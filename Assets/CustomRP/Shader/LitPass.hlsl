#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"
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
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes {
	float3 positionOS : POSITION;
	//������Ʈ ������ �븻�� ����
	float3 normalOS : NORMAL;
	float2 baseUV : TEXCOORD0;
	//�� ��ü�� GPU �ν��Ͻ� ���̵� �Է����� �޾ƿɴϴ�.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float3 positionWS : VAR_POSITION;
	float3 normalWS : VAR_NORMAL;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


//POSITION�� ���ؽ� �������� ������Ʈ ��ǥ�� �ǹ��ϴ� �ø�ƽ�̴�.
Varyings LitPassVertex(Attributes input) {
	Varyings output;

	UNITY_SETUP_INSTANCE_ID(input);
	//input�� ���� output�� GPU �ν��Ͻ��� ����ϵ��� ����
	UNITY_TRANSFER_INSTANCE_ID(input, output);

	output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	//ST�� ����� �����°� Ÿ�ϸ��� UV�� �����Ͽ� ��ȯ
	output.baseUV = input.baseUV * baseST.xy + baseST.zw;

	return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);
	//GPU �ν��Ͻ��� ����� ��� UNITY_ACCESS_INSTANCED_PROP�� ���� �ν��Ͻ̵� ��Ƽ������ ������Ƽ ��Ͽ� ������ �� �ֽ��ϴ�.
	float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	//_CLIPPING�� �����Ǿ� �������� ���� Ŭ����
	float4 base = baseMap * baseColor;
#if defined(_CLIPPING)
	clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
#endif
	Surface surface;
	surface.position = input.positionWS;
	surface.normal = normalize(input.normalWS);
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
	surface.depth = -TransformWorldToView(input.positionWS).z;
	surface.color = base.rgb;
	surface.alpha = base.a; 
	//BRDF ������ ���� Metailic���� Smooothness ���� �Ѱ��ش�.
	surface.metallic = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Metallic);
	surface.smoothness = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Smoothness);

#if defined(_PREMULTIPLY_ALPHA)
	BRDF brdf = GetBRDF(surface, true);
#else
	BRDF brdf = GetBRDF(surface);
#endif
	float3 color = GetLighting(surface, brdf);


	
	return float4(color, surface.alpha);
}

#endif