#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

//LPPV가 전달하는 객체의 볼륨 텍스쳐 샘플링
TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

//베이크된 조명이 제공하는 쉐도우 마스크 텍스쳐 샘플링
TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

float3 SampleLightMap(float2 lightMapUV) {
#if defined(LIGHTMAP_ON)
	//EntityLighting.hlsl에 포함된 메서드로 라이트맵 uv를 사용하여 라이트맵을 검색합니다.
	//TEXTURE2D_ARGS는 텍스쳐와 샘플러를 하나로 묶어, 하나의 인자로 전달할 수 있도록 해주는 매크로입니다.
	return SampleSingleLightmap(TEXTURE2D_ARGS(unity_Lightmap, samplerunity_Lightmap), lightMapUV,float4(1.0, 1.0, 0.0, 0.0),
												#if defined(UNITY_LIGHTMAP_FULL_HDR)
													false,
												#else
													true,
												#endif
													float4(LIGHTMAP_HDR_MULTIPLIER, LIGHTMAP_HDR_EXPONENT, 0.0, 0.0));
#else
	return 0.0;
#endif
}

//광 프로브 샘플링 함수
float3 SampleLightProbe(Surface surfaceWS) {
	//랜더링하는 객체가 라이트맵을 사용중일경우(즉, BakedLight를 사용하는 객체일경우) 광 프로브의 영향을 받지 않습니다.
#if defined(LIGHTMAP_ON)
	return 0.0;
#else
	//LPPV를 사용하는 객체일 경우 LPPV에서 제공한 파라미터로 구면 조화 함수를 계산합니다.
	if (unity_ProbeVolumeParams.x) {
		return SampleProbeVolumeSH4(
			TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
			surfaceWS.position, surfaceWS.normal,
			unity_ProbeVolumeWorldToObject,
			unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
			unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
		);
	}
	else {
		float4 coefficients[7];
		coefficients[0] = unity_SHAr;
		coefficients[1] = unity_SHAg;
		coefficients[2] = unity_SHAb;
		coefficients[3] = unity_SHBr;
		coefficients[4] = unity_SHBg;
		coefficients[5] = unity_SHBb;
		coefficients[6] = unity_SHC;
		//SampleSH9 함수는 구면조화 함수를 통해 해당 표면의 간접 조명을 샘플링합니다.
		return max(0.0, SampleSH9(coefficients, surfaceWS.normal));
	}
#endif
}

//쉐도우 마스크를 통해 베이킹된 그림자를 샘플링하는 함수
float4 SampleBakedShadows(float2 lightMapUV, Surface surfaceWS) {
//LIGHTMAP_ON이 설정된 객체에서만 유효
#if defined(LIGHTMAP_ON)
	return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
#else
	//동적객체 중에서 LPPV가 설정된 객체일 경우 LPPV에 베이크된 그림자를 샘플링하여 적용합니다.
	if (unity_ProbeVolumeParams.x) {
		//LPPV 라이트맵과 LPPV 쉐도우는 같은 3D텍스쳐에 적용되고 샘플링하는 함수도 동일한 인수를 필요로 합니다.
		//다만, LPPV 쉐도우 샘플링에선 법선 벡터를 인수로 받지 않습니다.
		return SampleProbeOcclusion(
			TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
			surfaceWS.position, unity_ProbeVolumeWorldToObject,
			unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
			unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
		);
	}
	//LPPV가 설정되지 않은 동적 객체에선 일반적인 오쿨루젼 데이터를 사용
	else {
		//동적 객체일 경우 프로브 오쿨루젼 데이터를 베이크된 그림자로서 반환.
		return unity_ProbesOcclusion;
	}
#endif
}


struct GI {
	float3 diffuse;
	//쉐도우 마스크는 기본적으로 베이크된 조명에 포함된 데이터이므로 GI 구조체에서도 들고옵니다.
	ShadowMask shadowMask;
};

GI GetGI(float2 lightMapUV, Surface surfaceWS) {
	GI gi;
	gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);
	//GI에서도 마찬가지로 기본적으로 쉐도우 마스크를 사용하지 않도록합니다.
	gi.shadowMask.always = false;
	gi.shadowMask.distance = false;
	gi.shadowMask.shadows = 1.0;
	//_SHADOW_MASK_ALWAYS가 활성화 되어있는 경우 쉐도우 마스크 사용을 설정하고 베이크된 그림자를 샘플링
#if defined(_SHADOW_MASK_ALWAYS)
	gi.shadowMask.always = true;
	gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
	//_SHADOW_MASK_DISTANCE가 활성화 되어있는 경우 쉐도우 마스크 사용을 설정하고 베이크된 그림자를 샘플링
#elif defined(_SHADOW_MASK_DISTANCE)
	gi.shadowMask.distance = true;
	gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
#endif
	return gi;
}

#endif