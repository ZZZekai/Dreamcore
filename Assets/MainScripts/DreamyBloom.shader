Shader "Jili/DreamyBloom"
{
    Properties
    {
        _Threshold("Threshold", Float) = 0.8
        _Intensity("Intensity", Float) = 2
        _BlurSize("Blur Size", Float) = 2
        _BloomTint("Bloom Tint", Color) = (1,1,1,1)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
        }

        ZWrite Off
        ZTest Always
        Cull Off

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        float _Threshold;
        float _Intensity;
        float _BlurSize;
        float4 _BloomTint;

        float4 _BlurDirection;

        TEXTURE2D(_BloomTex);
        SAMPLER(sampler_BloomTex);

        // Calculate brightness from RGB color
        float GetBrightness(float3 color)
        {
            return dot(
                color,
                float3(0.2126, 0.7152, 0.0722)
            );
        }

        ENDHLSL

        Pass
        {
            Name "Bright Extract"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragBright

            half4 FragBright(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                float3 color =
                    SAMPLE_TEXTURE2D_X(
                        _BlitTexture,
                        sampler_LinearClamp,
                        uv
                    ).rgb;

                // Convert color to brightness value

                float brightness =
                    GetBrightness(color);

                float mask =
                    saturate(
                        (brightness - _Threshold)
                        / max(0.0001, 1.0 - _Threshold) // If brightness lower than _Threshold, result close to 0
                    );

                float3 bright =
                    color * mask;

                return half4(bright, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "Blur"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragBlur

            half4 FragBlur(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                //Calculate the blur offse
                //_BlurDirection decides horizontal or vertical blur

                float2 texel =
                    _BlitTexture_TexelSize.xy
                    * _BlurSize
                    * _BlurDirection.xy;

                float3 color = 0;

                //samples nearby pixels and mixes them together

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv - texel * 4
                ).rgb * 0.05;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv - texel * 3
                ).rgb * 0.09;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv - texel * 2
                ).rgb * 0.12;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv - texel
                ).rgb * 0.15;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv
                ).rgb * 0.18; // the highest weight for centre

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv + texel
                ).rgb * 0.15;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv + texel * 2
                ).rgb * 0.12;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv + texel * 3
                ).rgb * 0.09;

                color += SAMPLE_TEXTURE2D_X(
                    _BlitTexture,
                    sampler_LinearClamp,
                    uv + texel * 4
                ).rgb * 0.05;

                return half4(color, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "Composite"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragComposite

            half4 FragComposite(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                float3 scene =
                    SAMPLE_TEXTURE2D_X(
                        _BlitTexture,
                        sampler_LinearClamp,
                        uv
                    ).rgb;

                float waveX =
                    sin(uv.y * 20.0 + _Time.y * 2.0) * 0.005;

                float waveY =
                    cos(uv.x * 16.0 + _Time.y * 1.5) * 0.002;

                float2 bloomUV =
                    uv + float2(waveX, waveY);

                float3 bloom =
                    SAMPLE_TEXTURE2D(
                        _BloomTex,
                        sampler_BloomTex,
                        bloomUV
                    ).rgb;

                float3 finalColor =
                    scene + bloom * _BloomTint.rgb * _Intensity;//controls the color and strength of the glow

                return half4(finalColor, 1);
            }

            ENDHLSL
        }

        Pass
        {
            Name "Copy"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment FragCopy

            half4 FragCopy(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;

                float3 color =
                    SAMPLE_TEXTURE2D_X(
                        _BlitTexture,
                        sampler_LinearClamp,
                        uv
                    ).rgb;

                return half4(color, 1);
            }

            ENDHLSL
        }
    }
}