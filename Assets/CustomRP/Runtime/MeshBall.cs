using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MeshBall : MonoBehaviour
{
    //인스턴스화 할 머티리얼의 각 프로퍼티 아이디
    static int baseColorId = Shader.PropertyToID("_BaseColor"),
                metallicId = Shader.PropertyToID("_Metallic"),
                smoothnessId = Shader.PropertyToID("_Smoothness");

    [SerializeField]
    Mesh mesh = default;

    [SerializeField]
    Material material = default;

    Matrix4x4[] matrices = new Matrix4x4[1023];
    Vector4[] baseColors = new Vector4[1023];
    float[] metallic = new float[1023],
            smoothness = new float[1023];


    MaterialPropertyBlock block;

    void Start()
    {
        for (int i = 0; i < matrices.Length; i++)
        {
            //Matrix4x4.TRS 메서드는 물체의 위치, 회전, 스케일을 받아서 변환행렬을 생성해주는 함수입니다.
            matrices[i] = Matrix4x4.TRS(
                Random.insideUnitSphere * 10f, Quaternion.Euler(
                    Random.value * 360f, Random.value * 360f, Random.value * 360f
                ), Vector3.one * Random.Range(0.5f, 1.5f)
            );

            baseColors[i] =
                new Vector4(Random.value, Random.value, Random.value, Random.Range(0.5f, 1f));
            metallic[i] = Random.value < 0.25f ? 1f : 0f;
            smoothness[i] = Random.Range(0.05f, 0.95f);
        }
    }

    void Update()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
            block.SetVectorArray(baseColorId, baseColors);
            block.SetFloatArray(metallicId, metallic);
            block.SetFloatArray(smoothnessId, smoothness);
        }
        //DrawMeshInstanced 메서드는 여러개의 객체를 생성할때 사용하며, Transform값을 변환행렬로 받습니다.
        //또한 MaterialPropertyBlock을 인수로 넘겨 해당 인스턴스된 머티리얼에 각기 다른 머티리얼 프로퍼티를 적용할 수 있습니다.
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block);
    }
}
