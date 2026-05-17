Shader "Hidden/Custom/DreamcoreCore"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100
        ZWrite Off Cull Off

        Pass
        {
            Name "DreamcorePass"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float _Pixelation;
            float _Distortion;
            float _Aberration;
            float _NoiseStrength;
            float _LensCurvature; // [Added] Receives the lens curvature parameter
            float4 _TintColor;
            float _TintStrength;

            inline float ScreenNoise(float2 uv, float speed)
            {
                float timeVal = _Time.y * speed;
                return frac(sin(dot(uv + timeVal, float2(12.9898, 78.233))) * 43758.5453);
            }

            // --- New Feature: Fisheye / Barrel Distortion Algorithm ---
            float2 ApplyLensDistortion(float2 uv, float strength)
            {
                if(strength <= 0.001) return uv; // Performance optimization

                // 1. Map UV from [0, 1] to [-1, 1] so that (0,0) is exactly at the screen center
                float2 centeredUV = uv * 2.0 - 1.0;

                // 2. Calculate the square of the distance from the center (r^2)
                float r2 = dot(centeredUV, centeredUV);

                // 3. Apply the classic barrel distortion formula: st' = st * (1 + k * r^2)
                // Slightly adjusted here so the strength parameter yields a more intuitive bulging effect
                float2 distorted_st = centeredUV * (1.0 + r2 * strength * 0.45);

                // 4. Remap UV back from [-1, 1] to [0, 1]
                float2 finalUV = distorted_st * 0.5 + 0.5;

                return finalUV;
            }

            float2 Pixelate(float2 uv, float intensity)
            {
                if (intensity <= 0.001) return uv; 
                float pixelCount = lerp(2048.0, 128.0, intensity); 
                return floor(uv * pixelCount) / pixelCount;
            }

            float2 DistortUV(float2 uv, float intensity)
            {
                if (intensity <= 0.001) return uv;
                float timeString = _Time.y * 1.5;
                
                // 1. Subtle horizontal jitter
                float distortion = sin(uv.y * 15.0 + timeString) * 0.01 * intensity; 
                uv.x += distortion;

                // 2. Vertical screen twitch (V-Sync Tearing simulation)
                float jumpTrigger = step(0.98, frac(sin(_Time.y * 2.14) * 43758.5453));
                float jumpAmount = jumpTrigger * 0.1 * intensity;
                uv.y -= jumpAmount;

                return uv;
            }

            half4 Frag (Varyings input) : SV_Target
            {
                float2 originalUV = input.texcoord;
                
                float2 spatialUV = ApplyLensDistortion(originalUV, _LensCurvature);
                float2 distortedUV = DistortUV(spatialUV, _Distortion);
                float2 finalSampleUV = Pixelate(distortedUV, _Pixelation);

                // 1. Sample the clean center base texture without chromatic aberration
                half4 baseColor = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, finalSampleUV);
                
                // 2. Apply color tint filter to the base image
                half4 tintedBase = lerp(baseColor, _TintColor * baseColor, _TintStrength);

                // 3. Calculate chromatic aberration offsets (Classic Red/Cyan combination)
                float rOffset = 0.015 * _Aberration;
                float cyanOffset = -0.015 * _Aberration; // Green + Blue offset in the same direction creates bright cyan

                half r = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, finalSampleUV + float2(rOffset, 0)).r;
                half g = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, finalSampleUV + float2(cyanOffset, 0)).g;
                half b = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, finalSampleUV + float2(cyanOffset, 0)).b;

                // 4. Extract the chromatic aberration delta (difference values)
                half rDelta = r - baseColor.r;
                half gDelta = g - baseColor.g;
                half bDelta = b - baseColor.b;

                // 5. Layer the aberration delta on top of the tint, allowing cyan/blue to bypass the color filter tinting
                half4 colorWithAberration = tintedBase + half4(rDelta, gDelta, bDelta, 0.0);

                // 6. Overlay dynamic analog noise and scanlines
                float noise = ScreenNoise(finalSampleUV, 1.5);
                half4 finalColor = colorWithAberration + noise * _NoiseStrength;
                
                float scanline = sin(originalUV.y * 800.0) * 0.1 * _NoiseStrength;
                finalColor.rgb -= scanline;
                
                return finalColor;
            }
            ENDHLSL
        }
    }
}