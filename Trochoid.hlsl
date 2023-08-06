#ifndef TROCHOID_HLSL
#define TROCHOID_HLSL

#define PIE 3.1415926
#define G 9.8
float phasor(float2 xz, float4 params) {
    float k = 2 * PIE / params.w;
    float a = params.y / k;
    float speed = sqrt(G / k);
    return a * sin(k * (dot(params.xz, xz) + speed * _Time.y));
}

float phasorCos(float2 xz, float4 params) {
    float k = 2 * PIE / params.w;
    float a = params.y / k;
    float speed = sqrt(G / k);
    return a * cos(k * (dot(params.xz, xz) + speed * _Time.y));
}

float3 _trochoidOffset(float3 origin, float4 params) {
    float3 ret_offset;
    ret_offset.y = phasor(origin.xz, params);
    float offset = phasorCos(origin.xz, params);
    ret_offset.x = (params.x * (offset));
    ret_offset.z = (params.z * (offset));
    return ret_offset;
}

float3 TrochoidOffset(float3 origin, float4 params1, float4 params2, float4 params3) {
    float3 offset1 = _trochoidOffset(origin, params1);
    float3 offset2 = _trochoidOffset(origin, params2);
    float3 offset3 = _trochoidOffset(origin, params3);
    
    float3 offset_sum = offset1 + offset2 + offset3;
    return offset_sum;
}
#endif