using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperty : MonoBehaviour
{
    static int baseColorId = Shader.PropertyToID("_BaseColor"),
                cutoffId = Shader.PropertyToID("_Cutoff"),
                //mataliic과 smoothness 프로퍼티 추가
                metallicId = Shader.PropertyToID("_Metallic"),
		        smoothnessId = Shader.PropertyToID("_Smoothness");

    //이 스크립트를 사용하는 모든 객체들이 개별적 랜더러에 접근할 MaterialPropertyBlock입니다
    static MaterialPropertyBlock block;

    [SerializeField]
    Color baseColor = Color.white;

    [SerializeField, Range(0f, 1f)]
    float cutoff = 0.5f, metallic = 0f, smoothness = 0.5f;

    //OnValidate는 구성요소가 로드되거나 변경될때 호출됩니다.
    void OnValidate()
    {
        //MaterialPropertyBlock을 통해 랜더러에 접근하기 전에 블록을 초기화합니다.
        if (block == null)
        {
            block = new MaterialPropertyBlock();
        }
        block.SetColor(baseColorId, baseColor);
        block.SetFloat(cutoffId, cutoff);
        block.SetFloat(metallicId, metallic);
        block.SetFloat(smoothnessId, smoothness);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }

    //OnValidate 메서드는 빌드에선 호출되지 않기에 이는 수동으로 호출해줍니다.
    void Awake()
    {
        OnValidate();
    }
}
