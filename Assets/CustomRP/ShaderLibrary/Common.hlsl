#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

//쉐도우 마스크가 오쿨루젼 프로브를 통해 돌아갈 경우, Unity의 GPU Instancing을 방해한다. 이는 SHADOWS_SHADOWMASK 키워드를 정의하는 것으로 해결할 수 있다.
#if defined(_SHADOW_MASK_ALWAYS) || defined(_SHADOW_MASK_DISTANCE)
	#define SHADOWS_SHADOWMASK
#endif

#include "Graphics/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
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

void ClipLOD(float2 positionCS, float fade) {
#if defined(LOD_FADE_CROSSFADE)
	//반투명 그림자에서 사용한 그래디언트 노이즈를 디더링에 사용합니다.
	float dither = InterleavedGradientNoise(positionCS.xy, 0);
	//LOD의 크로스 페이드 팩터를 검사하여 음수 팩터(다음 LOD)의 경우 더하고 그렇지 않을 경우(이전 LOD)의 경우 빼서 클리핑
	clip(fade + (fade < 0.0 ? dither : -dither));
#endif
}

//노멀맵의 픽셀을 디코딩하는 함수
//노멀맵은 RGB에 XYZ를 저장하며, 법선벡터는 Surface에서 제공되므로 B채널 샘플링을 생략해도 무방합니다.
//플랫폼에 따라 노멀맵이 변경되기도하며, DXT5(BC3) 포멧으로 압축된 텍스쳐는 UnpackNormalRGB로, 그렇지 않은 경우는 UnpackNormalmapRGorAG 메서드로 텍스쳐의 압축을 해제합니다.
float3 DecodeNormal(float4 sample, float scale) {
#if defined(UNITY_NO_DXT5nm)
	return normalize(UnpackNormalRGB(sample, scale));
#else
	return normalize(UnpackNormalmapRGorAG(sample, scale));
#endif
}

#endif