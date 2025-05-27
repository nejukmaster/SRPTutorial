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
	//오브젝트 공간의 탄젠트를 받음
	float4 tangentOS : TANGENT;
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
//노멀맵 사용이 정의되지 않으면 Fragment의 탄젠트 벡터 요소를 선언하지 않습니다.
#if defined(_NORMAL_MAP)
	float4 tangentWS : VAR_TANGENT;
#endif
	float2 baseUV : VAR_BASE_UV;
	float2 detailUV : VAR_DETAIL_UV;
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
//노멀맵 사용이 정의된 경우에만 탄젠트 벡터를 할당해야 에러를 피할 수 있습니다.
#if defined(_NORMAL_MAP)
	//오브젝트 공간의 탄젠트를 월드 공간으로 변환
	output.tangentWS = float4(TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w);
#endif
	//ST에 저장된 오프셋과 타일링을 UV에 적용하여 반환
	output.baseUV = TransformBaseUV(input.baseUV);
//디테일맵 사용이 정의된 경우에만 디테일맵 UV를 계산
#if defined(_DETAIL_MAP)
	output.detailUV = TransformDetailUV(input.baseUV);
#endif

	return output;
}

float4 LitPassFragment(Varyings input) : SV_TARGET{
	UNITY_SETUP_INSTANCE_ID(input);

	//LOD에 따른 오브젝트 페이딩 처리
	ClipLOD(input.positionCS.xy, unity_LODFade.x);

	//GPU 인스턴싱을 사용할 경우 UNITY_ACCESS_INSTANCED_PROP을 통해 인스턴싱된 머티리얼의 프로퍼티 블록에 접근할 수 있습니다.
	//float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
	//float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	//_CLIPPING이 설정되어 있을때만 알파 클리핑
	InputConfig config = GetInputConfig(input.baseUV);
#if defined(_MASK_MAP)
	config.useMask = true;
#endif
#if defined(_DETAIL_MAP)
	config.detailUV = input.detailUV;
	config.useDetail = true;
#endif
	float4 base = GetBase(config);
#if defined(_CLIPPING)
	clip(base.a - GetCutoff(config));
#endif
	Surface surface;
	surface.position = input.positionWS;
#if defined(_NORMAL_MAP)
	//노말맵을 반영한 노말 벡터
	surface.normal = NormalTangentToWorld(GetNormalTS(config), input.normalWS, input.tangentWS);
	//노멀맵에 의한 노멀 보정은 그림자 캐스팅시 그림자 바이어스에 영향을 미치므로, 이때는 표면의 노말을 사용해야하므로 이를 Surface구조체에 따로 저장해놓습니다.
	surface.interpolatedNormal = input.normalWS;
//노멀맵을 사용하지 않도록 설정되어있으면 노멀맵 계산을 시행하지 않습니다.
#else
	surface.normal = normalize(input.normalWS);
	surface.interpolatedNormal = surface.normal;
#endif
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
	surface.depth = -TransformWorldToView(input.positionWS).z;
	surface.color = base.rgb;
	surface.alpha = base.a; 
	//BRDF 구현을 위한 Metailic값과 Smooothness 값을 넘겨준다.
	surface.metallic = GetMetallic(config);
	surface.smoothness = GetSmoothness(config);

	surface.occlusion = GetOcclusion(config);
	//프레넬 반사 표현을 위한 Fresnel값을 넘겨줍니다.
	surface.fresnelStrength = GetFresnel(config);
	//CoreRPLibrary에 포함된 InterleavedGradientNoise는 2D벡터값을 통해 그래디언트 노이즈를 생성합니다.
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0);

#if defined(_PREMULTIPLY_ALPHA)
	BRDF brdf = GetBRDF(surface, true);
#else
	BRDF brdf = GetBRDF(surface);
#endif
	//픽셀 데이터로 부터 GI데이터를 가지고오는 매크로(직접 정의)
	GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
	float3 color = GetLighting(surface, brdf, gi);
	color += GetEmission(config);
	
	return float4(color, surface.alpha);
}

#endif