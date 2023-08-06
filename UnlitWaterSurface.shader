Shader "Unlit/UnlitWaterSurface"
{
    Properties
    {
        [Toggle(SHOW_DEPTH)] _ShowDepth("Show Depth", float) = 0
        [Toggle(SHOW_SCREEN_POS)] _ShowScreenPos("Show Screen Position", float) = 0
        [Toggle(SHOW_UNDERWATER_DEPTH)] _ShowUnderwaterDepth("Show Underwater Depth", float) = 0
        [Toggle(SHOW_UNDERWATER_COLOR)] _ShowUnderwaterColor("Show Underwater Color", float) = 0
        [Toggle(SHOW_FRESNEL_COLOR)] _SHOW_FRESNEL_COLOR("Show Fresnel Color", float) = 0
        [Toggle(SHOW_REFRACTION)] _SHOW_REFRACTION("Show Refraction", float) = 0
        [Toggle(SHOW_REFRACTION_OFFSET)] _ShowRefrectionOffset("Show Refraction offset", float) = 0
        [Toggle(SHOW_RIPPLE_NOISE)] _ShowRippleNoise("Show Ripple Noise", float) = 0
        [Toggle(SHOW_REFLECTION)] _SHOW_REFLECTION("Show Reflection", float) = 0
        [Toggle(SHOW_FINAL)] _SHOW_FINAL("Show Final", float) = 1

        [Header(Underwater Depth)]
        _UnderwaterDepthScale("Underwater Depth Scale", float) = 50
        _UnderwaterNearColor ("Underwater Near Color", Color) = (1,0,0,0)
        _UnderwaterFarColor ("Underwater Far Color", Color) = (0,1,0,0)
        _UnderwaterWeight ("Underwater Color Weight", Range(0, 1)) = 0.5

        [Header(Fresnel Effect)]
        _NearColor ("Near Color", Color) = (1,0,0,0)
        _FarColor ("Far Color", Color) = (0,1,0,0)
        _FresnelBias ("Fresnel Bias", float) = 0
        _FresnelScale ("Fresnel Scale", float) = 1

        [Header(Refraction)]
        _RefractionNormalWeight ("Reflection Normal Weight", Range(0, 1)) = 0 // How distorted you want the refraction be?

        [Header(Reflection)]
        _ReflectionMap("Reflection Texture", 2D) = "white" {}
        _ReflectNormalScale("Reflection Normal Vector Scale", float) = 1.0
        _ReflectNormalOffsetScale("Reflection Normal Vector Offset Weight", Range(0, 1)) = 1.0
        _ReflectionColor ("Reflection Color", Color) = (0,0,1,0)
        _ReflectionStep ("Reflection Color Step Threshold", Range(0, 1)) = 0.2

        _SpotLightColor ("Spot Light Color", Color) = (0,0,1,0)
        _SpotLightStep ("Spot Light Reflection Color Step Threshold", Range(0, 1)) = 0.2
        _SpotLightWorldPosition ("Spot Light World Position", Vector) = (0, 0, 0, 0)

        [Header(Ripple)]
        _FlowMap("Ripple Flow Texture (RG)", 2D) = "white" {} // Distort the ripple with this texture
        _NoiseFrequency ("Noise Frequency", float) = 1.0
        _NoiseOctave ("Noise Octave", int) = 0
        _RippleWidth ("Ripple Width", Range(0, 1)) = 0.2
        _RippleRange ("Ripple Range", float) = 10
        _RippleWiggleSpeed ("Ripple Wiggle Speed", float) = 0.5
        _RippleColor ("Ripple Color", Color) = (0,0,1,0)

        [Header(Wave)]
        _WaveA ("Wave A (Direction x, Steepness, Direction z, Wavelength)", Vector) = (1.0, 0.5, 0.0, 13.0)
        _WaveB ("Wave B (Direction x, Steepness, Direction z, Wavelength)", Vector) = (1.0, 0.5, 0.0, 13.0)
        _WaveC ("Wave C (Direction x, Steepness, Direction z, Wavelength)", Vector) = (1.0, 0.5, 0.0, 13.0)
    }
    SubShader
    {
        Tags { "RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Transparent" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature SHOW_DEPTH SHOW_SCREEN_POS SHOW_UNDERWATER_DEPTH SHOW_FRESNEL_COLOR SHOW_UNDERWATER_COLOR SHOW_REFRACTION SHOW_REFRACTION_OFFSET SHOW_RIPPLE_NOISE SHOW_REFLECTION SHOW_FINAL

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            #include "./PerlinNoise.hlsl"
            #include "./ValueNoise.hlsl"
            #include "./Trochoid.hlsl"

            struct appdata
            {
                float4 positionOS   : POSITION;                 
                half3 normal : NORMAL;
                float3 tangent: TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 positionHCS  : SV_POSITION;
                half3 normal : TEXCOORD4;
                float2 uv_flow : TEXCOORD1;
                float fresnelRefCoef : TEXCOORD2;
                float3 worldPos: TEXCOORD3;
            };
            
            TEXTURE2D(_FlowMap);
            SAMPLER(sampler_FlowMap);

            TEXTURE2D(_ReflectionMap);
            SAMPLER(sampler_ReflectionMap);

            CBUFFER_START(UnityPerMaterial)
                float _UnderwaterDepthScale;

                float4 _NearColor;
                float4 _FarColor;
                float _FresnelBias;
                float _FresnelScale;

                float4 _UnderwaterNearColor;
                float4 _UnderwaterFarColor;
                float _UnderwaterWeight;

                float _RefractionNormalWeight;

                float _NoiseOctave;
                float _NoiseFrequency;
                float _RippleWidth;
                float _RippleRange;
                float _RippleWiggleSpeed;
                float4 _FlowMap_ST;
                float4 _RippleColor;

                float4 _ReflectionMap_ST;
                float _ReflectNormalScale;
                float _ReflectNormalOffsetScale;
                float4 _ReflectionColor;
                float _ReflectionStep;
                float4 _SpotLightColor;
                float _SpotLightStep;
                float3 _SpotLightWorldPosition;

                float4 _WaveA;
                float4 _WaveB;
                float4 _WaveC;
            CBUFFER_END

            float GetDepth(float4 positionHCS) {
                float2 uv = positionHCS.xy / _ScaledScreenParams.xy;

                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(uv);
                #else
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
                #endif

                return depth;
            }

            float3 GetDistortedSceneColor(float4 positionHCS, float3 normal) {
                // Use y and sin to get offset, add offset to x, sample from offsetted coordinate
                float2 uv = positionHCS.xy / _ScaledScreenParams.xy;
                float2 dist_uv = float2(positionHCS.x + 0, positionHCS.y) / _ScaledScreenParams.xy;
                dist_uv += normal.xz * _RefractionNormalWeight;

                #if UNITY_REVERSED_Z
                    float dist_depth = SampleSceneDepth(dist_uv);
                #else
                    float dist_depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(dist_uv));
                #endif
                float3 dist_scene_color = SampleSceneColor(dist_uv);

                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(uv);
                #else
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
                #endif
                float3 scene_color = SampleSceneColor(uv);

                float surface_depth = frac(positionHCS.z);

                if (surface_depth < dist_depth) {
                    // invalid distorted uv
                    return scene_color;
                }
                else {

                    return dist_scene_color;
                }
            }

            float GetDistortedDepth(float4 positionHCS, float3 normal) {
                // Use y and sin to get offset, add offset to x, sample from offsetted coordinate
                float2 uv = positionHCS.xy / _ScaledScreenParams.xy;
                float2 dist_uv = float2(positionHCS.x + 0, positionHCS.y) / _ScaledScreenParams.xy;
                dist_uv += normal.xz * _RefractionNormalWeight;

                #if UNITY_REVERSED_Z
                    float dist_depth = SampleSceneDepth(dist_uv);
                #else
                    float dist_depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(dist_uv));
                #endif

                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(uv);
                #else
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
                #endif

                float surface_depth = frac(positionHCS.z);

                if (surface_depth < dist_depth) {
                    // invalid distorted uv
                    return depth;
                }
                else {

                    return dist_depth;
                }
            }

            float GetUnderwaterOffset(float4 positionHCS) {
                // Use y and sin to get offset, add offset to x, sample from offsetted coordinate
                float4 pos = positionHCS;
                float offset = 20.38 * sin(2 * 3.1415926 * 1.02 * positionHCS.y);

                // distorted uv
                pos.x += offset;

                // if we're trying to sample an invalid uv ths is behind an object which is above the water surface.
                // (we can't see this new uv so it's not reasonable to sample it)

                float2 distorted_uv = pos.xy / _ScaledScreenParams.xy;
                #if UNITY_REVERSED_Z
                    float depth = SampleSceneDepth(distorted_uv);
                #else
                    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(distorted_uv));
                #endif

                float surface_depth = frac(positionHCS.z);
                if (surface_depth < depth) {
                    // invalid distorted uv
                    return -10;
                }
                
                return offset / 20.38;
            }

            float GetUnderwaterDepth(float depth, float waterSurfaceDepth) {
                float underwater_depth = waterSurfaceDepth - depth;
                underwater_depth *= _UnderwaterDepthScale;
                return saturate(underwater_depth);
            }

            float GetRippleUnderwaterDepth(float depth, float waterSurfaceDepth) {
                float underwater_depth = waterSurfaceDepth - depth;
                underwater_depth *= _RippleRange;
                return saturate(underwater_depth);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.uv_flow = TRANSFORM_TEX(v.uv, _FlowMap);

                // Fresnel
                float3 vertexWorldPosition = TransformObjectToWorld(v.positionOS.xyz);
                float3 cam2vertex = vertexWorldPosition - _WorldSpaceCameraPos;
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                o.fresnelRefCoef = max(0, min(1, _FresnelBias + _FresnelScale * (pow(1 + dot(normalize(cam2vertex), normalize(worldNormal)), 2))));
                o.worldPos = vertexWorldPosition;

                // Trochoid
                float3 pos_obj_space = v.positionOS.xyz;
                pos_obj_space += TrochoidOffset(pos_obj_space, _WaveA, _WaveB, _WaveC);

                // Recalculate normal vector
                float3 tangent = v.tangent;
                float3 normal = v.normal;
                float3 bitangent = normalize(cross(normal, tangent));

                float3 d1 = v.positionOS.xyz + 0.01 * tangent;
                float3 d2 = v.positionOS.xyz + 0.01 * bitangent;

                // Transform to the new position
                d1 += TrochoidOffset(d1, _WaveA, _WaveB, _WaveC);
                d2 += TrochoidOffset(d2, _WaveA, _WaveB, _WaveC);

                // and recauclate tangent and bitangent
                float3 new_tangent = d1 - pos_obj_space;
                float3 new_bitangent = d2 - pos_obj_space;

                float3 new_normal = normalize(cross(new_tangent, new_bitangent));

                o.normal = new_normal;
                o.positionHCS = TransformObjectToHClip(pos_obj_space);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {

                float depth = frac(GetDepth(i.positionHCS));
                float screen_depth = frac(i.positionHCS.z);
                float underwater_depth = GetUnderwaterDepth(depth, screen_depth);

                // Refraction
                float ddepth = GetDistortedDepth(i.positionHCS, i.normal); // distorted depth
                float3 dSceneColor = GetDistortedSceneColor(i.positionHCS, i.normal); // distorted underwater color
                float refrac_underwater_depth = GetUnderwaterDepth(ddepth, screen_depth);

                // Ripple
                float ripple_underwater_depth = GetRippleUnderwaterDepth(ddepth, screen_depth);
                float4 ripple_flow = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, i.uv_flow + _Time.y * _RippleWiggleSpeed) * 2 - 1;
                float4 ripple_noise = paintValueNoise2d(i.worldPos.xz + ripple_flow.rg, _NoiseFrequency, _NoiseOctave);
                float ripple_in_mask = step(0.4 + _RippleWidth, ripple_noise.x);
                float ripple_out_mask = step(0.4, ripple_noise.x);
                float ripple_flag = ripple_out_mask - ripple_in_mask;

                // Reflection
                float4 normals_offset_flow = SAMPLE_TEXTURE2D(_FlowMap, sampler_FlowMap, i.uv_flow * _ReflectNormalScale * 0.5 + _Time.y * 0.05);
                float4 nr = SAMPLE_TEXTURE2D(_ReflectionMap, sampler_ReflectionMap, i.uv_flow * _ReflectNormalScale + normals_offset_flow.xx) * 2 - 1;
                float4 ng = SAMPLE_TEXTURE2D(_ReflectionMap, sampler_ReflectionMap, i.uv_flow * _ReflectNormalScale * 1.2 + normals_offset_flow.xx) * 2 - 1;
                float4 nb = SAMPLE_TEXTURE2D(_ReflectionMap, sampler_ReflectionMap, i.uv_flow * _ReflectNormalScale * 0.6 + normals_offset_flow.xx) * 2 - 1;
                float3 normals_offset = float3(nr.x, ng.x, nb.x);
                float3 normal = i.normal + normals_offset.rgb * _ReflectNormalOffsetScale;
                normal = normalize(normal);

                // Directional light
                float3 incident_vec = float3 (1, -1, 1);
                float attenuation = 1.0 / (1e-3 + length(incident_vec));
                float3 reflect_vec = reflect(normalize(incident_vec), normal);
                float reflec_ratio = max(0, dot(reflect_vec, normal)) * attenuation;
                reflec_ratio = step(_ReflectionStep, reflec_ratio); // 0 or 1

                // Spot Light
                incident_vec = i.worldPos - _SpotLightWorldPosition;
                attenuation = 1.0 / (1e-3 + length(incident_vec));
                reflect_vec = reflect(normalize(incident_vec), normal);
                float reflec_ratio_sl = max(0, dot(reflect_vec, normal)) * attenuation;
                reflec_ratio_sl = step(_SpotLightStep, reflec_ratio_sl); // 0 or 1

                #ifdef SHOW_DEPTH
                    return float4 (depth, depth, depth, 1);
                #endif
                #ifdef SHOW_SCREEN_POS
                    return float4(screen_depth, screen_depth, screen_depth, 1);
                #endif
                #ifdef SHOW_UNDERWATER_DEPTH
                    return float4(underwater_depth, underwater_depth, underwater_depth, 1);
                #endif
                #ifdef SHOW_REFRACTION_OFFSET
                    float offset = GetUnderwaterOffset(i.positionHCS); // -1 ~ 1
                    if (offset == -10) {
                        return float4(0, 0, 1, 1);
                    }
                    else if (offset > 0.0) {
                        return float4(1, 0, 0, 1);
                    }
                    else {
                        return float4(0, 1, 0, 1); // Artifacts on offset < 0 => Sample the depth of objects above water surface
                    }
                #endif
                #ifdef SHOW_REFRACTION
                    // The depth buffer of objects behind the surface
                    return float4(refrac_underwater_depth, refrac_underwater_depth, refrac_underwater_depth, 1);
                #endif
                #ifdef SHOW_UNDERWATER_COLOR
                    float4 underwater_color = lerp(_UnderwaterNearColor, _UnderwaterFarColor, refrac_underwater_depth);
                    return underwater_color * underwater_color.a + float4 (dSceneColor * (1-underwater_color.a), (1-underwater_color.a));
                #endif
                #ifdef SHOW_FRESNEL_COLOR
                    return (1-i.fresnelRefCoef) * _NearColor + (i.fresnelRefCoef) * _FarColor;
                #endif
                #ifdef SHOW_RIPPLE_NOISE
                    return ripple_flag == 1 ? (1 - ripple_underwater_depth) * _RippleColor : float4(0, 0, 0, 1);
                #endif
                #ifdef SHOW_REFLECTION
                    return _ReflectionColor * reflec_ratio_sl;
                #endif
                #ifdef SHOW_FINAL
                    float4 underwater_color = lerp(_UnderwaterNearColor, _UnderwaterFarColor, refrac_underwater_depth);
                    underwater_color = underwater_color * underwater_color.a + float4 (dSceneColor * (1-underwater_color.a), (1-underwater_color.a));
                    float4 fresnel_color = (1-i.fresnelRefCoef) * _NearColor + (i.fresnelRefCoef) * _FarColor;
                    float4 ret_color = saturate(underwater_color * _UnderwaterWeight + fresnel_color * (1 - _UnderwaterWeight));
                    
                    ret_color +=  float4(_ReflectionColor.rgb * reflec_ratio * _ReflectionColor.a, 1);
                    ret_color +=  float4(_SpotLightColor.rgb * reflec_ratio_sl * _SpotLightColor.a, 1);
                    if (ripple_flag) {
                        ret_color += (1 - ripple_underwater_depth) * _RippleColor;
                    }
                    return ret_color;
                #endif


            }
            ENDHLSL
        }
    }
}