using UnityEngine;
using UnityEngine.Rendering;

//Lighting클래스에서 그림자 랜더링만 전담할 Shadows클래스를 생성합니다.
//Shadows클래스는 그림자 랜더링만 전담할 버퍼를 가집니다.
public class Shadows
{
    struct ShadowedDirectionalLight
    {
        public int visibleLightIndex;
    }

    //그림자 랜더링은 객체를 텍스쳐에 그리는 것으로 ShadowMap을 제작하여 이루어집니다.
    //이때, ShadowMap을 그릴 ShaderProperty를 정의해줍니다.
    static int
            dirShadowAtlasId = Shader.PropertyToID("_DirectionalShadowAtlas"),
            dirShadowMatricesId = Shader.PropertyToID("_DirectionalShadowMatrices"),
            //캐스케이드 단계 수와 Culling Sphere 정보를 담는 ShaderProperty를 정의
            cascadeCountId = Shader.PropertyToID("_CascadeCount"),
            cascadeCullingSpheresId = Shader.PropertyToID("_CascadeCullingSpheres"),
            shadowDistanceFadeId = Shader.PropertyToID("_ShadowDistanceFade");

    //Culling Sphere는 각 캐스케이드 단계가 그림자를 생성하는 영역을 정의하는 구 영역입니다.
    //이는 구의 위치 x,y,z와 구의 반지를 w로 구성되는 Vector4로 정의됩니다.
    static Vector4[] cascadeCullingSpheres = new Vector4[maxCascades];

    //각 조명별 그림자 변환 행렬을 저장
    //그림자 변환 행렬은 주어진 세계를 좌표그림자 텍스쳐 좌표로 변환해 줍니다.
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

    //조명에 그림자 랜더링을 예약하는 메소드
    //ShadowAtlas에 조명에 의한 Shadow Map이 생성된 경우 해당 그림자의 강도와 그림자 타일 오프셋을 같이 반환, 그렇지 않을 경우 영벡터를 반환
    public Vector2 ReserveDirectionalShadows(Light light, int visibleLightIndex) 
    {
        //현재 그림자를 예약한 조명의 수가 최대 그림자 랜더링 가능한 조명의 수보다 적은지 체크
        //조명이 그림자를 랜더링하는지, 그림자 강도가 0보다 큰지 체크
        //해당 조명의 그림자가 컬링 되어있는지 체크(거리 등에 의해 그림자를 드리우지 않을 수 있음)
        if (ShadowedDirectionalLightCount < maxShadowedDirectionalLightCount && light.shadows != LightShadows.None && light.shadowStrength > 0f && cullingResults.GetShadowCasterBounds(visibleLightIndex, out Bounds b))
        {
            //그림자를 랜더링하는 조명을 생성하고 저장 후, 예약한 조명의 수를 증가
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

    //그림자 랜더링
    public void Render()
    {
        if (ShadowedDirectionalLightCount > 0)
        {
            RenderDirectionalShadows();
        }
        //그림자를 랜더링하는 조명이 없을경우에도 1x1 크기의 Shadowmap을 랜더링하여 해제할 임시 텍스쳐를 더미로 만들어 줍니다.
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
        //임시 랜더텍스쳐는 각 프레임 단위로 해제해주어야 합니다.
        buffer.ReleaseTemporaryRT(dirShadowAtlasId);
        ExecuteBuffer();
    }

    void RenderDirectionalShadows() 
    {
        //쉐도우 맵 사이즈를 설정하고 임시 랜더 텍스쳐를 생성합니다.
        int atlasSize = (int)settings.directional.atlasSize;
        buffer.GetTemporaryRT(dirShadowAtlasId, atlasSize, atlasSize, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        buffer.BeginSample(bufferName);
        //GPU에 각 오브젝트를 임시 랜더 텍스쳐에 그리도록 지시
        buffer.SetRenderTarget(dirShadowAtlasId, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.ClearRenderTarget(true, false, Color.clear);
        ExecuteBuffer();

        int tiles = ShadowedDirectionalLightCount * settings.directional.cascadeCount;
        //각 조명의 Shadow Map을 겹치지 않게 분할하여 그리기
        int split = tiles <= 1 ? 1 : tiles <= 4 ? 2 : 4;
        int tileSize = atlasSize / split;

        //각 쉐도우 랜더링 조명에 대한 Directional Shadow 랜더링
        for (int i = 0; i < ShadowedDirectionalLightCount; i++)
        {
            RenderDirectionalShadows(i, split, tileSize);
        }

        //캐스케이드 수와 캐스케이드 Culling Sphere 데이터를 shader property로 넘겨줍니다.
        buffer.SetGlobalInt(cascadeCountId, settings.directional.cascadeCount);
        buffer.SetGlobalVectorArray(
            cascadeCullingSpheresId, cascadeCullingSpheres
        );
        //그림자 변환 행렬을 global shader property로 넘겨줍니다.
        buffer.SetGlobalMatrixArray(dirShadowMatricesId, dirShadowMatrices);
        //그림자 최대거리를 프로퍼티로 넘겨줍니다.
        //이때 Fading 효과를 계산할 때, 연산을 간단히 하기 위해 역수로 넘겨줍니다.
        //Depth값에 따른 선형 Fading: Strength = (1-depth/shadowMaxDistance)/fadingFactor
        //Casecade Sphere 영역에 따른 구형 Fading: Strength = (1-distance^2/sphereRadius^2)/fadingFactor
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

        //각 거리별 그림자 맵을 그린다.
        for (int i = 0; i < cascadeCount; i++)
        {
            //쉐도우 맵의 아이디어는 조명의 입장에서 씬의 깊이 정보만 랜더링하는것입니다.
            //Directional Light는 실제 위치가 없는 방향만 존재하므로 카메라의 입장에서 Directional Light와 일치하는 방향의 뷰 및 투영행렬을 구하여 랜더링을 수행합니다.
            //해당 과정은 CullingResults 클래스의 ComputeDirectionalShadowMatricesAndCullingPrimitives 메서드를 통해 구할 수 있습니다.
            // 1. 랜더링 하고자하는 조명의 visibleLightIndex
            // 2,3,4. 그림자의 Cascade를 제어
            // 5. 텍스쳐 크기
            // 6. 평면 근처 그림자
            // 7. 결과에 따른 각 출력값
            cullingResults.ComputeDirectionalShadowMatricesAndCullingPrimitives(
                light.visibleLightIndex, i, cascadeCount, ratios, tileSize, 0f,
                out Matrix4x4 viewMatrix, out Matrix4x4 projectionMatrix,
                out ShadowSplitData splitData
            );
            //ShadowSplitData를 Settings에 복사
            //ShadowSplitData에는 그림자를 드리우는 객체를 컬링하는 방법에 대한 정보가 저장되어있습니다.
            shadowSettings.splitData = splitData;
            //또한 ShadowSplitData에는 캐스케이드에 따른 계산된 Culling Sphere의 데이터도 같이 저장되어 있으므로, 이를 매핑해줍니다.
            if (index == 0)
            {
                //ShadowSplitData에서의 Culling Sphere 데이터는 w값으로 구의 반지름을 저장하고있는데, 각 fragment가 Culling Sphere 안에 있는지에 대한 계산은 Culling Sphere의 반지름 제곱을 통해 계산되므로,
                //쉐이더 단의 연산을 줄이고자 CPU에서 미리 반지름 제곱을 계산하여 GPU로 넘겨준다.
                Vector4 cullingSphere = splitData.cullingSphere;
                cullingSphere.w *= cullingSphere.w;
                cascadeCullingSpheres[i] = cullingSphere;
            }

            int tileIndex = tileOffset + i;

            //그림자 변환 행렬을 생성하여 각 조명의 인덱스에 맞게 저장합니다.
            //그림자 변환 행렬은 각 조명의 투영행렬과 뷰 행렬을 곱한 VP^-1 행렬로 정의됩니다.
            dirShadowMatrices[tileIndex] = ConvertToAtlasMatrix(
                projectionMatrix * viewMatrix,
                SetTileViewport(tileIndex, split, tileSize), split
            ); ;
            //현재 버퍼의 뷰 및 투영행렬을 설정
            buffer.SetViewProjectionMatrices(viewMatrix, projectionMatrix);

            ExecuteBuffer();
            context.DrawShadows(ref shadowSettings);
        }
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, int split)
    {
        //역 Z버퍼를 사용하는 경우 Z축(깊이)에 변환의 역을 취합니다.'
        //VP버퍼에서 1열은 X축에 대한 변환, 2열은 Y축에 대한 변환, 3열은 Z축(깊이)에 관한 변환, 4열은 클립공간 좌표 정규화를 위한 변환이다.
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        float scale = 1f / split;
        //0.5를 곱하는 것은 -1 ~ 1사이의 범위를 가지는 클립공간을 0 ~ 1로 정규화 하도록 바꾸는 작업
        //또한 X,Y에 관련된 변환에 offset과 tiling을 적용
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
