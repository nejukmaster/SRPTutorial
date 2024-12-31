#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

//unity_ObjectToWorld�� C#���� ����� �������Դϴ�.
//�ش� �������� ������Ʈ ��ǥ�� ���� ��ǥ�� ��ȯ�ϴ� ��ȯ����� ��� �ֽ��ϴ�.
CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject; 
	float4 unity_LODFade;
	float4 unity_WorldTransformParams;
	float3 _WorldSpaceCameraPos;
CBUFFER_END
//�ش� �������� ī�޶� ���� �޶����� View-Projection ����� ����ϴ�.
float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;

#endif