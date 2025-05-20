#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

//������ ����ũ�� ������� ���κ긦 ���� ���ư� ���, Unity�� GPU Instancing�� �����Ѵ�. �̴� SHADOWS_SHADOWMASK Ű���带 �����ϴ� ������ �ذ��� �� �ִ�.
#if defined(_SHADOW_MASK_ALWAYS) || defined(_SHADOW_MASK_DISTANCE)
	#define SHADOWS_SHADOWMASK
#endif

#include "Graphics/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "UnityInput.hlsl"
/*
//������Ʈ ��ǥ�� ���� ��ǥ�� ��ȯ�ϴ� �Լ�
float3 TransformObjectToWorld(float3 positionOS) {
	return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
}
//���� ��ǥ�� Ŭ�� ��ǥ�� ��ȯ�ϴ� �Լ�
float4 TransformWorldToHClip(float3 positionWS) {
	return mul(unity_MatrixVP, float4(positionWS, 1.0));
}
*/

//�ش� ���̺귯���� UNITY_MATRIX_M ��ũ�� ������ ���縦 �����ϹǷ� �̸� �����ϰ� �̸� unityObjectToWorld ��Ʈ���� ������ �����մϴ�.
#define UNITY_MATRIX_M unity_ObjectToWorld
//SpaceTransforms.hlsl���� �����ϴ� ��ũ�ε��� �� ���� �°� �����Ͽ� �����մϴ�.
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection
//Unity 2022 �̻󿡼� ���� ��ũ�ε��� �߰������� �������ݴϴ�.
#define UNITY_MATRIX_I_V unity_MatrixInvV
#define UNITY_PREV_MATRIX_M unity_prev_MatrixM
#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM

//����Ƽ�� GPU Instancing�� �����ϱ� ���� ���̺귯�� ����
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
//Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl ��Ű���� �� �ּ��� �Լ��� �����ϴ� ����Ƽ ���̴� ���̺귯���̴�.
#include "Graphics/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

float Square(float v) {
	return v * v;
}

//�� ���������� ���� �Ÿ��� ����ϴ� �Լ�
float DistanceSquared(float3 pA, float3 pB) {
	return dot(pA - pB, pA - pB);
}

#endif