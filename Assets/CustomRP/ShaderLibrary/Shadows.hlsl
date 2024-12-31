#ifndef CUSTOM_SHADOWS_INCLUDED
#define CUSTOM_SHADOWS_INCLUDED

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
	float4x4 _DirectionalShadowMatrices[MAX_SHADOWED_DIRECTIONAL_LIGHT_COUNT * MAX_CASCADE_COUNT];
CBUFFER_END

struct ShadowData {
	int cascadeIndex;
	float strength;
};

ShadowData GetShadowData(Surface surfaceWS) {
	ShadowData data;
	data.strength = 1.0;
	//ĳ�����̵� Culling Sphere�� ��ȸ�ϸ� ǥ���� �����ִ� Culling Sphere�� �ε����� Ž��
	int i;
	for (i = 0; i < _CascadeCount; i++) {
		float4 sphere = _CascadeCullingSpheres[i];
		float distanceSqr = DistanceSquared(surfaceWS.position, sphere.xyz);
		if (distanceSqr < sphere.w) {
			break;
		}
	}

	//ǥ���� ���� �ִ� Culling Sphere�� ã�� ������ ��� �׸��ڸ� ������ ���� �ʽ��ϴ�.
	if (i == _CascadeCount) {
		data.strength = 0.0;
	}

	data.cascadeIndex = i;
	return data;
}

//Directional Light�� ���� �׸��� �����͸� �Ѱܹ��� ����ü �ۼ�
struct DirectionalShadowData {
	float strength;
	int tileIndex;
};

//STS(Shadow Texture Space)���� �׸��� �����͸� ���ø��ϴ� �޼���
float SampleDirectionalShadowAtlas(float3 positionSTS) {
	return SAMPLE_TEXTURE2D_SHADOW(
		_DirectionalShadowAtlas, SHADOW_SAMPLER, positionSTS
	);
}

//ǥ�� ������ ���⼺ �׸��� �����͸� �޾� �׸��� ��Ʋ�󽺸� ���ø��Ͽ� �� ���踦 ��ȯ�ϴ� �޼���
float GetDirectionalShadowAttenuation(DirectionalShadowData data, Surface surfaceWS) {
	//�ֽ� GPU�� ��� if�� �б⸦ �� ó���ϳ�, ���� GPU������ �׷��� �����Ƿ� ����
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