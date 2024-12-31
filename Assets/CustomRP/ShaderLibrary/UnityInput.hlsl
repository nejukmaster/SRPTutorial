#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//unity_ObjectToWorld는 C#에서 선언된 유니폼입니다.
//해당 유니폼은 오브젝트 좌표를 월드 좌표로 변환하는 변환행렬을 담고 있습니다.
CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject; 
	float4 unity_LODFade;
	float4 unity_WorldTransformParams;
	float3 _WorldSpaceCameraPos;
CBUFFER_END
//해당 유니폼은 카메라 별로 달라지는 View-Projection 행렬을 담습니다.
float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;

#endif