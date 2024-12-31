using Unity.Collections;
using UnityEngine;
using UnityEngine.Rendering;

public class Lighting
{

    const string bufferName = "Lighting";
    const int maxDirLightCount = 4;

    //조명 데이터를 저장할 쉐이더 프로퍼티 ID
    static int
        //조명 개수
        dirLightCountId = Shader.PropertyToID("_DirectionalLightCount"),
        //조명 색상 배열
		dirLightColorsId = Shader.PropertyToID("_DirectionalLightColors"),
        //조명 방향 배열
		dirLightDirectionsId = Shader.PropertyToID("_DirectionalLightDirections"),
        //조명 그림자 데이터
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
        //그림자 랜더링
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
        //NativeArray는 GC에 의해 관리되지 않는 정적 배열입니다.
        //CullingResults의 visibleLights 속성은 현재 카메라에서 보이는 광원(VisibleLight)의 목록을 반환합니다.
        NativeArray<VisibleLight> visibleLights = cullingResults.visibleLights;
        int dirLightCount = 0;
        for (int i = 0; i < visibleLights.Length; i++)
        {
            VisibleLight visibleLight = visibleLights[i];
            if (visibleLight.lightType == LightType.Directional)
            {
                SetupDirectionalLight(dirLightCount++, ref visibleLight);
                //최대 랜더링 조명 개수를 넘으면 조명 데이터를 GPU로 넘기지 않는다.
                if (dirLightCount >= maxDirLightCount)
                {
                    break;
                }
            }
        }

        //CommandBuffer의 SetGlobalVector 메서드는 해당 씬을 랜더링할 때 사용될 수 있는 Global Parameter의 값을 설정할 수 있습니다.
        buffer.SetGlobalInt(dirLightCountId, visibleLights.Length);
        buffer.SetGlobalVectorArray(dirLightColorsId, dirLightColors);
        buffer.SetGlobalVectorArray(dirLightDirectionsId, dirLightDirections);
        buffer.SetGlobalVectorArray(dirLightShadowDataId, dirLightShadowData);
    }

    void SetupDirectionalLight(int index, ref VisibleLight visibleLight) 
    {
        dirLightColors[index] = visibleLight.finalColor;
        dirLightDirections[index] = -visibleLight.localToWorldMatrix.GetColumn(2);
        //그림자를 예약
        dirLightShadowData[index] = shadows.ReserveDirectionalShadows(visibleLight.light, index);
    }
}