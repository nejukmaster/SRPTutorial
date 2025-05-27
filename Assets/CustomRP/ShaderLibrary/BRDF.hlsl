#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

//실제 비금속의 반사율 근사치
#define MIN_REFLECTIVITY 0.04

float OneMinusReflectivity(float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY;
	return range - metallic * range;
}

struct BRDF {
	float3 diffuse;
	float3 specular;
	float roughness;
	//거칠기에 따른 환경 반사의 LOD레벨을 구하기위해 거칠기 계산에 사용되는 perceptualRoughness를 저장합니다.
	float perceptualRoughness;
	float fresnel;
};

BRDF GetBRDF(Surface surface, bool ApplyAlphaToDiffuse = false) {
	BRDF brdf;
	brdf.specular = 0.0;
	brdf.roughness = 1.0;
	
	//반사율 계산
	//OneMinusReflectivity 메서드는 matallic값을 받아 실제 세계 유전체의 diffuse값(1-반사율)을 반환합니다.
	float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
	brdf.diffuse = surface.color * oneMinusReflectivity;
	if (ApplyAlphaToDiffuse) {
		brdf.diffuse *= surface.alpha;
	}
	brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);

	//거칠기 계산
	//Smoothness -> Perceptual Roughness -> Roughness 변환을 수행 : (1-smoothness)^2
	brdf.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);	
	brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);
	//프레넬 반사는 표면의 각과 입사각이 같아졌을때 빛이 거의 완벽하게 반사되는 현상을 말합니다.
	//이 단계에선 실제 프레넬을 근사하는 변형 슐릭 근사법을 사용합니다.
	//먼저, smoothness와 메탈릭에 따른 반사율을 더해서 프레넬 반사율을 얻습니다.
	brdf.fresnel = saturate(surface.smoothness + 1.0 - oneMinusReflectivity);

	return brdf;
}

//Specular 계산 함수
float SpecularStrength(Surface surface, BRDF brdf, Light light) {
	float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = Square(saturate(dot(surface.normal, h)));
	float lh2 = Square(saturate(dot(light.direction, h)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

//Diffuse에 Specular를 적용
float3 DirectBRDF(Surface surface, BRDF brdf, Light light) {
	return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

//스펙큘러 글로벌 일루미네이션을 계산하는 함수
//간접광에 의한 스펙큘러를 계산하는 것이므로 여기서 diffuse값은 GI의 diffuse값을 받습니다.
//specular인자 역시 GI의 specular를 받습니다.
float3 IndirectBRDF(Surface surface, BRDF brdf, float3 diffuse, float3 specular) {
	//(1-ndv)^4로 표면에서의 프레넬 강도를 근사합니다.
	float fresnelStrength = Pow4(1.0 - saturate(dot(surface.normal, surface.viewDirection)));
	//이후 프레넬 강도로 스펙큘러와 프레넬 값을 보간하여 색상에 반사를 적용합니다.
	//또한, 커스텀 프레넬 강도를 적용해줍니다.
	float3 reflection = surface.fresnelStrength * specular * lerp(brdf.specular, brdf.fresnel, fresnelStrength);;
	//roughness는 빛을 산란시키므로 우리가 보는 정반사 값은 감소되어야 합니다.
	//따라서 계산된 반사광을 1+roughness^2으로 나눠줍니다.
	reflection /= brdf.roughness * brdf.roughness + 1.0;
	
	//오쿨루전 맵에의한 오쿨루전은 간접 환경광에만 적용됩니다.
	//이러면 직접광에 의한 반사등에는 폐색이 적용되지 않습니다.
	return (diffuse * brdf.diffuse + reflection) * surface.occlusion;
}

#endif