using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomRenderPipeline : RenderPipeline
{
    CameraRenderer renderer = new CameraRenderer();
    bool useDynamicBatching, useGPUInstancing;
    ShadowSettings shadowSettings;

    public CustomRenderPipeline(bool useDynamicBatching, bool useGPUInstancing, bool useSRPBatcher, ShadowSettings shadowSettings)
    {
        this.useDynamicBatching = useDynamicBatching;
        this.useGPUInstancing = useGPUInstancing;
        this.shadowSettings = shadowSettings;
        //SRP ��ġ�� ����ϵ��� ����
        //���� ��Ī�� ����� ��� SRP��ó�� �켱 ����ǹǷ� useScriptableRenderPipelineBatching�� false�� �ٲپ��ش�.
        GraphicsSettings.useScriptableRenderPipelineBatching = useSRPBatcher;
        //Unity���� ���� ���⸦ ���� �������� ��ȯ�ϵ��� �մϴ�.
        GraphicsSettings.lightsUseLinearIntensity = true;
    }

    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        for(int i = 0; i < cameras.Length; i++)
        {
            renderer.Render(context, cameras[i], useDynamicBatching, useGPUInstancing, shadowSettings);
        }
    }
}
