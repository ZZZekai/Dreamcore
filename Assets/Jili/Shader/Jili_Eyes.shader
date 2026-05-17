Shader "Jili/Eyes"
{
    Properties
    {
        _EyeDensity ("Eye Density", Range(1, 20)) = 8.0
        _EyeThreshold ("Eye Spawn Chance", Range(0, 1)) = 0.2
        _EyeSize ("Eye Size", Range(0.1, 0.5)) = 0.3
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // 引用 URP 屏幕纹理
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 screenUV : TEXCOORD0; };

            float _EyeDensity, _EyeThreshold, _EyeSize;

            float Rand(float2 seed) { return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453); }

            // 绘制眼睛 SDF
            float DrawEye(float2 uv) {
                float2 p = uv * 2.0 - 1.0;
                float eyeShape = length(p * float2(1.0, 1.7)); 
                float eyeMask = smoothstep(_EyeSize, _EyeSize - 0.05, eyeShape);
                float pupil = smoothstep(_EyeSize * 0.4, _EyeSize * 0.3, length(p));
                return saturate(eyeMask - pupil);
            }

            Varyings vert(Attributes input) {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.screenUV = input.uv;
                return output;
            }

            half4 frag(Varyings i) : SV_Target {
                // 1. 获取场景原始颜色
                float3 sceneColor = SampleSceneColor(i.screenUV);

                // 2. 屏幕空间网格化
                // 使用屏幕比例修正，防止眼睛被拉扁
                float aspect = _ScreenParams.x / _ScreenParams.y;
                float2 gridUV = i.screenUV * _EyeDensity;
                gridUV.x *= aspect;

                float2 gridID = floor(gridUV);
                float2 localUV = frac(gridUV);

                // 3. 随机生成眼睛
                float3 eyeColor = 0;
                if(Rand(gridID) < _EyeThreshold) {
                    // 随机抖动眼睛位置
                    float2 offset = float2(Rand(gridID + 0.5), Rand(gridID + 0.3)) * 0.5 - 0.25;
                    float m = DrawEye(localUV + offset);
                    
                    // 眼睛颜色（淡粉紫色的眼白，增加梦核感）
                    eyeColor = m * float3(0.9, 0.85, 1.0);
                }

                // 4. 混合：将眼睛“贴”在场景上
                // 使用 Additive 或 Alpha Blending
                float3 finalColor = sceneColor + eyeColor;

                return half4(finalColor, 1.0);
            }
            ENDHLSL
        }
    }
}