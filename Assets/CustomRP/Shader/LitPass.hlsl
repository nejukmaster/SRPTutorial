#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl"
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"
/*
CBUFFER_START(UnityPerMaterial)
	float4 _BaseColor;
CBUFFER_END
*/

//LIGHTMAP_ON �� ��쿡�� GI�����͸� �޾ƿ����� ��ũ�θ� ����
#if defined(LIGHTMAP_ON)
	#define GI_ATTRIBUTE_DATA float2 lightMapUV : TEXCOORD1;
	#define GI_VARYINGS_DATA float2 lightMapUV : VAR_LIGHT_MAP_UV;
	#define TRANSFER_GI_DATA(input, output) \
			output.lightMapUV = input.lightMapUV * \
			unity_LightmapST.xy + unity_LightmapST.zw;
	#define GI_FRAGMENT_DATA(input) input.lightMapUV
#else
	#define GI_ATTRIBUTE_DATA
	#define GI_VARYINGS_DATA
	#define TRANSFER_GI_DATA(input, output)
	#define GI_FRAGMENT_DATA(input) 0.0
#endif

struct Attributes {
	float3 positionOS : POSITION;
	//������Ʈ ������ �븻�� ����
	float3 normalOS : NORMAL;
	float2 baseUV : TEXCOORD0;
	//�� ��ü�� GI���� �Ӽ��� �ڵ����� �߰����ִ� ��ũ��(���� ����)
	GI_ATTRIBUTE_DATA
	//�� ��ü�� GPU �ν��Ͻ� ���̵� �Է����� �޾ƿɴϴ�.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float3 positionWS : VAR_POSITION;
	float3 normalWS : VAR_NORMAL;
	float2 baseUV : VAR_BASE_UV;
	//�� ��ü�� GI���� �Ӽ��� �ڵ����� �߰����ִ� ��ũ��(���� ����)
	GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


//POSITION�� ���ؽ� �������� ������Ʈ ��ǥ�� �ǹ��ϴ� �ø�ƽ�̴�.
Varyings LitPassVertex(Attributes input) {
	Varyings output;

	UNITY_SETUP_INSTANCE_ID(input);
	//input�� ���� output�� GPU �ν��Ͻ��� ����ϵ��� ����
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	//GI���� �����͸� �������� �ȼ��� �����ϴ� ��ũ��(���� ����)
	TRANSFER_GI_DATA(input, output);

	output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	//ST�� ����� �����°� Ÿ�ϸ��� UV�� �����Ͽ� ��ȯ
	output.baseUV = TransformBaseUV(input.baseUV);

	return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);
	//GPU �ν��Ͻ��� ����� ��� UNITY_ACCESS_INSTANCED_PROP�� ���� �ν��Ͻ̵� ��Ƽ������ ������Ƽ ��Ͽ� ������ �� �ֽ��ϴ�.
	//float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	//float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	//_CLIPPING�� �����Ǿ� �������� ���� Ŭ����
	float4 base = GetBase(input.baseUV);
#if defined(_CLIPPING)
	clip(base.a - GetCutoff(input.baseUV));
#endif
	Surface surface;
	surface.position = input.positionWS;
	surface.normal = normalize(input.normalWS);
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
	surface.depth = -TransformWorldToView(input.positionWS).z;
	surface.color = base.rgb;
	surface.alpha = base.a; 
	//BRDF ������ ���� Metailic���� Smooothness ���� �Ѱ��ش�.
	surface.metallic = GetMetallic(input.baseUV);
	surface.smoothness = GetSmoothness(input.baseUV);
	//CoreRPLibrary�� ���Ե� InterleavedGradientNoise�� 2D���Ͱ��� ���� �׷����Ʈ ����� �����մϴ�.
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);

#if defined(_PREMULTIPLY_ALPHA)
	BRDF brdf = GetBRDF(surface, true);
#else
	BRDF brdf = GetBRDF(surface);
#endif
	//�ȼ� �����ͷ� ���� GI�����͸� ��������� ��ũ��(���� ����)
	GI gi = GetGI(GI_FRAGMENT_DATA(input), surface);
	float3 color = GetLighting(surface, brdf, gi);
	color += GetEmission(input.baseUV);
	
	return float4(color, surface.alpha);
}

#endif