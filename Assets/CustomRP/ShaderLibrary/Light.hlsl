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
	//감쇠
	float attenuation;
};

int GetDirectionalLightCount() {
	return _DirectionalLightCount;
}

//인덱스에 따른 그림자 데이터를 가져오는 메서드
DirectionalShadowData GetDirectionalShadowData(int lightIndex, ShadowData shadowData) {
	DirectionalShadowData data;
	//방향성 조명으로 생긴 그림자 강도와 각 객체의 그림자 강도 즉시 결합하면 실시간 그림자와 베이크된 그림자의 전환에서의 기준이 불분명해진다.
	//따라서 이는 두 그림자를 보간한 후 강도를 적용해준다.
	data.strength = _DirectionalLightShadowData[lightIndex].x; //*shadowData.strength;
	//그림자 맵 인덱스 y축에 캐스케이드 인덱스를 더해줍니다.
	data.tileIndex = _DirectionalLightShadowData[lightIndex].y + shadowData.cascadeIndex;
	data.normalBias = _DirectionalLightShadowData[lightIndex].z;
	//사용하는 쉐도우 마스크 채널을 가져옵니다.
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