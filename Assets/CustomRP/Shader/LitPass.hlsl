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

//LIGHTMAP_ON 일 경우에만 GI데이터를 받아오도록 매크로를 정의
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
	//오브젝트 공간의 노말을 받음
	float3 normalOS : NORMAL;
	float2 baseUV : TEXCOORD0;
	//각 객체의 GI관련 속성을 자동으로 추가해주는 매크로(직접 정의)
	GI_ATTRIBUTE_DATA
	//각 객체의 GPU 인스턴스 아이디를 입력으로 받아옵니다.
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float3 positionWS : VAR_POSITION;
	float3 normalWS : VAR_NORMAL;
	float2 baseUV : VAR_BASE_UV;
	//각 객체의 GI관련 속성을 자동으로 추가해주는 매크로(직접 정의)
	GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};


//POSITION은 버텍스 데이터의 오브젝트 좌표를 의미하는 시맨틱이다.
Varyings LitPassVertex(Attributes input) {
	Varyings output;

	UNITY_SETUP_INSTANCE_ID(input);
	//input에 대해 output이 GPU 인스턴싱을 사용하도록 설정
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	//GI관련 데이터를 정점에서 픽셀로 전송하는 매크로(직접 정의)
	TRANSFER_GI_DATA(input, output);

	output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);
	//ST에 저장된 오프셋과 타일링을 UV에 적용하여 반환
	output.baseUV = TransformBaseUV(input.baseUV);

	return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);
	//GPU 인스턴싱을 사용할 경우 UNITY_ACCESS_INSTANCED_PROP을 통해 인스턴싱된 머티리얼의 프로퍼티 블록에 접근할 수 있습니다.
	//float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	//float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	//_CLIPPING이 설정되어 있을때만 알파 클리핑
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
	//BRDF 구현을 위한 Metailic값과 Smooothness 값을 넘겨준다.
	surface.metallic = GetMetallic(input.baseUV);
	surface.smoothness = GetSmoothness(input.baseUV);
	//CoreRPLibrary에 포함된 InterleavedGradientNoise는 2D벡터값을 통해 그래디언트 노이즈를 생성합니다.
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);

#if defined(_PREMULTIPLY_ALPHA)
	BRDF brdf = GetBRDF(surface, true);
#else
	BRDF brdf = GetBRDF(surface);
#endif
	//픽셀 데이터로 부터 GI데이터를 가지고오는 매크로(직접 정의)
	GI gi = GetGI(GI_FRAGMENT_DATA(input), surface);
	float3 color = GetLighting(surface, brdf, gi);
	color += GetEmission(input.baseUV);
	
	return float4(color, surface.alpha);
}

#endif