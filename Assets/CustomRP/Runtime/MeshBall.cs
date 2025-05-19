using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;


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

            //각 인스턴스에 대한 라이트 프로브를 수동 생성하기 위해 각 인스턴스의 생성될 위치를 가져옵니다.
            var positions = new Vector3[1023];
            for (int i = 0; i < matrices.Length; i++)
            {
                //각 인스턴스의 위치는 변환행렬의 마지막 열에 저장되어있습니다.
                positions[i] = matrices[i].GetColumn(3);
            }
            //라이트 프로브의 정보는 SphericalHarmonicsL2 객체로 전달됩니다.
            var lightProbes = new SphericalHarmonicsL2[1023];
            var occlusionProbes = new Vector4[1023];
            //CalculateInterpolatedLightAndOcclusionProbes 스태틱 메서드로 라이트 프로브 배열을 채웁니다. 이때 세번째 인수는 LPPV를 사용할 떄 Occlusion 데이터를 저장할 주소입니다.
            LightProbes.CalculateInterpolatedLightAndOcclusionProbes(
                positions, lightProbes, occlusionProbes
            );
            //만든 SphericalharmonicsL2 배열을 block에 복사하여 등록해줍니다.
            block.CopySHCoefficientArraysFrom(lightProbes);
            //얻은 오클루젼 데이터를 등록해줍니다.
            block.CopyProbeOcclusionArrayFrom(occlusionProbes);
        }
        //DrawMeshInstanced 메서드는 여러개의 객체를 생성할때 사용하며, Transform값을 변환행렬로 받습니다.
        //또한 MaterialPropertyBlock을 인수로 넘겨 해당 인스턴스된 머티리얼에 각기 다른 머티리얼 프로퍼티를 적용할 수 있습니다.
        //쉐도우 캐스팅 모드는 인스턴스가 그림자를 캐스팅할지 여부, 레이어, 카메라를 정합니다.
        //LightProbeUsage는 인스턴스의 라이트 프로브의 사용 여부를 정합니다.
        Graphics.DrawMeshInstanced(mesh, 0, material, matrices, 1023, block, ShadowCastingMode.On, true, 0, null, LightProbeUsage.CustomProvided);
    }
}
