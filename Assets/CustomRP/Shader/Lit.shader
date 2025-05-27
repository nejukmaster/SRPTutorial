Shader "Custom RP/Lit" {
	
	Properties {
		_BaseMap("Texture", 2D) = "white" {}
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)

		//Unity의 라이트매퍼는 머티리얼의 투명/불투명 판단을 할 때, "_MainTex"와 "_Color" 프로퍼티를 참조하도록 하드코딩되어있다.
		//따라서 셰이더에 해당 프로퍼티를 추가하고, Editor를 통해 "_BaseMap", "_BaseColor"와 연결해준다.
		[HideInInspector] _MainTex("Texture for Lightmap", 2D) = "white" {}
		[HideInInspector] _Color("Color for Lightmap", Color) = (0.5, 0.5, 0.5, 1.0)

		//방출하는 빛을 결정하는 Emission 텍스쳐
		[NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
		[HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)

		//표면의 노멀 벡터를 결정하는 NormalMap 텍스쳐
		//노멀맵은 표면의 탄젠트 공간에서 법선벡터 방향 요소를 B, Tangent 방향 요소를 G,Bitangent 방향 요소를 R에 저장합니다.
		[Toggle(_NORMAL_MAP)] _NormalMapToggle ("Normal Map", Float) = 0
		[NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
		_NormalScale("Normal Scale", Range(0, 1)) = 1

		//디테일 맵 텍스쳐
		//BaseMap보다 높은 타일링으로 더욱 복잡한 표현을 담당하는 텍스쳐입니다.
		//linearGrey는 텍스쳐의 디폴트가 회색 텍스쳐로 바뀝니다.
		[Toggle(_DETAIL_MAP)] _DetailMapToggle ("Detail Maps", Float) = 0
		_DetailMap("Details", 2D) = "linearGrey" {}
		[NoScaleOffset] _DetailNormalMap("Detail Normals", 2D) = "bump" {}
		_DetailAlbedo("Detail Albedo", Range(0, 1)) = 1
		_DetailSmoothness("Detail Smoothness", Range(0, 1)) = 1
		_DetailNormalScale("Detail Normal Scale", Range(0, 1)) = 1

		[Toggle(_MASK_MAP)] _MaskMapToggle ("Mask Map", Float) = 0
		//메탈릭 맵과 스무스니스 맵, 오쿨루전 맵을 합친 MaskMap 정의
		[NoScaleOffset] _MaskMap("Mask (MODS)", 2D) = "white" {}

		_Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		_Metallic ("Metallic", Range(0, 1)) = 0
		_Occlusion ("Occlusion", Range(0, 1)) = 1
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
		_Fresnel ("Fresnel", Range(0, 1)) = 1

		[Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0
		[Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0
		//Enum 태그를 사용한 속성은 C#으로 정의된 Enum의 형태로 인스펙터 창에 표기된다.
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
		[Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1

		[KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0
		[Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1
	}
	
	SubShader {
		HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "../ShaderLibrary/InputConfig.hlsl"
		#include "LitInput.hlsl"
		ENDHLSL
		
		Pass {
			Tags {
				"LightMode" = "CustomLit"
			}
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]

			HLSLPROGRAM
			//OpenGL ES 2.0에서는 셰이더 코드에서의 루프가 안되므로 아예 OpenGL ES 2.0 버전은 컴파일 되지 않도록 막습니다.
			#pragma target 3.5
			#pragma shader_feature _CLIPPING
			#pragma shader_feature _PREMULTIPLY_ALPHA
			#pragma shader_feature _RECEIVE_SHADOWS
			//노멀맵, 마스크맵, 디테일맵은 LitPass에서만 유효하므로 Toggle에 대한 Shader Feature도 CustomLitPass에만 선언해줍니다.
			#pragma shader_feature _NORMAL_MAP
			#pragma shader_feature _MASK_MAP
			#pragma shader_feature _DETAIL_MAP

			//PCF필터링 모드를 구분할 멀티 컴파일 프로퍼티 선언
			#pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
			#pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
			//LOD 크로스 페이딩 사용여부를 나타내는 키워드
			#pragma multi_compile _ LOD_FADE_CROSSFADE
			//쉐도우 마스크 사용 여부에 관한 키워드 프로퍼티
			//쉐도우 마스크 모드에 대한 키워드 프로퍼티
			#pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile_instancing

			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
			#include "LitPass.hlsl"
			ENDHLSL
		}
		//메타패스는 유니티가 간접광을 계산할때 사용하는 패스입니다.
		Pass{
			Tags{
				"LightMode" = "Meta"
			}
			Cull Off

			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment
			#include "MetaPass.hlsl"
			ENDHLSL
		}
		Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}

			ColorMask 0

			HLSLPROGRAM
			#pragma target 3.5
			#pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
			#pragma multi_compile_instancing
			//LOD 그룹을 통해 컬링된 결과는 그림자 맵에도 적용되어야합니다.
			#pragma multi_compile _ LOD_FADE_CROSSFADE
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
		}
	}
	//CustomEditor 키워드는 해당 쉐이더로 생성된 머티리얼의 인스펙터 GUI를 ShaderGUI를 상속한 C#클래스로 커스텀 할 수 있게 해준다.
	CustomEditor "CustomShaderGUI"
}
