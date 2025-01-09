using UnityEngine;
using UnityEngine.Rendering;

//LightingŬ�������� �׸��� �������� ������ ShadowsŬ������ �����մϴ�.
//ShadowsŬ������ �׸��� �������� ������ ���۸� �����ϴ�.
public class Shadows
{
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
    }

    //�׸��� �������� ��ü�� �ؽ��Ŀ� �׸��� ������ ShadowMap�� �����Ͽ� �̷�����ϴ�.
    //�̶�, ShadowMap�� �׸� ShaderProperty�� �������ݴϴ�.
    static int
            dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
            dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),
            //ĳ�����̵� �ܰ� ���� Culling Sphere ������ ��� ShaderProperty�� ����
            cascadeCountId = Shader.PropertyToID("_CascadeCount"),
            cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
            shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    //Culling Sphere�� �� ĳ�����̵� �ܰ谡 �׸��ڸ� �����ϴ� ������ �����ϴ� �� �����Դϴ�.
    //�̴� ���� ��ġ x,y,z�� ���� ������ w�� �����Ǵ� Vector4�� ���ǵ˴ϴ�.
    static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];

    //�� ���� �׸��� ��ȯ ����� ����
    //�׸��� ��ȯ ����� �־��� ���踦 ��ǥ�׸��� �ؽ��� ��ǥ�� ��ȯ�� �ݴϴ�.
    static Matrix4x4[]
        dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];


    ShadowedDirectionalLight[] ShadowedDirectionalLights = new ShadowedDirectionalLight[maxShadowedDirectionalLightCount];

    const string bufferName = "Shadows";
    const int maxShadowedDirectionalLightCount = 4, maxCascades = 4;

    CommandBuffer buffer = new CommandBuffer
    {
        name = bufferName
    };

    ScriptableRenderContext context;

    CullingResults cullingResults;

    ShadowSettings settings;

    int ShadowedDirectionalLightCount;

    public void Setup(
        ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings
    )
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
        ShadowedDirectionalLightCount = 0;
    }

    //���� �׸��� �������� �����ϴ� �޼ҵ�
    //ShadowAtlas�� ���� ���� Shadow Map�� ������ ��� �ش� �׸����� ������ �׸��� Ÿ�� �������� ���� ��ȯ, �׷��� ���� ��� �����͸� ��ȯ
    public Vector2 ReserveDirectionalShadows(Light light, int visibleLightIndex) 
    {
        //���� �׸��ڸ� ������ ������ ���� �ִ� �׸��� ������ ������ ������ ������ ������ üũ
        //������ �׸��ڸ� �������ϴ���, �׸��� ������ 0���� ū�� üũ
        //�ش� ������ �׸��ڰ� �ø� �Ǿ��ִ��� üũ(�Ÿ� � ���� �׸��ڸ� �帮���� ���� �� ����)
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount && light.shadows != LightShadows.None && light.shadowStrength > 0f && cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            //�׸��ڸ� �������ϴ� ������ �����ϰ� ���� ��, ������ ������ ���� ����
            ShadowedDirectionalLights[ShadowedDirectionalLightCount] =
                new ShadowedDirectionalLight
                {
                    visibleLightIndex = visibleLightIndex
                };
           return new Vector2(
                    light.shadowStrength, settings.directional.cascadeCount * ShadowedDirectionalLightCount++
           );
        }
        return Vector2.zero;
    }

    //�׸��� ������
    public void Render()
    {
        if (ShadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();
        }
        //�׸��ڸ� �������ϴ� ������ ������쿡�� 1x1 ũ���� Shadowmap�� �������Ͽ� ������ �ӽ� �ؽ��ĸ� ���̷� ����� �ݴϴ�.
        else
        {
            buffer.GetTemporaryRT(
                dirShadowAtlasId, 1, 1,
                32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap
            );
        }
    }

    public void Cleanup()
    {
        //�ӽ� �����ؽ��Ĵ� �� ������ ������ �������־�� �մϴ�.
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows() 
    {
        //������ �� ����� �����ϰ� �ӽ� ���� �ؽ��ĸ� �����մϴ�.
        int atlasSize = (int)settings.directional.atlasSize;
        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        buffer.BeginSample(bufferName);
        //GPU�� �� ������Ʈ�� �ӽ� ���� �ؽ��Ŀ� �׸����� ����
        buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.ClearRenderTarget(true, false, Color.clear);
        ExecuteBuffer();

        int tiles = ShadowedDirectionalLightCount * settings.directional.cascadeCount;
        //�� ������ Shadow Map�� ��ġ�� �ʰ� �����Ͽ� �׸���
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;

        //�� ������ ������ ���� ���� Directional Shadow ������
        for (int i = 0; i < ShadowedDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }

        //ĳ�����̵� ���� ĳ�����̵� Culling Sphere �����͸� shader property�� �Ѱ��ݴϴ�.
        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount);
        buffer.SetGlobalVectorArray(
            cascadeCullingSpheresId, cascadeCullingSpheres
        );
        //�׸��� ��ȯ ����� global shader property�� �Ѱ��ݴϴ�.
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        //�׸��� �ִ�Ÿ��� ������Ƽ�� �Ѱ��ݴϴ�.
        //�̶� Fading ȿ���� ����� ��, ������ ������ �ϱ� ���� ������ �Ѱ��ݴϴ�.
        //Depth���� ���� ���� Fading: Strength = (1-depth/shadowMaxDistance)/fadingFactor
        //Casecade Sphere ������ ���� ���� Fading: Strength = (1-distance^2/sphereRadius^2)/fadingFactor
        float f = 1f - settings.directional.cascadeFade;
        buffer.SetGlobalVector(
            shadowDistanceFadeId,
            new Vector4(1f / settings.maxDistance, 1f / settings.distanceFade, 1f/(1f-f*f))
        );
        buffer.EndSample(bufferName);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows(int index, int split, int tileSize) 
    {
        ShadowedDirectionalLight light = ShadowedDirectionalLights[index];
        var shadowSettings = new ShadowDrawingSettings(cullingResults, light.visibleLightIndex, BatchCullingProjectionType.Orthographic);

        int cascadeCount = settings.directional.cascadeCount;
        int tileOffset = index * cascadeCount;
        Vector3 ratios = settings.directional.CascadeRatios;

        //�� �Ÿ��� �׸��� ���� �׸���.
        for (int i = 0; i < cascadeCount; i++)
        {
            //������ ���� ���̵��� ������ ���忡�� ���� ���� ������ �������ϴ°��Դϴ�.
            //Directional Light�� ���� ��ġ�� ���� ���⸸ �����ϹǷ� ī�޶��� ���忡�� Directional Light�� ��ġ�ϴ� ������ �� �� ��������� ���Ͽ� �������� �����մϴ�.
            //�ش� ������ CullingResults Ŭ������ ComputeDirectionalShadowMatricesAndCullingPrimitives �޼��带 ���� ���� �� �ֽ��ϴ�.
            // 1. ������ �ϰ����ϴ� ������ visibleLightIndex
            // 2,3,4. �׸����� Cascade�� ����
            // 5. �ؽ��� ũ��
            // 6. ��� ��ó �׸���
            // 7. ����� ���� �� ��°�
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize, 0f,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            //ShadowSplitData�� Settings�� ����
            //ShadowSplitData���� �׸��ڸ� �帮��� ��ü�� �ø��ϴ� ����� ���� ������ ����Ǿ��ֽ��ϴ�.
            shadowSettings.splitData = splitData;
            //���� ShadowSplitData���� ĳ�����̵忡 ���� ���� Culling Sphere�� �����͵� ���� ����Ǿ� �����Ƿ�, �̸� �������ݴϴ�.
            if (index == 0)
            {
                //ShadowSplitData������ Culling Sphere �����ʹ� w������ ���� �������� �����ϰ��ִµ�, �� fragment�� Culling Sphere �ȿ� �ִ����� ���� ����� Culling Sphere�� ������ ������ ���� ���ǹǷ�,
                //���̴� ���� ������ ���̰��� CPU���� �̸� ������ ������ ����Ͽ� GPU�� �Ѱ��ش�.
                Vector4 cullingSphere = splitData.cullingSphere;
                cullingSphere.w *= cullingSphere.w;
                cascadeCullingSpheres[i] = cullingSphere;
            }

            int tileIndex = tileOffset + i;

            //�׸��� ��ȯ ����� �����Ͽ� �� ������ �ε����� �°� �����մϴ�.
            //�׸��� ��ȯ ����� �� ������ ������İ� �� ����� ���� VP^-1 ��ķ� ���ǵ˴ϴ�.
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(
                projectionMatrix * viewMatrix,
                SetTileViewport(tileIndex, split, tileSize), split
            ); ;
            //���� ������ �� �� ��������� ����
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);

            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);
        }
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {
        //�� Z���۸� ����ϴ� ��� Z��(����)�� ��ȯ�� ���� ���մϴ�.'
        //VP���ۿ��� 1���� X�࿡ ���� ��ȯ, 2���� Y�࿡ ���� ��ȯ, 3���� Z��(����)�� ���� ��ȯ, 4���� Ŭ������ ��ǥ ����ȭ�� ���� ��ȯ�̴�.
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        float scale = 1f / split;
        //0.5�� ���ϴ� ���� -1 ~ 1������ ������ ������ Ŭ�������� 0 ~ 1�� ����ȭ �ϵ��� �ٲٴ� �۾�
        //���� X,Y�� ���õ� ��ȯ�� offset�� tiling�� ����
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        return m;
    }

    Vector2 SetTileViewport(int index, int split, float tileSize)
    {
        Vector2 offset = new Vector2(index % split, index / split);
        buffer.SetViewport(new Rect(
            offset.x * tileSize, offset.y * tileSize, tileSize, tileSize
        ));
        return offset;
    }

    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
