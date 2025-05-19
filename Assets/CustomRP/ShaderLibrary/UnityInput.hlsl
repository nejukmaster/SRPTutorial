#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//unity_ObjectToWorld는 C#에서 선언된 유니폼입니다.
//해당 유니폼은 오브젝트 좌표를 월드 좌표로 변환하는 변환행렬을 담고 있습니다.
CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject; 
	float4 unity_LODFade;
	float4 unity_WorldTransformParams;
	//유니티의 베이크된 그림자의 경우 동적객체의 라이트 프로브에 베이크하여 나타내며, 이를 오쿨루전 프로브라고 한다.
	float4 unity_ProbesOcclusion;
	float3 _WorldSpaceCameraPos;

	//PerObjectData.Lightmaps로 인해 전달되는 객체의 라이트 맵 좌표
	float4 unity_LightmapST;
	float4 unity_DynamicLightmapST;

	//PerObjectData.LightProbe로 인해 전달되는 객체가 사용하는 LightProbe 정보
	float4 unity_SHAr;
	float4 unity_SHAg;
	float4 unity_SHAb;
	float4 unity_SHBr;
	float4 unity_SHBg;
	float4 unity_SHBb;
	float4 unity_SHC;

	//LPPV가 전달하는 객체의 3D 볼륨 데이터
	float4 unity_ProbeVolumeParams;
	float4x4 unity_ProbeVolumeWorldToObject;
	float4 unity_ProbeVolumeSizeInv;
	float4 unity_ProbeVolumeMin;

CBUFFER_END
//해당 유니폼은 카메라 별로 달라지는 View-Projection 행렬을 담습니다.
float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;

#endif