using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    /* ������ ���ؽ�Ʈ���� ���������� �������� �ʴ� ����(�������Ϸ�, ������ ����� ��)��
     * CommandBuffer�� ��� ������ ���ؽ�Ʈ���� ������ �� �ִ�    */
    const string bufferName = "Render Camera";
    CommandBuffer buffer = new CommandBuffer {
                                name = bufferName
                            };

    ScriptableRenderContext context;
    Camera camera;

    //�ø� ����� ������ CullingResults ����ü
    CullingResults cullingResults;

    //�������� ����� ���̴� �н��� ID
    static ShaderTagId 
        unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"),
        litShaderTagId = new ShaderTagId("CustomLit");

    Lighting lighting = new Lighting();

    public void Render(ScriptableRenderContext context, Camera camera, bool useDynamicBatching, bool useGPUInstancing, ShadowSettings shadowSettings)
    {
        this.context = context;
        this.camera = camera;

        PrepareBuffer();
        PrepareForSceneWindow();
        if (!Cull(shadowSettings.maxDistance))
        {
            return;
        }

        buffer.BeginSample(SampleName);
        ExecuteBuffer();
        lighting.Setup(context, cullingResults, shadowSettings);
        buffer.EndSample(SampleName);
        Setup();
        DrawVisibleGeometry(useDynamicBatching, useGPUInstancing);
        DrawUnsupportedShaders();
        DrawGizmos();
        lighting.Cleanup();
        Submit();
    }
    
    void Setup()
    {
        /* ���� ������ �ǰ��ִ� ī�޶��� POV, World Transform���� �����Ͽ�
         * ��������� ������ ���ؽ�Ʈ�� ����   
         * �ش� �۾��� �־�� ī�޶��� ��Ⱦ��, ���� Ʈ������, POV���� �´�
         * ������ �̹����� ���� �� �ִ�.    */
        context.SetupCameraProperties(camera);
        /* ������ ������ ��� �ڵ����� ����������,
         * ī�޶��� ���� Ÿ���� ���� �ؽ����� ���
         * ������ ������ �ߴ� ������� �������� ���� �����Ƿ�,
         * ClearReanderTarget �޼���� �̸� �����ش�.     */
        buffer.ClearRenderTarget(true, true, Color.clear);
        CameraClearFlags flags = camera.clearFlags;
        /* BeginSample�� ������ ���۵� ����Ƽ �������Ϸ� ������ 
         * ������ �̸��� �۾����� CommandBuffer�� �߰��� �� �ִ�.    */
        buffer.BeginSample(SampleName);
        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth,
            flags != CameraClearFlags.Color,
            flags == CameraClearFlags.Color ?
                camera.backgroundColor.linear : Color.clear
        );
        /*������ �ϴ� ������ �������ϸ� �� ���̹Ƿ�,
         * ī�޶� ������Ƽ�� �����ϱ� ����
         * ���ؽ�Ʈ�� �����ϱ� ������ ����
         * �������ϸ� ����/�� ����� �����Ѵ�.     */
        ExecuteBuffer();
    }
    //������ ���ؽ�Ʈ�� ī�޶� ���� ������ �۾��� ����
    //������Ī ��� �� GPU �ν��Ͻ� ��뿡 ���� ���� �߰�
    void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing)
    {
        /* �������� ȣ���ϱ� ���� DrawingSettings�� FilteringSettings ����ü�� ����
         * ������ ���� ���� �Ѱܾ��Ѵ�.
         * �� �������� �׳� �⺻ ���ð��� ����ߴ�.
         */
        var sortingSettings = new SortingSettings(camera)
        {
            //CommonOpaque�� ������ ��ü ���� �׸���.
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(
            unlitShaderTagId, sortingSettings
            )
        {
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing,
            //PerObjectData�� SRP���� GPU�� ������ ��ü�� �߰����� �����͸� �����մϴ�.
            //�ߺ� ������ | �����ڸ� ����մϴ�. ex) PerObjectData.Lightmaps | PerObjectData.LightProbe
            //Lightmaps�� ����ŷ�� ����Ʈ �ʿ� ���� ��ü�� ����Ʈ �� uv �����͵��� GPU�� �����մϴ�.
            //LightProbe�� �� ��ü�� ����ϴ� ����Ʈ ���κ꿡 ���� ������ GPU�� �����մϴ�.
            //LightProbeProxyVolume(LPPV)�� �������Ǵ� ��ü�� LightProbeProxyVolume ������Ʈ�� ������ ������, �� ������ GPU�� �����մϴ�.
            //LPPV�� ���� ��ü�� ���� �������� 3D Float Texture�� �����մϴ�.
            //ShadowMask�� ��ü�� ������ ����ũ �����͸� GPU�� �����ϵ��� �����մϴ�.
            //OcclusionProbe�� ������ü�� ����Ʈ ���κ꿡 ����ũ�� �׸��� ������ GPU�� �����ϵ��� �����մϴ�.
            //OcclusionProbeProxyVolume�� �� ������Ʈ�� LPPV��  ����ũ�� �׸��� ������ GPU�� �����ϵ��� �����մϴ�.
            //ReflectionProbes�� ���� �������ϴ� ��ü�� ���� ReflectionProbe�� ť����̳� �ݻ� ������ġ ���� �����ϵ��� �����մϴ�.
            perObjectData = PerObjectData.Lightmaps | PerObjectData.LightProbe | PerObjectData.LightProbeProxyVolume | PerObjectData.ShadowMask | PerObjectData.OcclusionProbe
                            | PerObjectData.OcclusionProbeProxyVolume | PerObjectData.ReflectionProbes
        };
        //LitShader�� ������
        drawingSettings.SetShaderPassName(1, litShaderTagId);
        //Opaque ��ü�� ������
        /* ������ ��ü�� ������ �� �� Z-buffer�� ���� ������, ������ ��ü�� �׷��� �ʱ� ������,
         * ���� ��ü�� �׸��� DrawSkybox�� ȣ���� ��� ����ü�� �� �ȼ��� �νĵǾ�
         * �ش� �ȼ����� Skybox�� ���׸��� �ȴ�.     */
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );

        context.DrawSkybox(camera);

        //CommonTransparent�� ���� ��ü ���� �׸���.
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        //���� ��ü�� ������
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;

        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
    }

    //������ ���ؽ�Ʈ ť�� ���Ե� ������� �۾��� ����
    void Submit()
    {
        buffer.EndSample(SampleName);
        ExecuteBuffer();
        /* ���ؽ�Ʈ ����. �츮�� ���ؽ�Ʈ�� ������ �۾����� �� Submit�޼��带 ȣ���ϱ� ������ ���ÿ� ���̸�
         * ������� �ʰ� �����Ǵٰ�, ������ ���������� ����ȴ�.   */
        context.Submit();
    }
    void ExecuteBuffer()
    {
        //ExecuteCommandBuffer �޼���� �ش� ������ ���ؽ�Ʈ�� �־��� ������ ����� �����մϴ�.
        context.ExecuteCommandBuffer(buffer);
        /* ����� ������ ���ؽ�Ʈ�� �����ߴٰ� �ؼ� ���ۿ��� ���������� �����Ƿ�,
         * Clear �޼��带 ���� ���� ������ �ݴϴ�.    */
        buffer.Clear();
    }
    //�ø��� ������ �޼���
    bool Cull(float maxShadowDistance)
    {
        //�ø� �Ķ���͸� ī�޶�� ���� ������ "p" ������ �����մϴ�.
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            //�ø� ����� shadowDistance�� �����մϴ�.
            //�̶� ī�޶� �� �� �ִ� �Ÿ����� �� �׸��ڴ� �������� �ǹ� �����Ƿ� ī�޶��� far clip�Ÿ��� �����մϴ�.
            p.shadowDistance = Mathf.Min(maxShadowDistance, camera.farClipPlane);
            //���ؽ�Ʈ�� Cull�޼��带 ���� �ø��� �����ϸ� CullingResults ����ü�� ��ȯ�Ѵ�.
            //ref Ű����� ������ü�� �ּҰ� �����͸� �ѱ��, ����ü�� �ԷµǾ �������� �ʴ´�.
            cullingResults = context.Cull(ref p);
            return true;
        }
        return false;
    }
}
