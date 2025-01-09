#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

//����Ƽ�� ���̴� �����Ϸ��� �ڵ带 ����ȭ �Ͽ� �ٽ� �����ϱ� ������ ����ü�� ���ٰ� �ؼ� �޸𸮴����� �Ͼ�� �ʴ´�.
struct Surface {
	//ǥ�� �ȼ��� ���� ������
	float3 position;
	float3 normal;
	float3 viewDirection;
	float depth;
	float3 color;
	float alpha; 
	float metallic;
	float smoothness;
};

#endif