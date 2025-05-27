#ifndef CUSTOM_SHADOW_CASTER_PASS_INCLUDED
#define CUSTOM_SHADOW_CASTER_PASS_INCLUDED

#include "../ShaderLibrary/Common.hlsl"

struct Attributes {
	float3 positionOS : POSITION;
	float2 baseUV : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings ShadowCasterPassVertex(Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float3 positionWS = TransformObjectToWorld(input.positionOS);
	output.positionCS = TransformWorldToHClip(positionWS);

	//NearPlane에 의해 그림자가 잘리는 현상을 방지하기 위해서 ShadowAtlas w값에 NearPlane값을 곱한값과 일반 z값중 큰값으로 사용합니다.
#if UNITY_REVERSED_Z
	//Z 버퍼가 뒤집혀져있을경우 작은값을 택합니다.
	output.positionCS.z =
		min(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
	output.positionCS.z =
		max(output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif

	float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	output.baseUV = input.baseUV * baseST.xy + baseST.zw;
	return output;
}

void ShadowCasterPassFragment(Varyings input) {
	UNITY_SETUP_INSTANCE_ID(input);
	InputConfig config = GetInputConfig(input.baseUV);

	//LOD에 따른 페이딩 처리
	ClipLOD(input.positionCS.xy, unity_LODFade.x);

	float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, config.baseUV);
	float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
	float4 base = baseMap * baseColor;
#if defined(_SHADOWS_CLIP)
	clip(saturate(base.a) - 1.01f*UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
#elif defined(_SHADOWS_DITHER)
	float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
	clip(saturate(base.a) - (1.5f*dither + 1 ) * UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
#endif
}

#endif