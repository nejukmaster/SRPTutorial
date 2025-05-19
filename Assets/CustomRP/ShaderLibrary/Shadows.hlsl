#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

//��Ʈ ���� �Լ��� ���ǵ� ��Ű�� ��Ŭ���
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

//��������� ���ø��Ѵ�.
TEXTURE2D_SHADOW(_DirectionalShadowAtlas);
//������ ��(���̸�)�� �⺻���� ����Ƽ ���̴� ���ø� ����� regular bilinear filtering ������� ���ø��ϴ� ���� �������� �ʱ⿡
//linear clamp compare ����� ���÷��� �������ݴϴ�.
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
	//������ ����ũ ����ü�� �Ÿ���� ���� bool ������Ƽ�� ����ũ�� �׸��ڸ� ��Ÿ���� 4���� float ���͸� ����մϴ�.
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
	//�⺻������ �����츶��ũ�� ������� �ʰ� �ʱ�ȭ
	data.shadowMask.distance = false;
	data.shadowMask.shadows = 1.0;
	//ĳ�����̵� ���� Factor�� 1.0(�ִ밭��)�� �ʱ�ȭ
	data.cascadeBlend = 1.0;
	//strength�� �ʱ�ȭ�� ��, surface�� depth�� �׸��� �ִ� ������ �Ÿ����� ������ 1, �׷��� ������ 0���� ������ ���� �� �׸��ڸ� ���������� �ʴ´�.
	data.strength = FadedShadowStrength(
		surfaceWS.depth, _ShadowDistanceFade.x, _ShadowDistanceFade.y
	);
	//ĳ�����̵� Culling Sphere�� ��ȸ�ϸ� ǥ���� �����ִ� Culling Sphere�� �ε����� Ž��
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

	//ǥ���� ���� �ִ� Culling Sphere�� ã�� ������ ��� �׸��ڸ� ������ ���� �ʽ��ϴ�.
	if (i == _CascadeCount) {
		data.strength = 0.0;
	}
#if defined(_CASCADE_BLEND_DITHER)
	else if (data.cascadeBlend < surfaceWS.dither) {
		i += 1;
	}
#endif
	//DITHER�� SOFT Ű���嵵 ���������� ������� ĳ�����̵� ������ ������� �ʽ��ϴ�.(Hard)
#if !defined(_CASCADE_BLEND_SOFT)
	data.cascadeBlend = 1.0;
#endif

	data.cascadeIndex = i;
	return data;
}

//Directional Light�� ���� �׸��� �����͸� �Ѱܹ��� ����ü �ۼ�
struct DirectionalShadowData {
	float strength;
	int tileIndex;
	float normalBias;
};

//STS(Shadow Texture Space)���� �׸��� �����͸� ���ø��ϴ� �޼���
float SampleDirectionalShadowAtlas(float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

//�׸��ڿ� PCF�� �����ϴ� �Լ�
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

//����ũ�� �׸��� ����ũ�� �������� �Լ�
float GetBakedShadow(ShadowMask mask) {
	float shadow = 1.0;
	//�Ÿ��� �����츶��ũ�� Ȱ��ȭ �Ǿ��������
	if (mask.distance) {
		//������ ������ Rä���� ����ũ�� ���� ��ü�� ����ũ�� �׸��ڸ� ��Ÿ���ϴ�.
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

//����ũ�� �׸��ڿ� �ǽð� �׸��ڸ� ȥ��
float MixBakedAndRealtimeShadows(ShadowData global, float shadow, float strength)
{
	float baked = GetBakedShadow(global.shadowMask);
	if (global.shadowMask.distance) {
		//�Ÿ� ������ ����ũ�� ����ϴ� ��ü�� ��� �׸��ڵ����͸� ���� �׸��ڸ� �켱������ ���
		//�ø��� ������ ������ �׸��ڵ� ǥ���ϵ��� ���밪���� ����
		shadow = lerp(baked, shadow, abs(global.strength));
		return lerp(1.0, shadow, strength);
	}
	return lerp(1.0, shadow, strength * global.strength);
}

//ǥ�� ������ ���⼺ �׸��� �����͸� �޾� �׸��� ��Ʋ�󽺸� ���ø��Ͽ� �� ���踦 ��ȯ�ϴ� �޼���
float GetDirectionalShadowAttenuation(DirectionalShadowData directional, ShadowData global, Surface surfaceWS) {
	//��Ƽ������ �׸��ڸ� ���� ������� ���踦 1�� ����
#if !defined(_RECEIVE_SHADOWS)
	return 1.0;
#endif
	float shadow;
	//�ֽ� GPU�� ��� if�� �б⸦ �� ó���ϳ�, ���� GPU������ �׷��� �����Ƿ� ����
	//�ǽð� �׸��� ����� ���� �׸��� ���⸦ ���Ͽ� ��� �ϳ��� 0�� ���� ������� �׸��� �Ÿ����� �־����ٰ� �Ǵ��Ͽ� ���� �׸��ڸ� ����մϴ�.
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