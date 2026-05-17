Shader "Jili/UICircleMask"
{
    Properties
    {
        _OutsideColor ("Outside Color", Color) = (0, 0, 0, 1)

        _Radius ("Radius", Range(0.1, 1.0)) = 0.48
        _Softness ("Softness", Range(0.001, 0.3)) = 0.04

        _CenterX ("Center X", Range(0, 1)) = 0.5
        _CenterY ("Center Y", Range(0, 1)) = 0.5

        _EdgeDistortion ("Edge Distortion", Range(0, 0.1)) = 0.015
        _DistortionScale ("Distortion Scale", Range(1, 50)) = 12
        _DistortionSpeed ("Distortion Speed", Range(0, 5)) = 0.4
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "RenderType"="Transparent"
            "RenderPipeline"="UniversalPipeline"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Name "UI Circle Mask"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            float4 _OutsideColor;
            float _Radius;
            float _Softness;
            float _CenterX;
            float _CenterY;

            float _EdgeDistortion;
            float _DistortionScale;
            float _DistortionSpeed;

            float random(float2 p)
            {
                return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
            }

            float noise(float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);

                float a = random(i);
                float b = random(i + float2(1.0, 0.0));
                float c = random(i + float2(0.0, 1.0));
                float d = random(i + float2(1.0, 1.0));

                float2 u = f * f * (3.0 - 2.0 * f);

                return lerp(a, b, u.x)
                     + (c - a) * u.y * (1.0 - u.x)
                     + (d - b) * u.x * u.y;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uv = IN.uv;

                float2 center = float2(_CenterX, _CenterY);
                float2 dir = uv - center;
                float dist = length(dir);

                float2 safeDir = normalize(dir + 0.0001);

                float edgeNoise =
                    noise(safeDir * _DistortionScale + _Time.y * _DistortionSpeed);

                float distortedRadius =
                    _Radius + (edgeNoise - 0.5) * _EdgeDistortion;

                // 圆内透明，圆外黑色
                float outsideAlpha =
                    smoothstep(
                        distortedRadius - _Softness,
                        distortedRadius,
                        dist
                    );

                half4 col = _OutsideColor;
                col.a *= outsideAlpha;

                return col;
            }

            ENDHLSL
        }
    }
}