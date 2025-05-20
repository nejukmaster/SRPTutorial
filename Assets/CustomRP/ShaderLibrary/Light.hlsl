#ifndef CUSTOM_LIGHT_INCLUDED
#define CUSTOM_LIGHT_INCLUDED

#define MAX_DIRECTIONAL_LIGHT_COUNT 4

CBUFFER_START(_CustomLight)
	int _DirectionalLightCount;
	float4 _DirectionalLightColors[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightDirections[MAX_DIRECTIONAL_LIGHT_COUNT];
	float4 _DirectionalLightShadowData[MAX_DIRECTIONAL_LIGHT_COUNT];
CBUFFER_END

struct Light {
	float3 color;
	float3 direction;
	//����
	float attenuation;
};

int GetDirectionalLightCount() {
	return _DirectionalLightCount;
}

//�ε����� ���� �׸��� �����͸� �������� �޼���
DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	//���⼺ �������� ���� �׸��� ������ �� ��ü�� �׸��� ���� ��� �����ϸ� �ǽð� �׸��ڿ� ����ũ�� �׸����� ��ȯ������ ������ �Һи�������.
	//���� �̴� �� �׸��ڸ� ������ �� ������ �������ش�.
	data.strength = _DirectionalLightShadowData[lightIndex].x; //*shadowData.strength;
	//�׸��� �� �ε��� y�࿡ ĳ�����̵� �ε����� �����ݴϴ�.
	data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
	data.normalBias = _DirectionalLightShadowData[lightIndex].z;
	//����ϴ� ������ ����ũ ä���� �����ɴϴ�.
	data.shadowMaskChannel = _DirectionalLightShadowData[lightIndex].w;
	return data;
}

Light GetDirectionalLight(int index, Surface surfaceWS, ShadowData shadowData) {
	Light light;
	light.color = _DirectionalLightColors[index].rgb;
	light.direction = _DirectionalLightDirections[index].xyz;
	DirectionalShadowData dirShadowData = GetDirectionalShadowData(index, shadowData);
	light.attenuation = GetDirectionalShadowAttenuation(dirShadowData, shadowData, surfaceWS);
	return light;
}

float3 IncomingLight(Surface surface, Light light) {
	return saturate(dot(surface.normal, light.direction) * light.attenuation) * light.color;
}

#endif