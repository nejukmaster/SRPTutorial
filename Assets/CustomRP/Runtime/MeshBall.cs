using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MeshBall : MonoBehaviour
{
    //�ν��Ͻ�ȭ �� ��Ƽ������ �� ������Ƽ ���̵�
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
            //Matrix4x4.TRS �޼���� ��ü�� ��ġ, ȸ��, �������� �޾Ƽ� ��ȯ����� �������ִ� �Լ��Դϴ�.
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
        //DrawMeshInstanced �޼���� �������� ��ü�� �����Ҷ� ����ϸ�, Transform���� ��ȯ��ķ� �޽��ϴ�.
        //���� MaterialPropertyBlock�� �μ��� �Ѱ� �ش� �ν��Ͻ��� ��Ƽ���� ���� �ٸ� ��Ƽ���� ������Ƽ�� ������ �� �ֽ��ϴ�.
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block);
    }
}
