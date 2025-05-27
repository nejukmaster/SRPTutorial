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
	//��ĥ�⿡ ���� ȯ�� �ݻ��� LOD������ ���ϱ����� ��ĥ�� ��꿡 ���Ǵ� perceptualRoughness�� �����մϴ�.
	float perceptualRoughness;
	float fresnel;
};

BRDF GetBRDF(Surface surface, bool ApplyAlphaToDiffuse = false) {
	BRDF brdf;
	brdf.specular = 0.0;
	brdf.roughness = 1.0;
	
	//�ݻ��� ���
	//OneMinusReflectivity �޼���� matallic���� �޾� ���� ���� ����ü�� diffuse��(1-�ݻ���)�� ��ȯ�մϴ�.
	float oneMinusReflectivity = OneMinusReflectivity(surface.metallic);
	brdf.diffuse = surface.color * oneMinusReflectivity;
	if (ApplyAlphaToDiffuse) {
		brdf.diffuse *= surface.alpha;
	}
	brdf.specular = lerp(MIN_REFLECTIVITY, surface.color, surface.metallic);

	//��ĥ�� ���
	//Smoothness -> Perceptual Roughness -> Roughness ��ȯ�� ���� : (1-smoothness)^2
	brdf.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(surface.smoothness);	
	brdf.roughness = PerceptualRoughnessToRoughness(brdf.perceptualRoughness);
	//������ �ݻ�� ǥ���� ���� �Ի簢�� ���������� ���� ���� �Ϻ��ϰ� �ݻ�Ǵ� ������ ���մϴ�.
	//�� �ܰ迡�� ���� �������� �ٻ��ϴ� ���� ���� �ٻ���� ����մϴ�.
	//����, smoothness�� ��Ż���� ���� �ݻ����� ���ؼ� ������ �ݻ����� ����ϴ�.
	brdf.fresnel = saturate(surface.smoothness + 1.0 - oneMinusReflectivity);

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

//����ŧ�� �۷ι� �Ϸ�̳��̼��� ����ϴ� �Լ�
//�������� ���� ����ŧ���� ����ϴ� ���̹Ƿ� ���⼭ diffuse���� GI�� diffuse���� �޽��ϴ�.
//specular���� ���� GI�� specular�� �޽��ϴ�.
float3 IndirectBRDF(Surface surface, BRDF brdf, float3 diffuse, float3 specular) {
	//(1-ndv)^4�� ǥ�鿡���� ������ ������ �ٻ��մϴ�.
	float fresnelStrength = Pow4(1.0 - saturate(dot(surface.normal, surface.viewDirection)));
	//���� ������ ������ ����ŧ���� ������ ���� �����Ͽ� ���� �ݻ縦 �����մϴ�.
	//����, Ŀ���� ������ ������ �������ݴϴ�.
	float3 reflection = surface.fresnelStrength * specular * lerp(brdf.specular, brdf.fresnel, fresnelStrength);;
	//roughness�� ���� �����Ű�Ƿ� �츮�� ���� ���ݻ� ���� ���ҵǾ�� �մϴ�.
	//���� ���� �ݻ籤�� 1+roughness^2���� �����ݴϴ�.
	reflection /= brdf.roughness * brdf.roughness + 1.0;
	
	//������� �ʿ����� ��������� ���� ȯ�汤���� ����˴ϴ�.
	//�̷��� �������� ���� �ݻ��� ����� ������� �ʽ��ϴ�.
	return (diffuse * brdf.diffuse + reflection) * surface.occlusion;
}

#endif