#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

//쉐도우 마스크가 오쿨루젼 프로브를 통해 돌아갈 경우, Unity의 GPU Instancing을 방해한다. 이는 SHADOWS_SHADOWMASK 키워드를 정의하는 것으로 해결할 수 있다.
#if defined(_SHADOW_MASK_ALWAYS) || defined(_SHADOW_MASK_DISTANCE)
	#define SHADOWS_SHADOWMASK
#endif

#include "Graphics/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "UnityInput.hlsl"
/*
//오브젝트 좌표를 월드 좌표로 변환하는 함수
float3 TransformObjectToWorld(float3 positionOS) {
	return mul(unity_ObjectToWorld, float4(positionOS, 1.0)).xyz;
}
//월드 좌표를 클립 좌표로 변환하는 함수
float4 TransformWorldToHClip(float3 positionWS) {
	return mul(unity_MatrixVP, float4(positionWS, 1.0));
}
*/

//해당 라이브러리는 UNITY_MATRIX_M 매크로 변수의 존재를 가정하므로 이를 선언하고 이를 unityObjectToWorld 매트릭스 값으로 설정합니다.
#define UNITY_MATRIX_M unity_ObjectToWorld
//SpaceTransforms.hlsl에서 가정하는 매크로들을 각 값에 맞게 설정하여 선언합니다.
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_P glstate_matrix_projection
//Unity 2022 이상에선 다음 매크로들을 추가적으로 선언해줍니다.
#define UNITY_MATRIX_I_V unity_MatrixInvV
#define UNITY_PREV_MATRIX_M unity_prev_MatrixM
#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM

//유니티의 GPU Instancing을 지원하기 위한 라이브러리 포함
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
//Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl 패키지는 위 주석의 함수를 포함하는 유니티 쉐이더 라이브러리이다.
#include "Graphics/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"

float Square(float v) {
	return v * v;
}

//두 지점사이의 제곱 거리를 계산하는 함수
float DistanceSquared(float3 pA, float3 pB) {
	return dot(pA - pB, pA - pB);
}

#endif