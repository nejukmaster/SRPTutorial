#ifndef INPUT_CONFIG
#define INPUT_CONFIG

//MainTex�� UV��ǥ�� DetailMap�� UV��ǥ�� ��� �����ϴ� ����ü ����
struct InputConfig {
	float2 baseUV;
	float2 detailUV;
	//�� ��Ҹ� ���������� �������ϴ� ���
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