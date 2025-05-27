#ifndef INPUT_CONFIG
#define INPUT_CONFIG

//MainTex의 UV좌표와 DetailMap의 UV좌표를 묶어서 전달하는 구조체 선언
struct InputConfig {
	float2 baseUV;
	float2 detailUV;
	//각 요소를 선택적으로 랜더링하는 토글
	bool useMask;
	bool useDetail;
};

InputConfig GetInputConfig(float2 baseUV, float2 detailUV = 0.0) {
	InputConfig c;
	c.baseUV = baseUV;
	c.detailUV = detailUV;
	c.useMask = false;
	c.useDetail = false;
	return c;
}

#endif