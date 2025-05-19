using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


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

            baseColors[i] = new Vector4(Random.value, Random.value, Random.value, Random.Range(0.5f, 1f));
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

            //�� �ν��Ͻ��� ���� ����Ʈ ���κ긦 ���� �����ϱ� ���� �� �ν��Ͻ��� ������ ��ġ�� �����ɴϴ�.
            var positions = new Vector3[1023];
            for (int i = 0; i < matrices.Length; i++)
            {
                //�� �ν��Ͻ��� ��ġ�� ��ȯ����� ������ ���� ����Ǿ��ֽ��ϴ�.
                positions[i] = matrices[i].GetColumn(3);
            }
            //����Ʈ ���κ��� ������ SphericalHarmonicsL2 ��ü�� ���޵˴ϴ�.
            var lightProbes = new SphericalHarmonicsL2[1023];
            var occlusionProbes = new Vector4[1023];
            //CalculateInterpolatedLightAndOcclusionProbes ����ƽ �޼���� ����Ʈ ���κ� �迭�� ä��ϴ�. �̶� ����° �μ��� LPPV�� ����� �� Occlusion �����͸� ������ �ּ��Դϴ�.
            LightProbes.CalculateInterpolatedLightAndOcclusionProbes(
                positions, lightProbes, occlusionProbes
            );
            //���� SphericalharmonicsL2 �迭�� block�� �����Ͽ� ������ݴϴ�.
            block.CopySHCoefficientArraysFrom(lightProbes);
            //���� ��Ŭ���� �����͸� ������ݴϴ�.
            block.CopyProbeOcclusionArrayFrom(occlusionProbes);
        }
        //DrawMeshInstanced �޼���� �������� ��ü�� �����Ҷ� ����ϸ�, Transform���� ��ȯ��ķ� �޽��ϴ�.
        //���� MaterialPropertyBlock�� �μ��� �Ѱ� �ش� �ν��Ͻ��� ��Ƽ���� ���� �ٸ� ��Ƽ���� ������Ƽ�� ������ �� �ֽ��ϴ�.
        //������ ĳ���� ���� �ν��Ͻ��� �׸��ڸ� ĳ�������� ����, ���̾�, ī�޶� ���մϴ�.
        //LightProbeUsage�� �ν��Ͻ��� ����Ʈ ���κ��� ��� ���θ� ���մϴ�.
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block, ShadowCastingMode.On, true, 0, null, LightProbeUsage.CustomProvided);
    }
}
