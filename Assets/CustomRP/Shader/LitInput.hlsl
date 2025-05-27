#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

//UnityPerMaterial 버퍼를 사용해 GPU 인스턴싱된 프로퍼티 값을 가져오는 매크로 선언
#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

//Texture를 사용하기 위해선 TEXTURE2D 매크로를 통해 GPU 메모리에 텍스쳐를 업로드해야 합니다.
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

//DetailMap 텍스쳐를 GPU 메모리에 업로드
TEXTURE2D(_DetailMap);
SAMPLER(sampler_DetailMap);


//Emission Map 텍스쳐를 GPU 메모리에 업로드
TEXTURE2D(_EmissionMap);

//MaskMap 텍스쳐를 GPU 메모리에 업로드
TEXTURE2D(_MaskMap);

//NormalMap 텍스쳐를 GPU 메모리에 업로드
TEXTURE2D(_NormalMap);

//DetailNormaMap 텍스쳐를 GPU 메모리에 업로드
TEXTURE2D(_DetailNormalMap);

//유니티 GPU 인스턴싱을 사용하는 쉐이더의 경우 SRP Batcher를 아래와 같이 적용합니다.
UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
//텍스쳐 uniform 뒤에 _ST를 붙이면 해당 텍스쳐의 
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
	UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
	UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
	UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)
	UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

//입력받은 UV에 BaseMap 텍스쳐의 Tiling과 Offset을 적용하는 함수들
float2 TransformBaseUV(float2 baseUV, float2 detailUV = 0.0) {
	float4 baseST = INPUT_PROP(_BaseMap_ST);
	return baseUV * baseST.xy + baseST.zw;
}

//입력받은 UV에 DetailMap 텍스쳐의 Tiling과 Offset을 적용하는 함수들
float2 TransformDetailUV(float2 detailUV) {
	float4 detailST = INPUT_PROP(_DetailMap_ST);
	return detailUV * detailST.xy + detailST.zw;
}

float4 GetDetail(InputConfig c) {
	if (c.useDetail) {
		float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, c.detailUV);
		return map * 2.0 - 1.0;
	}
	return 0.0;
}

float4 GetMask(InputConfig c) {
	//hlsl에서 bool은 분기명령 대신 select 명령어로 처리되며, 따라서 해당 코드는 분기를 만들지 않습니다.
	// c.useMask ? SAMPLE_TEXTURE2D(...) : 1.0; 
	if (c.useMask) {
		return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, c.baseUV);
	}
	return 1.0;
}

float4 GetBase(InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
	float4 color = INPUT_PROP(_BaseColor);

	//useDetail이 활성화 되어있을 때만 디테일 마스크 맵을 샘플링
	if (c.useDetail) {
		//디테일맵의 R채널에는 색상에 영향 명암에 영향을 미치는 팩터가 저장되어있습니다.
		float4 detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
		//마스크맵의 B채널에는 디테일맵의 강도에 관한 팩터가 저장되어있습니다.
		//이는 BaseMap과 같은 스케일을 공유해야하므로 baseUV를 통해 샘플링합니다.
		float mask = GetMask(c).b;
		map.rgb = lerp(map.rgb, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
	}

	return map * color;
}

float GetCutoff(InputConfig c) {
	return INPUT_PROP(_Cutoff);
}

float GetMetallic(InputConfig c) {
	float metallic = INPUT_PROP(_Metallic);
	//Matallic값은 MaskMap의 R채널입니다.
	metallic *= GetMask(c).r;
	return metallic;
}

float GetSmoothness(InputConfig c) {
	float smoothness = INPUT_PROP(_Smoothness);
	//Smoothness값은 MaskMap의 A채널입니다.
	smoothness *= GetMask(c).a;

	//useDetail이 활성화 되어있을 때만 디테일 마스크 맵을 샘플링
	if (c.useDetail) {
		//Detail Albedo를 적용한 것과 같은 방식으로 Smoothness도 적용해줍니다.
		float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
		float mask = GetMask(c).b;
		smoothness = lerp(smoothness, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
	}

	return smoothness;
}

float GetFresnel(InputConfig c) {
	return INPUT_PROP(_Fresnel);
}

float GetOcclusion(InputConfig c) {
	float strength = INPUT_PROP(_Occlusion);
	float occlusion = GetMask(c).g;
	occlusion = lerp(occlusion, 1.0, strength);
	return occlusion;
}

float3 GetEmission(InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, c.baseUV);
	float4 color = INPUT_PROP(_EmissionColor);
	return map.rgb * color.rgb;
}

//탄젠트 공간상의 노멀을 샘플링하는 함수
float3 GetNormalTS(InputConfig c) {
	//노멀맵의 픽셀을 샘플링
	float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, c.baseUV);
	float scale = INPUT_PROP(_NormalScale);
	//해당 픽셀을 디코딩
	float3 normal = DecodeNormal(map, scale);

	//useDetail이 활성화 되어있을 때만 디테일 노멀 맵을 샘플링
	if (c.useDetail) {
		//디테일 노멀맵의 픽셀을 샘플링
		map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, c.detailUV);
		scale = INPUT_PROP(_DetailNormalScale) * GetMask(c).b;
		float3 detail = DecodeNormal(map, scale);
		//BlendNormalRNM을 사용해서 normal벡터를 기준으로 detail벡터를 회전시킵니다.
		normal = BlendNormalRNM(normal, detail);
	}

	return normal;
}

//탄젠트 공간에 정의된 노멀을 월드 공간으로 변환하는 함수
float3 NormalTangentToWorld(float3 normalTS, float3 normalWS, float4 tangentWS) {
	float3x3 tangentToWorld = CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
	//TransformTagentToWorld 메서드는 단순히 인자로 받은 탄젠트 공간의 노멀과 변환행렬의 행렬곱을 구하도록 되어있다.
	//mul(normalTS, tangentToWorld)
	return TransformTangentToWorld(normalTS, tangentToWorld);
}

#endif