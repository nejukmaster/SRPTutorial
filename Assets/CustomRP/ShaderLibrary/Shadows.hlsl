#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

//텐트 필터 함수가 정의된 패키지 인클루드
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

#if defined(_DIRECTIONAL_PCF3)
	#define DIRECTIONAL_FILTER_SAMPLES 4
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_3x3
#elif defined(_DIRECTIONAL_PCF5)
	#define DIRECTIONAL_FILTER_SAMPLES 9
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_5x5
#elif defined(_DIRECTIONAL_PCF7)
	#define DIRECTIONAL_FILTER_SAMPLES 16
	#define DIRECTIONAL_FILTER_SETUP SampleShadow_ComputeSamples_Tent_7x7
#endif

#define MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT 4
#define MAX_CASCADE_COUNT 4

//쉐도우맵을 샘플링한다.
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
//쉐도우 맵(깊이맵)은 기본적인 유니티 쉐이더 샘플링 방법인 regular bilinear filtering 방법으로 샘플링하는 것이 적절하지 않기에
//linear clamp compare 방식의 샘플러를 정의해줍니다.
#define SHADOW_SAMPLER sampler_linear_clamp_compare
SAMPLER_CMP(SHADOW_SAMPLER);

CBUFFER_START(_CustomShadows)
	int _CascadeCount;
	float4 _CascadeCullingSpheres[MAX_CASCADE_COUNT];
	float4 _CascadeData[MAX_CASCADE_COUNT];
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
	float4 _ShadowAtlasSize;
	float4 _ShadowDistanceFade;
CBUFFER_END

struct ShadowMask
{
	//쉐도우 마스크 구조체는 거리사용 여부 bool 프로퍼티와 베이크된 그림자를 나타내는 4차원 float 벡터를 사용합니다.
	bool distance;
	float4 shadows;
};

struct ShadowData {
	int cascadeIndex;
	float cascadeBlend;
	float strength;
	ShadowMask shadowMask;
};

float FadedShadowStrength(float distance, float scale, float fade) {
	return saturate((1.0 - distance * scale) * fade);
}

ShadowData GetShadowData(Surface surfaceWS) {
	ShadowData data;
	//기본적으로 쉐도우마스크를 사용하지 않게 초기화
	data.shadowMask.distance = false;
	data.shadowMask.shadows = 1.0;
	//캐스케이드 블랜딩 Factor를 1.0(최대강도)로 초기화
	data.cascadeBlend = 1.0;
	//strength를 초기화할 때, surface의 depth가 그림자 최대 랜더링 거리보다 작으면 1, 그렇지 않으면 0으로 설정해 범위 밖 그림자를 랜더링하지 않는다.
	data.strength = FadedShadowStrength(
		surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y
	);
	//캐스케이드 Culling Sphere를 순회하며 표면이 속해있는 Culling Sphere의 인덱스를 탐색
	int i;
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
			float fade = FadedShadowStrength(
				distanceSqr, _CascadeData[i].x, _ShadowDistanceFade.z
			);
			if (i == _CascadeCount - 1) {
				data.strength *= fade;
			}
			else {
				data.cascadeBlend = fade;
			}
			break;
		}
	}

	//표면이 속해 있는 Culling Sphere를 찾지 못했을 경우 그림자를 랜더링 하지 않습니다.
	if (i == _CascadeCount) {
		data.strength = 0.0;
	}
#if defined(_CASCADE_BLEND_DITHER)
	else if (data.cascadeBlend < surfaceWS.dither) {
		i += 1;
	}
#endif
	//DITHER도 SOFT 키워드도 설정되있지 않을경우 캐스케이드 블랜딩을 사용하지 않습니다.(Hard)
#if !defined(_CASCADE_BLEND_SOFT)
	data.cascadeBlend = 1.0;
#endif

	data.cascadeIndex = i;
	return data;
}

//Directional Light에 대한 그림자 데이터를 넘겨받을 구조체 작성
struct DirectionalShadowData {
	float strength;
	int tileIndex;
	float normalBias;
};

//STS(Shadow Texture Space)상의 그림자 데이터를 샘플링하는 메서드
float SampleDirectionalShadowAtlas(float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

//그림자에 PCF를 적용하는 함수
float FilterDirectionalShadow(float3 positionSTS) {
#if defined(DIRECTIONAL_FILTER_SETUP)
	float weights[DIRECTIONAL_FILTER_SAMPLES];
	float2 positions[DIRECTIONAL_FILTER_SAMPLES];
	float4 size = _ShadowAtlasSize.yyxx;
	DIRECTIONAL_FILTER_SETUP(size, positionSTS.xy, weights, positions);
	float shadow = 0;
	for (int i = 0; i < DIRECTIONAL_FILTER_SAMPLES; i++) {
		shadow += weights[i] * SampleDirectionalShadowAtlas(
			float3(positions[i].xy, positionSTS.z)
		);
	}
	return shadow;
#else
	return SampleDirectionalShadowAtlas(positionSTS);
#endif
}

float GetCascadedShadow(
	DirectionalShadowData directional, ShadowData global, Surface surfaceWS
) {
	float3 normalBias = surfaceWS.normal *
		(directional.normalBias * _CascadeData[global.cascadeIndex].y);
	float3 positionSTS = mul(
		_DirectionalShadowMatrices[directional.tileIndex],
		float4(surfaceWS.position + normalBias, 1.0)
	).xyz;
	float shadow = FilterDirectionalShadow(positionSTS);
	if (global.cascadeBlend < 1.0) {
		normalBias = surfaceWS.normal *
			(directional.normalBias * _CascadeData[global.cascadeIndex + 1].y);
		positionSTS = mul(
			_DirectionalShadowMatrices[directional.tileIndex + 1],
			float4(surfaceWS.position + normalBias, 1.0)
		).xyz;
		shadow = lerp(
			FilterDirectionalShadow(positionSTS), shadow, global.cascadeBlend
		);
	}
	return shadow;
}

//베이크된 그림자 마스크를 가져오는 함수
float GetBakedShadow(ShadowMask mask) {
	float shadow = 1.0;
	//거리별 쉐도우마스크가 활성화 되어있을경우
	if (mask.distance) {
		//쉐도우 벡터의 R채널은 베이크된 정적 객체의 베이크된 그림자를 나타냅니다.
		shadow = mask.shadows.r;
	}
	return shadow;
}

float GetBakedShadow(ShadowMask mask, float strength) {
	if (mask.distance) {
		return lerp(1.0, GetBakedShadow(mask), strength);
	}
	return 1.0;
}

//베이크된 그림자와 실시간 그림자를 혼합
float MixBakedAndRealtimeShadows(ShadowData global, float shadow, float strength)
{
	float baked = GetBakedShadow(global.shadowMask);
	if (global.shadowMask.distance) {
		//거리 쉐도우 마스크를 사용하는 객체의 경우 그림자데이터를 구운 그림자를 우선적으로 사용
		//컬링된 조명의 구워진 그림자도 표시하도록 절대값으로 전달
		shadow = lerp(baked, shadow, abs(global.strength));
		return lerp(1.0, shadow, strength);
	}
	return lerp(1.0, shadow, strength * global.strength);
}

//표면 정보와 방향성 그림자 데이터를 받아 그림자 아틀라스를 샘플링하여 빛 감쇠를 반환하는 메서드
float GetDirectionalShadowAttenuation(DirectionalShadowData directional, ShadowData global, Surface surfaceWS) {
	//머티리얼이 그림자를 받지 않을경우 감쇠를 1로 설정
#if !defined(_RECEIVE_SHADOWS)
	return 1.0;
#endif
	float shadow;
	//최신 GPU의 경우 if문 분기를 잘 처리하나, 낮은 GPU에서는 그렇지 않으므로 주의
	//실시간 그림자 세기와 구운 그림자 세기를 곱하여 어느 하나라도 0의 값을 가질경우 그림자 거리보다 멀어졌다고 판다하여 구운 그림자만 사용합니다.
	if (directional.strength * global.strength <= 0.0) {
		shadow = GetBakedShadow(global.shadowMask, directional.strength);
	}
	else {
		shadow = GetCascadedShadow(directional, global, surfaceWS);
		shadow = MixBakedAndRealtimeShadows(global, shadow, directional.strength);
	}
	return shadow;
}

#endif