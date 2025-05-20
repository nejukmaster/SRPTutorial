#ifndef CUSTOM_GI_INCLUDED
#define CUSTOM_GI_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"

TEXTURE2D(unity_Lightmap);
SAMPLER(samplerunity_Lightmap);

//LPPV�� �����ϴ� ��ü�� ���� �ؽ��� ���ø�
TEXTURE3D_FLOAT(unity_ProbeVolumeSH);
SAMPLER(samplerunity_ProbeVolumeSH);

//����ũ�� ������ �����ϴ� ������ ����ũ �ؽ��� ���ø�
TEXTURE2D(unity_ShadowMask);
SAMPLER(samplerunity_ShadowMask);

float3 SampleLightMap(float2 lightMapUV) {
#if defined(LIGHTMAP_ON)
	//EntityLighting.hlsl�� ���Ե� �޼���� ����Ʈ�� uv�� ����Ͽ� ����Ʈ���� �˻��մϴ�.
	//TEXTURE2D_ARGS�� �ؽ��Ŀ� ���÷��� �ϳ��� ����, �ϳ��� ���ڷ� ������ �� �ֵ��� ���ִ� ��ũ���Դϴ�.
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

//�� ���κ� ���ø� �Լ�
float3 SampleLightProbe(Surface surfaceWS) {
	//�������ϴ� ��ü�� ����Ʈ���� ������ϰ��(��, BakedLight�� ����ϴ� ��ü�ϰ��) �� ���κ��� ������ ���� �ʽ��ϴ�.
#if defined(LIGHTMAP_ON)
	return 0.0;
#else
	//LPPV�� ����ϴ� ��ü�� ��� LPPV���� ������ �Ķ���ͷ� ���� ��ȭ �Լ��� ����մϴ�.
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
		//SampleSH9 �Լ��� ������ȭ �Լ��� ���� �ش� ǥ���� ���� ������ ���ø��մϴ�.
		return max(0.0, SampleSH9(coefficients, surfaceWS.normal));
	}
#endif
}

//������ ����ũ�� ���� ����ŷ�� �׸��ڸ� ���ø��ϴ� �Լ�
float4 SampleBakedShadows(float2 lightMapUV, Surface surfaceWS) {
//LIGHTMAP_ON�� ������ ��ü������ ��ȿ
#if defined(LIGHTMAP_ON)
	return SAMPLE_TEXTURE2D(unity_ShadowMask, samplerunity_ShadowMask, lightMapUV);
#else
	//������ü �߿��� LPPV�� ������ ��ü�� ��� LPPV�� ����ũ�� �׸��ڸ� ���ø��Ͽ� �����մϴ�.
	if (unity_ProbeVolumeParams.x) {
		//LPPV ����Ʈ�ʰ� LPPV ������� ���� 3D�ؽ��Ŀ� ����ǰ� ���ø��ϴ� �Լ��� ������ �μ��� �ʿ�� �մϴ�.
		//�ٸ�, LPPV ������ ���ø����� ���� ���͸� �μ��� ���� �ʽ��ϴ�.
		return SampleProbeOcclusion(
			TEXTURE3D_ARGS(unity_ProbeVolumeSH, samplerunity_ProbeVolumeSH),
			surfaceWS.position, unity_ProbeVolumeWorldToObject,
			unity_ProbeVolumeParams.y, unity_ProbeVolumeParams.z,
			unity_ProbeVolumeMin.xyz, unity_ProbeVolumeSizeInv.xyz
		);
	}
	//LPPV�� �������� ���� ���� ��ü���� �Ϲ����� ������� �����͸� ���
	else {
		//���� ��ü�� ��� ���κ� ������� �����͸� ����ũ�� �׸��ڷμ� ��ȯ.
		return unity_ProbesOcclusion;
	}
#endif
}


struct GI {
	float3 diffuse;
	//������ ����ũ�� �⺻������ ����ũ�� ���� ���Ե� �������̹Ƿ� GI ����ü������ ���ɴϴ�.
	ShadowMask shadowMask;
};

GI GetGI(float2 lightMapUV, Surface surfaceWS) {
	GI gi;
	gi.diffuse = SampleLightMap(lightMapUV) + SampleLightProbe(surfaceWS);
	//GI������ ���������� �⺻������ ������ ����ũ�� ������� �ʵ����մϴ�.
	gi.shadowMask.always = false;
	gi.shadowMask.distance = false;
	gi.shadowMask.shadows = 1.0;
	//_SHADOW_MASK_ALWAYS�� Ȱ��ȭ �Ǿ��ִ� ��� ������ ����ũ ����� �����ϰ� ����ũ�� �׸��ڸ� ���ø�
#if defined(_SHADOW_MASK_ALWAYS)
	gi.shadowMask.always = true;
	gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
	//_SHADOW_MASK_DISTANCE�� Ȱ��ȭ �Ǿ��ִ� ��� ������ ����ũ ����� �����ϰ� ����ũ�� �׸��ڸ� ���ø�
#elif defined(_SHADOW_MASK_DISTANCE)
	gi.shadowMask.distance = true;
	gi.shadowMask.shadows = SampleBakedShadows(lightMapUV, surfaceWS);
#endif
	return gi;
}

#endif