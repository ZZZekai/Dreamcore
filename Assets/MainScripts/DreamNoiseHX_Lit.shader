Shader "Hengxiao/DreamNoiseHX_Lit"
{
    Properties
    {
        // Base tint; multiplied with the texture at the end
        _Color("Color", Color) = (1, 1, 0, 1)
        // Base map; main surface color
        _BaseMap("Base Map", 2D) = "white" {}

        // Displacement strength (bumpy surface)
        _DisplaceAmount("Displace Amount", Range(0, 5)) = 0.02
        // Noise scale (higher = finer detail, lower = larger blobs)
        _NoiseScale("Noise Scale", Range(2, 32)) = 10
        // Collapse strength (sink toward the ground)
        _CollapseAmount("Collapse Amount", Range(0, 1)) = 0
        // Top bias (higher = collapse more on upward-facing surfaces)
        _TopBias("Top Bias", Range(0, 1)) = 0.7
        // Height falloff (higher = more collapse at higher local Y)
        _HeightFalloff("Height Falloff", Range(0.5, 4)) = 1.8

        // Ambient strength (floor brightness); keeps back faces from going fully black
        _AmbientStrength("Ambient Strength", Range(0, 1)) = 0.2
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }

        HLSLINCLUDE
        // Transforms; InputData for Forward+ clustered lights; Lighting for main light and LIGHT_LOOP
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
            half4 _Color;
            float _DisplaceAmount;
            float _NoiseScale;
            float _CollapseAmount;
            float _TopBias;
            float _HeightFalloff;
            float _AmbientStrength;
        CBUFFER_END

        TEXTURE2D(_BaseMap);
        SAMPLER(sampler_BaseMap);

        // Lattice gradient for Perlin / gradient noise
        float3 LatticeGrad(float3 latticePos)
        {
            float3 h = frac(sin(float3(
                dot(latticePos, float3(127.1, 311.7, 74.7)),
                dot(latticePos, float3(269.5, 183.3, 246.1)),
                dot(latticePos, float3(113.5, 271.9, 246.9)))) * 43758.5453123);
            float3 g = h * 2.0 - 1.0;
            float ln = length(g);
            return ln > 1e-6 ? g / ln : float3(0, 1, 0);
        }

        // Quintic fade for smoother noise interpolation
        float3 FadePQ(float3 t)
        {
            return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
        }

        // Single octave of 3D Perlin noise
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

        // Two-octave fBm for richer shape detail
        float FractalGradientNoise(float3 p)
        {
            float sum = PerlinNoise3(p);
            sum += 0.5 * PerlinNoise3(p * 2.02 + float3(11.7, 3.9, 7.4));
            return sum / 1.5;
        }

        // Displacement: bumpy offset along normal plus collapse toward ground
        float3 DisplacePositionOS(float3 posOS, float3 normalOS)
        {
            float n = FractalGradientNoise(posOS * _NoiseScale);
            float3 normalDirOS = normalize(normalOS);

            // World down (0,-1,0) in object space so collapse stays toward ground when the mesh rotates
            float3 downDirOS = normalize(mul((float3x3)unity_WorldToObject, float3(0.0, -1.0, 0.0)));

            // Bumpy offset along normal (positive or negative)
            float roughOffset = n * _DisplaceAmount;

            // Collapse only downward (remap noise to [0,1])
            float collapseNoise = n * 0.5 + 0.5;

            // Top bias: stronger collapse when the normal points up
            float upMask = saturate(dot(normalize(TransformObjectToWorldNormal(normalDirOS)), float3(0.0, 1.0, 0.0)));
            float topWeight = lerp(1.0, upMask, _TopBias);

            // Height weight: stronger collapse at higher local Y; weight is 0 when y <= 0 (good for characters with feet below y=0).
            // No global clamp at y >= 0 on the final vertex—that breaks center-pivot meshes (chair legs, bottom of a sphere get flattened).
            float height01 = saturate(posOS.y);
            float heightWeight = pow(height01, _HeightFalloff);

            float collapseOffset = collapseNoise * _DisplaceAmount * _CollapseAmount * topWeight * heightWeight;

            // Final position = bumpy offset + downward collapse
            return posOS + normalDirOS * roughOffset + downDirOS * collapseOffset;
        }

        // Approximate displaced normal with finite differences
        float3 EstimateDisplacedNormalOS(float3 posOS, float3 normalOS)
        {
            float3 n = normalize(normalOS);
            float3 refUp = abs(n.y) < 0.99 ? float3(0, 1, 0) : float3(1, 0, 0);
            float3 t = normalize(cross(refUp, n));
            float3 b = normalize(cross(n, t));

            float eps = 0.01;
            float3 pC = DisplacePositionOS(posOS, n);
            float3 pT = DisplacePositionOS(posOS + t * eps, n);
            float3 pB = DisplacePositionOS(posOS + b * eps, n);

            return normalize(cross(pT - pC, pB - pC));
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            // Forward+ additional lights use clustered loop; need _CLUSTER_LIGHT_LOOP or GetAdditionalLightsCount() is always 0
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 shadowCoord : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                // Same as positionCS; for GetNormalizedScreenSpaceUV / clustered lights in the fragment (SV_POSITION is not always valid there)
                float4 clipPos : TEXCOORD4;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 posOS = DisplacePositionOS(IN.vertex.xyz, IN.normal);
                float3 normalOS = EstimateDisplacedNormalOS(IN.vertex.xyz, IN.normal);

                VertexPositionInputs posInputs = GetVertexPositionInputs(posOS);
                OUT.positionCS = posInputs.positionCS;
                OUT.clipPos = posInputs.positionCS;
                OUT.uv = IN.uv;
                OUT.normalWS = TransformObjectToWorldNormal(normalOS);
                OUT.positionWS = posInputs.positionWS;
                OUT.shadowCoord = TransformWorldToShadowCoord(posInputs.positionWS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 baseCol = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _Color;
                float3 normalWS = normalize(IN.normalWS);

                // Main light with shadow attenuation
                Light mainLight = GetMainLight(IN.shadowCoord);
                float3 lightDir = normalize(mainLight.direction);
                float NdotL = saturate(dot(normalWS, lightDir));

                // Main directional light (usually a Directional Light)
                float3 diffuse = baseCol.rgb * mainLight.color * (NdotL * mainLight.shadowAttenuation);

                // Additional lights (point, spot, etc.): Forward uses a for loop; Forward+ must use LIGHT_LOOP_BEGIN (cluster iteration)
                InputData inputData = (InputData)0;
                inputData.positionWS = IN.positionWS;
                inputData.positionCS = IN.clipPos;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.clipPos);

                uint additionalLightsCount = GetAdditionalLightsCount();
                LIGHT_LOOP_BEGIN(additionalLightsCount)
                    Light addLight = GetAdditionalLight(lightIndex, inputData.positionWS);
                    float3 addDir = normalize(addLight.direction);
                    float addNdotL = saturate(dot(normalWS, addDir));
                    float addAtten = addLight.distanceAttenuation * addLight.shadowAttenuation;
                    diffuse += baseCol.rgb * addLight.color * (addNdotL * addAtten);
                LIGHT_LOOP_END

                float3 ambient = baseCol.rgb * _AmbientStrength;
                return half4(diffuse + ambient, baseCol.a);
            }
            ENDHLSL
        }

        // Custom ShadowCaster pass: same displacement on the shadow map so shadows follow the bumps
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings ShadowPassVertex(Attributes IN)
            {
                Varyings OUT;
                float3 posOS = DisplacePositionOS(IN.vertex.xyz, IN.normal);
                float3 normalOS = EstimateDisplacedNormalOS(IN.vertex.xyz, IN.normal);

                float3 positionWS = TransformObjectToWorld(posOS);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);

                float3 biasedWS = ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz);
                OUT.positionCS = TransformWorldToHClip(biasedWS);
                return OUT;
            }

            half4 ShadowPassFragment(Varyings IN) : SV_Target
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
