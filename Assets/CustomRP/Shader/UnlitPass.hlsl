#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"

/*
CBUFFER_START(UnityPerMaterial)
	float4 _BaseColor;
CBUFFER_END
*/

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

struct Attributes {
	float3 positionOS : POSITION;
	float2 baseUV : TEXCOORD0;
	//�� ��ü�� GPU �ν��Ͻ� ���̵� �Է����� �޾ƿɴϴ�.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


//POSITION�� ���ؽ� �������� ������Ʈ ��ǥ�� �ǹ��ϴ� �ø�ƽ�̴�.
Varyings UnlitPassVertex(Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	//input�� ���� output�� GPU �ν��Ͻ��� ����ϵ��� ����
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
	output.positionCS = TransformWorldToHClip(positionWS);
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	//ST�� ����� �����°� Ÿ�ϸ��� UV�� �����Ͽ� ��ȯ
	output.baseUV = input.baseUV * baseST.xy + baseST.zw;
	return output;
}

float4 UnlitPassFragment(Varyings input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);
	//GPU �ν��Ͻ��� ����� ��� UNITY_ACCESS_INSTANCED_PROP�� ���� �ν��Ͻ̵� ��Ƽ������ ������Ƽ ���Ͽ� ������ �� �ֽ��ϴ�.
	float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	//_CLIPPING�� �����Ǿ� �������� ���� Ŭ����
	float4 base = baseMap * baseColor;
#if defined(_CLIPPING)
	clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
#endif
	return base;
}

#endif