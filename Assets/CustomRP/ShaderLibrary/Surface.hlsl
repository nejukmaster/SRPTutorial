#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

//유니티의 셰이더 컴파일러는 코드를 최적화 하여 다시 생성하기 때문에 구조체를 쓴다고 해서 메모리누수가 일어나진 않는다.
struct Surface {
	//표면 픽셀의 월드 포지션
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