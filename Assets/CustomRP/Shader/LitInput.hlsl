#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//UnityPerMaterial ���۸� ����� GPU �ν��Ͻ̵� ������Ƽ ���� �������� ��ũ�� ����
#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

//Texture�� ����ϱ� ���ؼ� TEXTURE2D ��ũ�θ� ���� GPU �޸𸮿� �ؽ��ĸ� ���ε��ؾ� �մϴ�.
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//DetailMap �ؽ��ĸ� GPU �޸𸮿� ���ε�
TEXTURE2D(_DetailMap);
SAMPLER(sampler_DetailMap);


//Emission Map �ؽ��ĸ� GPU �޸𸮿� ���ε�
TEXTURE2D(_EmissionMap);

//MaskMap �ؽ��ĸ� GPU �޸𸮿� ���ε�
TEXTURE2D(_MaskMap);

//NormalMap �ؽ��ĸ� GPU �޸𸮿� ���ε�
TEXTURE2D(_NormalMap);

//DetailNormaMap �ؽ��ĸ� GPU �޸𸮿� ���ε�
TEXTURE2D(_DetailNormalMap);

//����Ƽ GPU �ν��Ͻ��� ����ϴ� ���̴��� ��� SRP Batcher�� �Ʒ��� ���� �����մϴ�.
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
//�ؽ��� uniform �ڿ� _ST�� ���̸� �ش� �ؽ����� 
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//�Է¹��� UV�� BaseMap �ؽ����� Tiling�� Offset�� �����ϴ� �Լ���
float2 TransformBaseUV(float2 baseUV, float2 detailUV = 0.0) {
	float4 baseST = INPUT_PROP(_BaseMap_ST);
	return baseUV * baseST.xy + baseST.zw;
}

//�Է¹��� UV�� DetailMap �ؽ����� Tiling�� Offset�� �����ϴ� �Լ���
float2 TransformDetailUV(float2 detailUV) {
	float4 detailST = INPUT_PROP(_DetailMap_ST);
	return detailUV * detailST.xy + detailST.zw;
}

float4 GetDetail(InputConfig c) {
	if (c.useDetail) {
		float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, c.detailUV);
		return map * 2.0 - 1.0;
	}
	return 0.0;
}

float4 GetMask(InputConfig c) {
	//hlsl���� bool�� �б��� ��� select ��ɾ�� ó���Ǹ�, ���� �ش� �ڵ�� �б⸦ ������ �ʽ��ϴ�.
	// c.useMask ? SAMPLE_TEXTURE2D(...) : 1.0; 
	if (c.useMask) {
		return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, c.baseUV);
	}
	return 1.0;
}

float4 GetBase(InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
	float4 color = INPUT_PROP(_BaseColor);

	//useDetail�� Ȱ��ȭ �Ǿ����� ���� ������ ����ũ ���� ���ø�
	if (c.useDetail) {
		//�����ϸ��� Rä�ο��� ���� ���� ��Ͽ� ������ ��ġ�� ���Ͱ� ����Ǿ��ֽ��ϴ�.
		float4 detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
		//����ũ���� Bä�ο��� �����ϸ��� ������ ���� ���Ͱ� ����Ǿ��ֽ��ϴ�.
		//�̴� BaseMap�� ���� �������� �����ؾ��ϹǷ� baseUV�� ���� ���ø��մϴ�.
		float mask = GetMask(c).b;
		map.rgb = lerp(map.rgb, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
	}

	return map * color;
}

float GetCutoff(InputConfig c) {
	return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig c) {
	float metallic = INPUT_PROP(_Metallic);
	//Matallic���� MaskMap�� Rä���Դϴ�.
	metallic *= GetMask(c).r;
	return metallic;
}

float GetSmoothness(InputConfig c) {
	float smoothness = INPUT_PROP(_Smoothness);
	//Smoothness���� MaskMap�� Aä���Դϴ�.
	smoothness *= GetMask(c).a;

	//useDetail�� Ȱ��ȭ �Ǿ����� ���� ������ ����ũ ���� ���ø�
	if (c.useDetail) {
		//Detail Albedo�� ������ �Ͱ� ���� ������� Smoothness�� �������ݴϴ�.
		float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
		float mask = GetMask(c).b;
		smoothness = lerp(smoothness, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
	}

	return smoothness;
}

float GetFresnel(InputConfig c) {
	return INPUT_PROP(_Fresnel);
}

float GetOcclusion(InputConfig c) {
	float strength = INPUT_PROP(_Occlusion);
	float occlusion = GetMask(c).g;
	occlusion = lerp(occlusion, 1.0, strength);
	return occlusion;
}

float3 GetEmission(InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, c.baseUV);
	float4 color = INPUT_PROP(_EmissionColor);
	return map.rgb * color.rgb;
}

//ź��Ʈ �������� ����� ���ø��ϴ� �Լ�
float3 GetNormalTS(InputConfig c) {
	//��ָ��� �ȼ��� ���ø�
	float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, c.baseUV);
	float scale = INPUT_PROP(_NormalScale);
	//�ش� �ȼ��� ���ڵ�
	float3 normal = DecodeNormal(map, scale);

	//useDetail�� Ȱ��ȭ �Ǿ����� ���� ������ ��� ���� ���ø�
	if (c.useDetail) {
		//������ ��ָ��� �ȼ��� ���ø�
		map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, c.detailUV);
		scale = INPUT_PROP(_DetailNormalScale) * GetMask(c).b;
		float3 detail = DecodeNormal(map, scale);
		//BlendNormalRNM�� ����ؼ� normal���͸� �������� detail���͸� ȸ����ŵ�ϴ�.
		normal = BlendNormalRNM(normal, detail);
	}

	return normal;
}

//ź��Ʈ ������ ���ǵ� ����� ���� �������� ��ȯ�ϴ� �Լ�
float3 NormalTangentToWorld(float3 normalTS, float3 normalWS, float4 tangentWS) {
	float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
	//TransformTagentToWorld �޼���� �ܼ��� ���ڷ� ���� ź��Ʈ ������ ��ְ� ��ȯ����� ��İ��� ���ϵ��� �Ǿ��ִ�.
	//mul(normalTS, tangentToWorld)
	return TransformTangentToWorld(normalTS, tangentToWorld);
}

#endif