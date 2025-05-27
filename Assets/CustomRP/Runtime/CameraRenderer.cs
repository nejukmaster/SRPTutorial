using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    /* 랜더링 컨텍스트에서 직접적으로 지원하지 않는 동작(프로파일러, 프레임 디버거 등)은
     * CommandBuffer에 담아 랜더링 컨텍스트에서 실행할 수 있다    */
    const string bufferName = "Render Camera";
    CommandBuffer buffer = new CommandBuffer {
                                name = bufferName
                            };

    ScriptableRenderContext context;
    Camera camera;

    //컬링 결과를 저장할 CullingResults 구조체
    CullingResults cullingResults;

    //랜더링을 허용할 셰이더 패스의 ID
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
        /* 현재 랜더링 되고있는 카메라의 POV, World Transform등을 참조하여
         * 투영행렬을 랜더링 컨텍스트에 적용   
         * 해당 작업이 있어야 카메라의 종횡비, 월드 트랜스폼, POV값에 맞는
         * 랜더링 이미지를 얻을 수 있다.    */
        context.SetupCameraProperties(camera);
        /* 프레임 버퍼의 경우 자동으로 지워지지만,
         * 카메라의 랜더 타깃이 랜더 텍스쳐일 경우
         * 이전의 랜더링 했던 결과물이 남아있을 수도 있으므로,
         * ClearReanderTarget 메서드로 이를 지워준다.     */
        buffer.ClearRenderTarget(true, true, Color.clear);
        CameraClearFlags flags = camera.clearFlags;
        /* BeginSample은 사전에 제작된 유니티 프로파일러 샘플을 
         * 지정한 이름의 작업으로 CommandBuffer에 추가할 수 있다.    */
        buffer.BeginSample(SampleName);
        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth,
            flags != CameraClearFlags.Color,
            flags == CameraClearFlags.Color ?
                camera.backgroundColor.linear : Color.clear
        );
        /*랜더링 하는 과정을 프로파일링 할 것이므로,
         * 카메라를 프로퍼티를 전달하기 전과
         * 컨텍스트를 제출하기 직전에 각각
         * 프로파일링 시작/끝 명령을 복사한다.     */
        ExecuteBuffer();
    }
    //랜더링 컨텍스트에 카메라에 대한 랜더링 작업을 예약
    //동적배칭 사용 및 GPU 인스턴싱 사용에 대한 인자 추가
    void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing)
    {
        /* 렌더러를 호출하기 전에 DrawingSettings와 FilteringSettings 구조체에 담은
         * 랜더링 설정 값을 넘겨야한다.
         * 이 예제에선 그냥 기본 세팅값을 사용했다.
         */
        var sortingSettings = new SortingSettings(camera)
        {
            //CommonOpaque는 불투명 객체 먼저 그린다.
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(
            unlitShaderTagId, sortingSettings
            )
        {
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing,
            //PerObjectData는 SRP에서 GPU로 전달할 객체의 추가적인 데이터를 설정합니다.
            //중복 설정은 | 연산자를 사용합니다. ex) PerObjectData.Lightmaps | PerObjectData.LightProbe
            //Lightmaps는 베이킹된 라이트 맵에 대해 객체의 라이트 맵 uv 데이터등을 GPU에 전달합니다.
            //LightProbe는 각 객체가 사용하는 라이트 프로브에 대한 정보를 GPU에 전달합니다.
            //LightProbeProxyVolume(LPPV)은 랜더링되는 객체가 LightProbeProxyVolume 컴포넌트를 가지고 있으면, 그 정보를 GPU에 전달합니다.
            //LPPV는 동적 객체의 볼륨 데이터의 3D Float Texture를 제공합니다.
            //ShadowMask는 객체의 쉐도우 마스크 데이터를 GPU에 전달하도록 설정합니다.
            //OcclusionProbe는 동적객체의 라이트 프로브에 베이크된 그림자 정보를 GPU에 전달하도록 설정합니다.
            //OcclusionProbeProxyVolume은 각 오브젝트의 LPPV에  베이크된 그림자 정보를 GPU에 전달하도록 설정합니다.
            //ReflectionProbes는 지금 랜더링하는 객체가 속한 ReflectionProbe의 큐브맵이나 반사 기준위치 등을 전달하도록 설정합니다.
            perObjectData = PerObjectData.Lightmaps | PerObjectData.LightProbe | PerObjectData.LightProbeProxyVolume | PerObjectData.ShadowMask | PerObjectData.OcclusionProbe
                            | PerObjectData.OcclusionProbeProxyVolume | PerObjectData.ReflectionProbes
        };
        //LitShader를 랜더링
        drawingSettings.SetShaderPassName(1, litShaderTagId);
        //Opaque 객체만 랜더링
        /* 불투명 객체는 랜더링 될 때 Z-buffer에 값을 쓰지만, 불투명 객체는 그러지 않기 때문에,
         * 투명 객체를 그리고 DrawSkybox를 호출할 경우 투명객체가 빈 픽셀로 인식되어
         * 해당 픽셀위에 Skybox를 덧그리게 된다.     */
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);

        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );

        context.DrawSkybox(camera);

        //CommonTransparent는 투명 객체 먼저 그린다.
        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        //투명 객체만 랜더링
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;

        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
    }

    //랜더링 컨텍스트 큐에 삽입된 대기중인 작업을 실행
    void Submit()
    {
        buffer.EndSample(SampleName);
        ExecuteBuffer();
        /* 컨텍스트 제출. 우리가 컨텍스트에 예약한 작업들은 이 Submit메서드를 호출하기 전까지 스택에 쌓이며
         * 실행되지 않고 유예되다가, 제출후 순차적으로 실행된다.   */
        context.Submit();
    }
    void ExecuteBuffer()
    {
        //ExecuteCommandBuffer 메서드는 해당 랜더링 컨텍스트에 주어진 버퍼의 명령을 복사합니다.
        context.ExecuteCommandBuffer(buffer);
        /* 명령을 랜더링 컨텍스트에 복사했다고 해서 버퍼에서 삭제되지는 않으므로,
         * Clear 메서드를 통해 따로 삭제해 줍니다.    */
        buffer.Clear();
    }
    //컬링을 수행할 메서드
    bool Cull(float maxShadowDistance)
    {
        //컬링 파라미터를 카메라로 부터 가져와 "p" 변수에 저장합니다.
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            //컬링 수행시 shadowDistance를 설정합니다.
            //이때 카메라가 볼 수 있는 거리보다 먼 그림자는 랜더링이 의미 없으므로 카메라의 far clip거리로 제한합니다.
            p.shadowDistance = Mathf.Min(maxShadowDistance, camera.farClipPlane);
            //컨텍스트의 Cull메서드를 통해 컬링을 수행하며 CullingResults 구조체를 반환한다.
            //ref 키워드는 참조객체의 주소값 포인터를 넘기며, 구조체가 입력되어도 복사하지 않는다.
            cullingResults = context.Cull(ref p);
            return true;
        }
        return false;
    }
}
