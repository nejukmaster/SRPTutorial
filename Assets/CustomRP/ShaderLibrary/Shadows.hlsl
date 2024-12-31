#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

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
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
CBUFFER_END

struct ShadowData {
	int cascadeIndex;
	float strength;
};

ShadowData GetShadowData(Surface surfaceWS) {
	ShadowData data;
	data.strength = 1.0;
	//캐스케이드 Culling Sphere를 순회하며 표면이 속해있는 Culling Sphere의 인덱스를 탐색
	int i;
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
			break;
		}
	}

	//표면이 속해 있는 Culling Sphere를 찾지 못했을 경우 그림자를 랜더링 하지 않습니다.
	if (i == _CascadeCount) {
		data.strength = 0.0;
	}

	data.cascadeIndex = i;
	return data;
}

//Directional Light에 대한 그림자 데이터를 넘겨받을 구조체 작성
struct DirectionalShadowData {
	float strength;
	int tileIndex;
};

//STS(Shadow Texture Space)상의 그림자 데이터를 샘플링하는 메서드
float SampleDirectionalShadowAtlas(float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

//표면 정보와 방향성 그림자 데이터를 받아 그림자 아틀라스를 샘플링하여 빛 감쇠를 반환하는 메서드
float GetDirectionalShadowAttenuation(DirectionalShadowData data, Surface surfaceWS) {
	//최신 GPU의 경우 if문 분기를 잘 처리하나, 낮은 GPU에서는 그렇지 않으므로 주의
	if (data.strength <= 0.0) {
		return 1.0;
	}
	float3 positionSTS = mul(
		_DirectionalShadowMatrices[data.tileIndex],
		float4(surfaceWS.position, 1.0)
	).xyz;
	float shadow = SampleDirectionalShadowAtlas(positionSTS);
	return lerp(1.0, shadow, data.strength);
}

#endif