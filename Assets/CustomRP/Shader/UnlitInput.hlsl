#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//Texture를 사용하기 위해선 TEXTURE2D 매크로를 통해 GPU 메모리에 텍스쳐를 업로드해야 합니다.
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//유니티 GPU 인스턴싱을 사용하는 쉐이더의 경우 SRP Batcher를 아래와 같이 적용합니다.
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
//텍스쳐 uniform 뒤에 _ST를 붙이면 해당 텍스쳐의 
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

float2 TransformBaseUV(float2 baseUV) {
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	return baseUV * baseST.xy + baseST.zw;
}

float4 GetBase(float2 baseUV) {
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
	float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	return map * color;
}

float GetCutoff(float2 baseUV) {
	return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff);
}

float GetMetallic(float2 baseUV) {
	return 0.0;
}

float GetSmoothness(float2 baseUV) {
	return 0.0;
}


float3 GetEmission(float2 baseUV) {
	return GetBase(baseUV).rgb;
}

#endif