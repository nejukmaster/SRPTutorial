#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"

/*
CBUFFER_START(UnityPerMaterial)
	float4 _BaseColor;
CBUFFER_END
*/

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

struct Attributes {
	float3 positionOS : POSITION;
	float2 baseUV : TEXCOORD0;
	//각 객체의 GPU 인스턴스 아이디를 입력으로 받아옵니다.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


//POSITION은 버텍스 데이터의 오브젝트 좌표를 의미하는 시맨틱이다.
Varyings UnlitPassVertex(Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	//input에 대해 output이 GPU 인스턴싱을 사용하도록 설정
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
	output.positionCS = TransformWorldToHClip(positionWS);
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	//ST에 저장된 오프셋과 타일링을 UV에 적용하여 반환
	output.baseUV = input.baseUV * baseST.xy + baseST.zw;
	return output;
}

float4 UnlitPassFragment(Varyings input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);
	//GPU 인스턴싱을 사용할 경우 UNITY_ACCESS_INSTANCED_PROP을 통해 인스턴싱된 머티리얼의 프로퍼티 블록에 접근할 수 있습니다.
	float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	//_CLIPPING이 설정되어 있을때만 알파 클리핑
	float4 base = baseMap * baseColor;
#if defined(_CLIPPING)
	clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
#endif
	return base;
}

#endif