Shader "Jili/Color"
{
    Properties
    {
        [Header(Base Settings)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _BaseColor ("Base Color Tint", Color) = (1, 1, 1, 1)
        
        [Header(Oil Paint Effect)]
        _PosterizeSteps ("Color Steps (Oil Paint)", Range(2, 20)) = 8.0
        _JitterStrength ("Brush Stroke Jitter", Range(0, 0.05)) = 0.01
        
        [Header(Dreamcore Tones)]
        _ShadowBlue ("Shadow Blue Tone", Color) = (0.5, 0.6, 1, 1)
        _HighlightPink ("Highlight Pink Tone", Color) = (1, 0.8, 0.9, 1)
        
        [Header(Glow Effect)]
        [HDR] _GlowColor ("Fresnel Glow Color", Color) = (1, 0.5, 0.8, 1)
        _FresnelPower ("Fresnel Sharpness", Range(0.5, 10)) = 3.0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }
        LOD 100

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS     : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalWS     : TEXCOORD1;
                float3 viewDirWS    : TEXCOORD2;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BaseColor;
                float4 _ShadowBlue;
                float4 _HighlightPink;
                float4 _GlowColor;
                float _PosterizeSteps;
                float _JitterStrength;
                float _FresnelPower;
            CBUFFER_END

            float MyCustomRand(float2 seed)
            {
                return frac(sin(dot(seed, float2(12.9898, 78.233))) * 43758.5453);
            }

            Varyings vert (Attributes input)
            {
                Varyings output = (Varyings)0;
                
                // 修正：使用 GetVertexPositionInputs 获取世界和裁剪空间坐标
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                
                output.positionCS = vertexInput.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // 修正：确保 GetWorldSpaceViewDir 使用正确的输入变量名
                output.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

                return output;
            }

            half4 frag (Varyings i) : SV_Target
            {
                // 1. UV 抖动
                float noiseX = MyCustomRand(i.uv);
                float noiseY = MyCustomRand(i.uv + float2(1.0, 1.0));
                float2 uvJitter = float2(noiseX, noiseY) * _JitterStrength;
                float2 finalUV = i.uv + uvJitter;

                // 2. 采样
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, finalUV) * _BaseColor;
                float3 color = texColor.rgb;

                // 3. 梦核调色
                float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
                float3 dreamTone = lerp(_ShadowBlue.rgb, _HighlightPink.rgb, luma);
                color *= dreamTone;

                // 4. 油画色块化
                color = floor(color * _PosterizeSteps) / _PosterizeSteps;

                // 5. 菲涅尔发光
                float3 normal = normalize(i.normalWS);
                float3 viewDir = normalize(i.viewDirWS);
                float fresnel = 1.0 - saturate(dot(normal, viewDir));
    
                // 使用 pow 控制边缘的硬度：数值越小（如 1.5），光扩散得越远；数值越大（如 8），光越细
                fresnel = pow(fresnel, _FresnelPower);
    
                // 强制增强：直接乘一个很大的系数，或者在 HDR 颜色面板里调节
                float3 glow = fresnel * _GlowColor.rgb * _GlowColor.a * 10.0; // 这里手动乘了10倍

                // 梦核特有的“过曝”处理：让发光稍微影响一下物体本身的颜色
                color += glow * 0.5; 

    return half4(color + glow, 1.0);
            }
            ENDHLSL
        }
    }
}