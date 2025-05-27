using UnityEngine;
using UnityEngine.Rendering;

//LightingŬ�������� �׸��� �������� ������ ShadowsŬ������ �����մϴ�.
//ShadowsŬ������ �׸��� �������� ������ ���۸� �����ϴ�.
public class Shadows
{
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
        //��� ������ ���̾
        public float slopeScaleBias;
        //ShadowAtlas �������� NearPlane ������
        public float nearPlaneOffset;
    }

    //�׸��� �������� ��ü�� �ؽ��Ŀ� �׸��� ������ ShadowMap�� �����Ͽ� �̷�����ϴ�.
    //�̶�, ShadowMap�� �׸� ShaderProperty�� �������ݴϴ�.
    static int
            dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
            dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),
            //ĳ�����̵� �ܰ� ���� Culling Sphere ������ ��� ShaderProperty�� ����
            cascadeCountId = Shader.PropertyToID("_CascadeCount"),
            cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
            cascadeDataId = Shader.PropertyToID("_CascadeData"),
            shadowAtlasSizeId = Shader.PropertyToID("_ShadowAtlasSize"),
            shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    //Culling Sphere�� �� ĳ�����̵� �ܰ谡 �׸��ڸ� �����ϴ� ������ �����ϴ� �� �����Դϴ�.
    //�̴� ���� ��ġ x,y,z�� ���� ������ w�� �����Ǵ� Vector4�� ���ǵ˴ϴ�.
    static Vector4[] 
        cascadeCullingSpheres = new Vector4[maxCascades],
        cascadeData = new Vector4[maxCascades];

    //�� ���� �׸��� ��ȯ ����� ����
    //�׸��� ��ȯ ����� �־��� ���踦 ��ǥ�׸��� �ؽ��� ��ǥ�� ��ȯ�� �ݴϴ�.
    static Matrix4x4[] dirShadowMatrices = new Matrix4x4[maxShadowedDirectionalLightCount * maxCascades];

    static string[] directionalFilterKeywords = {
        "_DIRECTIONAL_PCF3",
        "_DIRECTIONAL_PCF5",
        "_DIRECTIONAL_PCF7",
    };

    //Soft, Dither ĳ�����̵� ������ ���� Ű���� ����
    static string[] cascadeBlendKeywords = {
        "_CASCADE_BLEND_SOFT",
        "_CASCADE_BLEND_DITHER"
    };

    //���̴��� ������ ����ũ�� ���� ������ �Ѱ��� Ű���� ����
    static string[] shadowMaskKeywords = {
        //shadowmask ���
        "_SHADOW_MASK_ALWAYS",
        //distance shadowmask ���
        "_SHADOW_MASK_DISTANCE"
    };


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

    //������ ����ũ ��� ����
    bool useShadowMask;

    public void Setup(
        ScriptableRenderContext context, CullingResults cullingResults,
        ShadowSettings settings
    )
    {
        this.context = context;
        this.cullingResults = cullingResults;
        this.settings = settings;
        ShadowedDirectionalLightCount = 0;
        this.useShadowMask = false;
    }

    //���� �׸��� �������� �����ϴ� �޼ҵ�
    //ShadowAtlas�� ���� ���� Shadow Map�� ������ ��� �ش� �׸����� ������ �׸��� Ÿ�� �������� ���� ��ȯ, �׷��� ���� ��� �����͸� ��ȯ
    public Vector4 ReserveDirectionalShadows(Light light, int visibleLightIndex) 
    {
        //���� �׸��ڸ� ������ ������ ���� �ִ� �׸��� ������ ������ ������ ������ ������ üũ
        //������ �׸��ڸ� �������ϴ���, �׸��� ������ 0���� ū�� üũ
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount && light.shadows != LightShadows.None && light.shadowStrength > 0f)
        {
            //�� ������ ����ϴ� ������ ����ũ ä���� ��Ÿ��
            //������ ����ũ �ؽ��Ĵ� rgba �� �װ��� ä���� ����ϹǷ� �� �װ��� Mixed ������ ���� �׸��ڸ� ������ �� �ֽ��ϴ�.
            //������ ������ ����ũ�� ������� ������� 
            float maskChannel = -1;
            //������ ����ũ�� ����ϴ� ������ �ִ��� üũ�Ͽ� useShadowMask ������Ƽ�� ����
            //LightBakingOutput�� �� ������ ����ŷ�� �����ÿ� ���� ������ ����ִ� ����ü�Դϴ�.
            LightBakingOutput lightBaking = light.bakingOutput;
            if (
                //Mixed ������ MixedLightingMode�� Shadowmask�� �����Ǿ��ִٸ�, �ش� ������ ������ ����ũ�� ����Ͽ� ����ŷ�� �����Դϴ�.
                lightBaking.lightmapBakeType == LightmapBakeType.Mixed &&
                lightBaking.mixedLightingMode == MixedLightingMode.Shadowmask
            )
            {
                useShadowMask = true;
                maskChannel = lightBaking.occlusionMaskChannel;
            }
            //�ش� ������ �׸��ڰ� �ø� �Ǿ��ִ��� üũ(�Ÿ� � ���� �׸��ڸ� �帮���� ���� �� ����)
            if (!cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
            {
                //������ �ø��Ǿ� �־ ������ �׸��� ���Ⱑ 0���� ũ�� ����Ƽ�� �׸��� ���� ���ø��ϹǷ� �̸� ����.
                //������ �׸��ڸ� ���ø��Ҷ��� �̸� ���밪���� �޾� �ش� ������ �ø��Ǿ� �־ ������ �׸��ڴ� �׸����� ����
                //�ش� ������ �׸����� ������ ��Ÿ���� ���Ϳ� �ش� ������ ����ϴ� ������ ����ũ ä���� �ε����� �߰��Ͽ� ��ȯ�մϴ�.
                return new Vector4(-light.shadowStrength, 0f, 0f, maskChannel);
            }
            //�׸��ڸ� �������ϴ� ������ �����ϰ� ���� ��, ������ ������ ���� ����
            ShadowedDirectionalLights[ShadowedDirectionalLightCount] =
                new ShadowedDirectionalLight
                {
                    visibleLightIndex = visibleLightIndex,
                    slopeScaleBias = light.shadowBias,
                    nearPlaneOffset = light.shadowNearPlane
                };
           return new Vector4(
                    light.shadowStrength,
                    settings.directional.cascadeCount * ShadowedDirectionalLightCount++,
                    light.shadowNormalBias,
                    maskChannel
           );
        }
        //�׸��ڸ� �������� �ʴ� ������ ��� ������ ����ũ�� �ε����� -1�� �����մϴ�.
        return new Vector4(0f, 0f, 0f, -1f);
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
        buffer.BeginSample(bufferName);
        SetKeywords(shadowMaskKeywords, useShadowMask ? QualitySettings.shadowmaskMode == ShadowmaskMode.Shadowmask ? 0 : 1 : -1);
        buffer.EndSample(bufferName);
        ExecuteBuffer();
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
        buffer.SetGlobalVectorArray(cascadeDataId, cascadeData);
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
        //Directional Lilght �������� ���� �� Ű���� Ȱ��ȭ
        SetKeywords(
            directionalFilterKeywords, (int)settings.directional.filter - 1
        );
        SetKeywords(
            cascadeBlendKeywords, (int)settings.directional.cascadeBlend - 1
        );
        buffer.SetGlobalVector(
                                //x������ҿ� ��Ʋ���� ũ�⸦, y������ҿ� ��Ʋ���� �ؼ� ����� �����մϴ�.
            shadowAtlasSizeId, new Vector4(atlasSize, 1f / atlasSize)
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

        float cullingFactor = Mathf.Max(0f, 0.8f - settings.directional.cascadeFade);

        //�� �Ÿ��� �׸��� ���� �׸���.
        for (int i = 0; i < cascadeCount; i++)
        {
            //������ ���� ���̵��� ������ �������� ���� ���� ������ �������ϴ°��Դϴ�.
            //Directional Light�� ���� ��ġ�� ���� ���⸸ �����ϹǷ� ī�޶��� ���忡�� Directional Light�� ��ġ�ϴ� ������ �� �� ��������� ���Ͽ� �������� �����մϴ�.
            //�ش� ������ CullingResults Ŭ������ ComputeDirectionalShadowMatricesAndCullingPrimitives �޼��带 ���� ���� �� �ֽ��ϴ�.
            // 1. ������ �ϰ����ϴ� ������ visibleLightIndex
            // 2,3,4. �׸����� Cascade�� ����
            // 5. �ؽ��� ũ��
            // 6. ��� ��ó �׸���
            // 7. ����� ���� �� ��°�
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize,
                light.nearPlaneOffset, out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            splitData.shadowCascadeBlendCullingFactor = cullingFactor;
            //ShadowSplitData�� Settings�� ����
            //ShadowSplitData���� �׸��ڸ� �帮��� ��ü�� �ø��ϴ� ����� ���� ������ ����Ǿ��ֽ��ϴ�.
            shadowSettings.splitData = splitData;
            //���� ShadowSplitData���� ĳ�����̵忡 ���� ���� Culling Sphere�� �����͵� ���� ����Ǿ� �����Ƿ�, �̸� �������ݴϴ�.
            if (index == 0)
            {
                SetCascadeData(i, splitData.cullingSphere, tileSize);
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

            buffer.SetGlobalDepthBias(0f, light.slopeScaleBias);
            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);
            buffer.SetGlobalDepthBias(0f, 0f);
        }
    }

    //ShaderKeyword�� �⺻������ On/Off
    //�������� Ű�����߿� �� Ű������ �ε����� �޾� On, �������� Off�� �����ϴ� �޼���
    void SetKeywords(string[] keywords, int enabledIndex)
    {
        for (int i = 0; i < keywords.Length; i++)
        {
            if (i == enabledIndex)
            {
                buffer.EnableShaderKeyword(keywords[i]);
            }
            else
            {
                buffer.DisableShaderKeyword(keywords[i]);
            }
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

    void SetCascadeData(int index, Vector4 cullingSphere, float tileSize)
    {
        float texelSize = 2f * cullingSphere.w / tileSize;
        //������ �ؼ�������� ĳ�����̵��� �ؼ������ ���� ũ�⸦ ���Ͽ� �����Ѵ�.
        //�̰� �����ָ� ���̾�� ���Ͱ� ���� �ʾ� Shadow Acne�� �ٽ� ��Ÿ���Եȴ�.
        float filterSize = texelSize * ((float)settings.directional.filter + 1f);
        //ShadowSplitData������ Culling Sphere �����ʹ� w������ ���� �������� �����ϰ��ִµ�, �� fragment�� Culling Sphere �ȿ� �ִ����� ���� ����� Culling Sphere�� ������ ������ ���� ���ǹǷ�,
        //���̴� ���� ������ ���̰��� CPU���� �̸� ������ ������ ����Ͽ� GPU�� �Ѱ��ش�.
        cullingSphere.w *= cullingSphere.w;
        cascadeCullingSpheres[index] = cullingSphere;
        cascadeData[index] = new Vector4(
            1f / cullingSphere.w,
            //���� ũ�⿡ ���� ������ �ؼ��� �밢�� ���̷� ���̾�� ����
            filterSize * 1.4142136f//root(2)
        );
    }

    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
