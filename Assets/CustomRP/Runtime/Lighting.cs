using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{

    const string bufferName = "Lighting";
    const int maxDirLightCount = 4;

    //���� �����͸� ������ ���̴� ������Ƽ ID
    static int
        //���� ����
        dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
        //���� ���� �迭
		dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
        //���� ���� �迭
		dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections"),
        //���� �׸��� ������
        dirLightShadowDataId = Shader.PropertyToID("_DirectionalLightShadowData");
    static Vector4[]
        dirLightColors = new Vector4[maxDirLightCount],
        dirLightDirections = new Vector4[maxDirLightCount],
        dirLightShadowData = new Vector4[maxDirLightCount];


    CullingResults cullingResults;

    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    Shadows shadows = new Shadows();

    public void Setup(ScriptableRenderContext context, CullingResults cullingResults, ShadowSettings shadowSettings)
    {
        this.cullingResults = cullingResults;
        buffer.BeginSample(bufferName);
        shadows.Setup(context, cullingResults, shadowSettings);
        SetupLights();
        //�׸��� ������
        shadows.Render();
        buffer.EndSample(bufferName);
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }

    public void Cleanup()
    {
        shadows.Cleanup();
    }

    void SetupLights()
    {
        //NativeArray�� GC�� ���� �������� �ʴ� ���� �迭�Դϴ�.
        //CullingResults�� visibleLights �Ӽ��� ���� ī�޶󿡼� ���̴� ����(VisibleLight)�� ����� ��ȯ�մϴ�.
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                //�ִ� ������ ���� ������ ������ ���� �����͸� GPU�� �ѱ��� �ʴ´�.
                if (dirLightCount >= maxDirLightCount)
                {
                    break;
                }
            }
        }

        //CommandBuffer�� SetGlobalVector �޼���� �ش� ���� �������� �� ���� �� �ִ� Global Parameter�� ���� ������ �� �ֽ��ϴ�.
        buffer.SetGlobalInt(dirLightCountId, visibleLights.Length);
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
        buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }

    void SetupDirectionalLight(int index, ref VisibleLight visibleLight) 
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        //�׸��ڸ� ����
        dirLightShadowData[index] = shadows.ReserveDirectionalShadows(visibleLight.light, index);
    }
}