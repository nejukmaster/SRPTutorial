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

float4 GetBase(InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
	float4 color = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	return map * color;
}

//각 공통 패스에서 컴파일 에러를 방지하기 위한 더미 메서드
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

//Unlit 객체는 디퓨즈를 그대로 방출
float3 GetEmission(InputConfig c) {
	return GetBase(c).rgb;
}

#endif