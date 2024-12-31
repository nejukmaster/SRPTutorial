using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

//partial class는 클래스를 여러 파일로 나누어 저장하는데 사용되고, 보통 자동생성된 코드와 수기로 작성한 코드를 분리할때 사용합니다.
partial class CameraRenderer
{
    partial void DrawGizmos();
    partial void DrawUnsupportedShaders();
    partial void PrepareForSceneWindow();
    partial void PrepareBuffer();
    //디버깅 코드는 Editor모드에서만 선언
#if UNITY_EDITOR
    //유니티의 레거시 쉐이더 아이디
    static ShaderTagId[] legacyShaderTagIds = {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };
    //유니티 에러 머티리얼
    static Material errorMaterial;

    string SampleName { get; set; }

    //에디터상 기즈모를 그리는 패스
    partial void DrawGizmos()
    {
        if (Handles.ShouldRenderGizmos())
        {
            context.DrawGizmos(camera, GizmoSubset.PreImageEffects);
            context.DrawGizmos(camera, GizmoSubset.PostImageEffects);
        }
    }

    partial void PrepareForSceneWindow()
    {
        //SceneView 카메라(에디터 모드의 카메라)에 월드 지오메트리를 적용하여 UI를 그린다.
        if (camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
        }
    }

    partial void PrepareBuffer()
    {
        Profiler.BeginSample("Editor Only");
        //2개 이상의 카메라가 있을 경우, 각 카메라 랜더링 패스를 구분할 수 있도록, 카메라 이름으로 CommandBuffer의 이름을 바꾼다.
        buffer.name = SampleName = camera.name;
        Profiler.EndSample();
    }

    // 지원하지 않는 쉐이더를 그리는 패스를 추가합니다.
    partial void DrawUnsupportedShaders()
    {
        if (errorMaterial == null)
        {
            errorMaterial =
                new Material(Shader.Find("Hidden/InternalErrorShader"));
        }
        var drawingSettings = new DrawingSettings(
            legacyShaderTagIds[0], new SortingSettings(camera)
        )
        {
            //지원되지 않는 쉐이더는 에러 머티리얼로 표시
            overrideMaterial = errorMaterial
        };
        //DrawingSettings의 SetShaderPassName 메서드에 인덱스와 쉐이더 태그를 넘겨 여러 쉐이더를 그릴 수 있다.
        for (int i = 1; i < legacyShaderTagIds.Length; i++)
        {
            drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
        }
        //디폴트 FilteringSettings를 사용한다.
        var filteringSettings = FilteringSettings.defaultValue;
        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
    }
#else
    const String SampleName => bufferName;
#endif
}
