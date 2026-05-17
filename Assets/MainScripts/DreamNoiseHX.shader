Shader "Hengxiao/DreamNoiseHX"
{
    Properties
    {
        // Base tint; multiplied with the texture at the end
        _Color("Color", Color) = (1, 1, 0, 1)
        // Base map; main visible color after sampling
        _BaseMap("Base Map", 2D) = "white" {}
        // Rough displacement: max strength for moving vertices along the normal
        _RoughDisplacement("Roughness (Displacement)", Range(0, 0.2)) = 0.02
        // Noise frequency (higher = finer detail, lower = larger bumps)
        _NoiseFrequency("Noise Frequency", Range(2, 32)) = 10
    }
    SubShader
    {
        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
                float _RoughDisplacement;
                float _NoiseFrequency;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            
            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            // Pseudo-random unit gradient at each integer lattice point.
            float3 LatticeGrad(float3 latticePos)
            {
                float3 h = frac(sin(float3(
                    dot(latticePos, float3(127.1, 311.7,  74.7)),
                    dot(latticePos, float3(269.5, 183.3, 246.1)),
                    dot(latticePos, float3(113.5, 271.9, 246.9)))) * 43758.5453123);
                float3 g = h * 2.0 - 1.0;
                float ln = length(g);
                return ln > 1e-6 ? g / ln : float3(0, 1, 0);
            }

            // Quintic fade for smooth, continuous Perlin interpolation
            float3 FadePQ(float3 t)
            {
                return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
            }

            // 3D Perlin gradient noise
            // Roughly in [-1, 1]; drives vertex displacement
            float PerlinNoise3(float3 p)
            {
                float3 pi = floor(p);
                float3 pf = p - pi;
                float3 w = FadePQ(pf);

                float n000 = dot(LatticeGrad(pi + float3(0, 0, 0)), pf - float3(0, 0, 0));
                float n100 = dot(LatticeGrad(pi + float3(1, 0, 0)), pf - float3(1, 0, 0));
                float n010 = dot(LatticeGrad(pi + float3(0, 1, 0)), pf - float3(0, 1, 0));
                float n110 = dot(LatticeGrad(pi + float3(1, 1, 0)), pf - float3(1, 1, 0));
                float n001 = dot(LatticeGrad(pi + float3(0, 0, 1)), pf - float3(0, 0, 1));
                float n101 = dot(LatticeGrad(pi + float3(1, 0, 1)), pf - float3(1, 0, 1));
                float n011 = dot(LatticeGrad(pi + float3(0, 1, 1)), pf - float3(0, 1, 1));
                float n111 = dot(LatticeGrad(pi + float3(1, 1, 1)), pf - float3(1, 1, 1));

                float nx00 = lerp(n000, n100, w.x);
                float nx01 = lerp(n001, n101, w.x);
                float nx10 = lerp(n010, n110, w.x);
                float nx11 = lerp(n011, n111, w.x);

                float nxy0 = lerp(nx00, nx10, w.y);
                float nxy1 = lerp(nx01, nx11, w.y);

                return lerp(nxy0, nxy1, w.z);
            }

            // Simple two-octave fBm for richer, more natural shape
            float FractalGradientNoise(float3 p)
            {
                float sum = PerlinNoise3(p);
                sum += 0.5 * PerlinNoise3(p * 2.02 + float3(11.7, 3.9, 7.4));
                return sum / 1.5;
            }
            
            struct Varyings
            {
                float4 position : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

  
            // Sample noise in object space
            // Compute displacement offset
            // Move along the normal (key for visible bumps on a plane)
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 v = IN.vertex.xyz;
                float n = FractalGradientNoise(v * _NoiseFrequency);
                float offset = n * _RoughDisplacement;

                // Displace along object-space normal, not radially from the origin.
                // On a Plane this gives mostly Y-axis bumps (terrain-like hills).
                float3 normalOS = normalize(IN.normal);
                float3 posOS = v + normalOS * offset;

                OUT.position = TransformObjectToHClip(posOS);
                OUT.uv = IN.uv;
                return OUT;
            }

            // Fragment stage:
            // Texture sample + tint only, to focus on geometry bumps.
            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv);
                return color * _Color;
            }
            ENDHLSL
        }
    }
}
