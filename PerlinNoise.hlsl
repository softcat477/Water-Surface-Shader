#ifndef PERLIN_NOISE_HLSL
#define PERLIN_NOISE_HLSL

float2 noise2d2d(float2 uv) {
    float2 ret = float2(frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453),
        frac(cos(dot(uv, float2(12.9898, 78.233))) * 43758.5453));

    ret = ret * 2 - 1.0; // from 0~1 to -1~1
    ret = normalize(ret);
    return ret;
}

float3 noise3d3d(float3 xyz) {
    float3 ret = float3(
        frac(sin(dot(xyz, float3(12.9898, 78.233, 45.543))) * 43758.5453),
        frac(sin(dot(xyz, float3(54.123, 43.543, 32.989))) * 43758.5453),
        frac(sin(dot(xyz, float3(93.989, 43.242, 65.654))) * 43758.5453)
    );

    ret = ret * 2 - 1.0; // from 0~1 to -1~1
    ret = normalize(ret);

    return ret;
}

float gradientDot2d(float2 gradient_xy, float2 xy) {
    float2 gradient = noise2d2d(gradient_xy);
    float2 offset = xy - gradient_xy;
    return dot(gradient, offset);
}

float gradientDot3d(float3 gradient_xyz, float3 xyz) {
    float3 gradient = noise3d3d(gradient_xyz);
    float3 offset = xyz - gradient_xyz;
    return dot(gradient, offset);
}

float perlinNoise2d(float2 fraction) {
    float frac_x = fraction.x;
    float frac_y = fraction.y;
    float ein, eout, intp;

    float x1 = floor(fraction.x);
    float x2 = ceil(fraction.x);
    float y1 = floor(fraction.y);
    float y2 = ceil(fraction.y);

    // 1. Dot product of random gradient on four corners
    float x1y1 = gradientDot2d(float2(x1, y1), fraction);
    float x1y2 = gradientDot2d(float2(x1, y2), fraction);
    float x2y1 = gradientDot2d(float2(x2, y1), fraction);
    float x2y2 = gradientDot2d(float2(x2, y2), fraction);

    // Lerp x
    ein = frac(frac_x);
    ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
    float _y1 = lerp(x1y1, x2y1, ein);
    float _y2 = lerp(x1y2, x2y2, ein);

    // Lerp y
    ein = frac(frac_y);
    ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
    float ret = lerp(_y1, _y2, ein);

    return ret * 0.5 + 0.5;
}

float4 paintPerlinNoise2d(float2 vertex_world, float frequency, float octave) {
    float2 fraction = vertex_world * frequency * pow(2, octave);
    float noise = perlinNoise2d(fraction);
    return half4(noise, noise, noise, 1);
}

float perlinNoise3d(float3 fraction) {
    float frac_x = fraction.x;
    float frac_y = fraction.y;
    float frac_z = fraction.z;
    float ein, eout, intp;

    float x1 = floor(fraction.x);
    float x2 = ceil(fraction.x);
    float y1 = floor(fraction.y);
    float y2 = ceil(fraction.y);
    float z1 = floor(fraction.z);
    float z2 = ceil(fraction.z);

    // 1. Dot product of random gradient on four corners
    float x1y1z1 = gradientDot3d(float3(x1, y1, z1), fraction);
    float x1y1z2 = gradientDot3d(float3(x1, y1, z2), fraction);
    float x1y2z1 = gradientDot3d(float3(x1, y2, z1), fraction);
    float x1y2z2 = gradientDot3d(float3(x1, y2, z2), fraction);
    float x2y1z1 = gradientDot3d(float3(x2, y1, z1), fraction);
    float x2y1z2 = gradientDot3d(float3(x2, y1, z2), fraction);
    float x2y2z1 = gradientDot3d(float3(x2, y2, z1), fraction);
    float x2y2z2 = gradientDot3d(float3(x2, y2, z2), fraction);

    // Lerp x
    ein = frac(frac_x);
    ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
    float y1z1 = lerp(x1y1z1, x2y1z1, ein);
    float y1z2 = lerp(x1y1z2, x2y1z2, ein);
    float y2z1 = lerp(x1y2z1, x2y2z1, ein);
    float y2z2 = lerp(x1y2z2, x2y2z2, ein);

    // Lerp y
    ein = frac(frac_y);
    ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
    float _z1 = lerp(y1z1, y2z1, ein);
    float _z2 = lerp(y1z2, y2z2, ein);

    // Lerp y
    ein = frac(frac_z);
    ein = 6 * pow(ein, 5) - 15 * pow(ein, 4) + 10 * pow(ein, 3);
    float ret = lerp(_z1, _z2, ein);

    return ret * 0.5 + 0.5;
}

float4 paintPerlinNoise3d(float3 vertex_world, float frequency, float octave) {
    float3 fraction = vertex_world * frequency * pow(2, octave);
    float noise = perlinNoise3d(fraction);
    return half4(noise, noise, noise, 1);
}

#endif