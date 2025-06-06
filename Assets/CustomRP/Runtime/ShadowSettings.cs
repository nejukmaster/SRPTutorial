using UnityEngine;

//그림자 랜더링 거리, 쉐도우 맵 해상도등을 설정할 세팅 클래스를 생성
[System.Serializable]
public class ShadowSettings
{
    public enum MapSize
    {
        _256 = 256, _512 = 512, _1024 = 1024,
        _2048 = 2048, _4096 = 4096, _8192 = 8192
    }

    //그림자 픽셀을 보간해주기위한 PCF(Percentage Closer Filtering) 모드
    public enum FilterMode
    {
        PCF2x2, PCF3x3, PCF5x5, PCF7x7
    }


    [System.Serializable]
    public struct Directional
    {

        public MapSize atlasSize;

        public FilterMode filter;

        [Range(1, 4)]
        public int cascadeCount;

        [Range(0f, 1f)]
        public float cascadeRatio1, cascadeRatio2, cascadeRatio3;

        public Vector3 CascadeRatios => new Vector3(cascadeRatio1, cascadeRatio2, cascadeRatio3);

        //캐스케이드 fading factor
        [Range(0.001f, 1f)]
        public float cascadeFade;

        public enum CascadeBlendMode
        {
            Hard, Soft, Dither
        }

        public CascadeBlendMode cascadeBlend;
    }

    [Min(0f)]
    public float maxDistance = 100f;

    [Range(0.001f, 1f)]
    public float distanceFade = 0.1f;

    public Directional directional = new Directional
    {
        atlasSize = MapSize._1024,
        filter = FilterMode.PCF2x2,
        cascadeCount = 4,
        cascadeRatio1 = 0.1f,
        cascadeRatio2 = 0.25f,
        cascadeRatio3 = 0.5f,
        cascadeFade = 0.1f,
        cascadeBlend = Directional.CascadeBlendMode.Hard
    };
}
