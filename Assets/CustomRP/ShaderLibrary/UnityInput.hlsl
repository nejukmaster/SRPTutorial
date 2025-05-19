#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//unity_ObjectToWorld�� C#���� ����� �������Դϴ�.
//�ش� �������� ������Ʈ ��ǥ�� ���� ��ǥ�� ��ȯ�ϴ� ��ȯ����� ��� �ֽ��ϴ�.
CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject; 
	float4 unity_LODFade;
	float4 unity_WorldTransformParams;
	//����Ƽ�� ����ũ�� �׸����� ��� ������ü�� ����Ʈ ���κ꿡 ����ũ�Ͽ� ��Ÿ����, �̸� ������� ���κ��� �Ѵ�.
	float4 unity_ProbesOcclusion;
	float3 _WorldSpaceCameraPos;

	//PerObjectData.Lightmaps�� ���� ���޵Ǵ� ��ü�� ����Ʈ �� ��ǥ
	float4 unity_LightmapST;
	float4 unity_DynamicLightmapST;

	//PerObjectData.LightProbe�� ���� ���޵Ǵ� ��ü�� ����ϴ� LightProbe ����
	float4 unity_SHAr;
	float4 unity_SHAg;
	float4 unity_SHAb;
	float4 unity_SHBr;
	float4 unity_SHBg;
	float4 unity_SHBb;
	float4 unity_SHC;

	//LPPV�� �����ϴ� ��ü�� 3D ���� ������
	float4 unity_ProbeVolumeParams;
	float4x4 unity_ProbeVolumeWorldToObject;
	float4 unity_ProbeVolumeSizeInv;
	float4 unity_ProbeVolumeMin;

CBUFFER_END
//�ش� �������� ī�޶� ���� �޶����� View-Projection ����� ����ϴ�.
float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;

#endif