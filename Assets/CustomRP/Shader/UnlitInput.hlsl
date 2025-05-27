#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//Texture�� ����ϱ� ���ؼ� TEXTURE2D ��ũ�θ� ���� GPU �޸𸮿� �ؽ��ĸ� ���ε��ؾ� �մϴ�.
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//����Ƽ GPU �ν��Ͻ��� ����ϴ� ���̴��� ��� SRP Batcher�� �Ʒ��� ���� �����մϴ�.
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
//�ؽ��� uniform �ڿ� _ST�� ���̸� �ش� �ؽ����� 
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float2 TransformBaseUV(float2 baseUV) {
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	return baseUV * baseST.xy + baseST.zw;
}

float4 GetBase(InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
	float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	return map * color;
}

//�� ���� �н����� ������ ������ �����ϱ� ���� ���� �޼���
float GetCutoff(InputConfig c) {
	return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
}

float GetMetallic(InputConfig c) {
	return 0.0;
}

float GetSmoothness(InputConfig c) {
	return 0.0;
}

float GetFresnel(InputConfig c) {
	return 0.0;
}

//Unlit ��ü�� ��ǻ� �״�� ����
float3 GetEmission(InputConfig c) {
	return GetBase(c).rgb;
}

#endif