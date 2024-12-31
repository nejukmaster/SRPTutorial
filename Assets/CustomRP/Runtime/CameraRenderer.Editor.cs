using UnityEditor;
using UnityEngine;
using UnityEngine.Profiling;
using UnityEngine.Rendering;

//partial class�� Ŭ������ ���� ���Ϸ� ������ �����ϴµ� ���ǰ�, ���� �ڵ������� �ڵ�� ����� �ۼ��� �ڵ带 �и��Ҷ� ����մϴ�.
partial class CameraRenderer
{
    partial void DrawGizmos();
    partial void DrawUnsupportedShaders();
    partial void PrepareForSceneWindow();
    partial void PrepareBuffer();
    //����� �ڵ�� Editor��忡���� ����
#if UNITY_EDITOR
    //����Ƽ�� ���Ž� ���̴� ���̵�
    static ShaderTagId[] legacyShaderTagIds = {
        new ShaderTagId("Always"),
        new ShaderTagId("ForwardBase"),
        new ShaderTagId("PrepassBase"),
        new ShaderTagId("Vertex"),
        new ShaderTagId("VertexLMRGBM"),
        new ShaderTagId("VertexLM")
    };
    //����Ƽ ���� ��Ƽ����
    static Material errorMaterial;

    string SampleName { get; set; }

    //�����ͻ� ����� �׸��� �н�
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
        //SceneView ī�޶�(������ ����� ī�޶�)�� ���� ������Ʈ���� �����Ͽ� UI�� �׸���.
        if (camera.cameraType == CameraType.SceneView)
        {
            ScriptableRenderContext.EmitWorldGeometryForSceneView(camera);
        }
    }

    partial void PrepareBuffer()
    {
        Profiler.BeginSample("Editor Only");
        //2�� �̻��� ī�޶� ���� ���, �� ī�޶� ������ �н��� ������ �� �ֵ���, ī�޶� �̸����� CommandBuffer�� �̸��� �ٲ۴�.
        buffer.name = SampleName = camera.name;
        Profiler.EndSample();
    }

    // �������� �ʴ� ���̴��� �׸��� �н��� �߰��մϴ�.
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
            //�������� �ʴ� ���̴��� ���� ��Ƽ����� ǥ��
            overrideMaterial = errorMaterial
        };
        //DrawingSettings�� SetShaderPassName �޼��忡 �ε����� ���̴� �±׸� �Ѱ� ���� ���̴��� �׸� �� �ִ�.
        for (int i = 1; i < legacyShaderTagIds.Length; i++)
        {
            drawingSettings.SetShaderPassName(i, legacyShaderTagIds[i]);
        }
        //����Ʈ FilteringSettings�� ����Ѵ�.
        var filteringSettings = FilteringSettings.defaultValue;
        context.DrawRenderers(
            cullingResults, ref drawingSettings, ref filteringSettings
        );
    }
#else
    const String SampleName => bufferName;
#endif
}
