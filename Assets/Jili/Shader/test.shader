Shader "Jili/DreamyGlow"
{
    Properties
    {
        _BaseColor ("Base Color", Color) =
        (0.3,0.8,1,1)

        _ShadowColor ("Shadow Color", Color) =
        (0.4,0.5,0.9,1)

        _LightColor ("Light Color", Color) =
        (1,0.85,0.7,1)

        _GlowColor ("Glow Color", Color) =
        (1,0.8,1,1)

        _FogColor ("Fog Color", Color) =
        (0.6,0.9,1,1)

        _FresnelPower ("Fresnel Power", Range(1,8)) = 4

        _GlowIntensity ("Glow Intensity", Range(0,10)) = 3

        _FogDensity ("Fog Density", Range(0,1)) = 0.05

        _NoiseIntensity ("Noise Intensity", Range(0,1)) = 0.05
        
        _NoiseScale ("Noise Scale", Range(1,500)) = 120
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
            };

            float4 _BaseColor;
            float4 _ShadowColor;
            float4 _LightColor;
            float4 _GlowColor;
            float4 _FogColor;

            float _FresnelPower;
            float _GlowIntensity;
            float _FogDensity;

            float _NoiseIntensity;
            float _NoiseScale;

            v2f vert (appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldPos =
                    mul(unity_ObjectToWorld, v.vertex).xyz;

                o.worldNormal =
                    UnityObjectToWorldNormal(v.normal);

                o.viewDir =
                    normalize(
                        _WorldSpaceCameraPos
                        - o.worldPos
                    );

                o.screenPos = ComputeScreenPos(o.pos);

                return o;
            }
            
            float random(float2 uv)
            {
                // 加入 _Time.y 使得噪点随时间变化
                return frac(sin(dot(uv, float2(12.9898, 78.233) + _Time.y)) * 43758.5453);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 N =
                    normalize(i.worldNormal);

                float3 V =
                    normalize(i.viewDir);

                float3 L =
                    normalize(_WorldSpaceLightPos0.xyz);

                // ===== 漫反射 =====

                float ndl =
                    saturate(dot(N,L));

                ndl =
                    smoothstep(0,1,ndl);

                // 彩色阴影混合

                float3 lighting =
                    lerp(
                        _ShadowColor.rgb,
                        _LightColor.rgb,
                        ndl
                    );

                float3 color =
                    _BaseColor.rgb * lighting;

                // ===== Fresnel =====

                float fresnel =
                    pow(
                        1.0 -
                        saturate(dot(N,V)),
                        _FresnelPower
                    );

                color +=
                    fresnel *
                    _GlowColor.rgb *
                    _GlowIntensity;

                // ===== 雾 =====

                float dist =
                    distance(
                        _WorldSpaceCameraPos,
                        i.worldPos
                    );

                float fog =
                    1.0 -
                    exp(
                        -dist * _FogDensity
                    );

                color =
                    lerp(
                        color,
                        _FogColor.rgb,
                        fog
                    );

                // ===== Noise =====
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
    
                // 使用单色噪点更符合艺术质感
                float noise = random(screenUV * _NoiseScale);

                // 移除 brightness 遮罩，让暗部也有颗粒
                // 使用简单的叠加方式，或者使用 Overlay 算法
                float3 grain = (noise - 0.5) * _NoiseIntensity;

                color += grain; // 直接叠加到最终颜色
                return float4(color, 1);
            }

            ENDHLSL
        }
    }
}