#ifndef CUSTOM_BRDF_INCLUDED
#define CUSTOM_BRDF_INCLUDED

//���� ��ݼ��� �ݻ��� �ٻ�ġ
#define MIN_REFLECTIVITY 0.04

float OneMinusReflectivity(float metallic) {
	float range = 1.0 - MIN_REFLECTIVITY;
	return range - metallic * range;
}

struct BRDF {
	float3 diffuse;
	float3 specular;
	float roughness;
};

BRDF GetBRDF(Surface surface, bool ApplyAlphaToDiffuse = false) {
	BRDF brdf;
	brdf.specular = 0.0;
	brdf.roughness = 1.0;
	
	//�ݻ��� ���
	float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
	brdf.diffuse = surface.color * oneMinusReflectivity;
	if (ApplyAlphaToDiffuse) {
		brdf.diffuse *= surface.alpha;
	}
	brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);

	//��ĥ�� ���
	//Smoothness -> Perceptual Roughness -> Roughness ��ȯ�� ���� : (1-smoothness)^2
	float perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);	
	brdf.roughness = PerceptualRoughnessToRoughness(perceptualRoughness);

	return brdf;
}

//Specular ��� �Լ�
float SpecularStrength(Surface surface, BRDF brdf, Light light) {
	float3 h = SafeNormalize(light.direction + surface.viewDirection);
	float nh2 = Square(saturate(dot(surface.normal, h)));
	float lh2 = Square(saturate(dot(light.direction, h)));
	float r2 = Square(brdf.roughness);
	float d2 = Square(nh2 * (r2 - 1.0) + 1.00001);
	float normalization = brdf.roughness * 4.0 + 2.0;
	return r2 / (d2 * max(0.1, lh2) * normalization);
}

//Diffuse�� Specular�� ����
float3 DirectBRDF(Surface surface, BRDF brdf, Light light) {
	return SpecularStrength(surface, brdf, light) * brdf.specular + brdf.diffuse;
}

#endif