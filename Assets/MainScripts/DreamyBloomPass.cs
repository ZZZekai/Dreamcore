using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;
using UnityEngine.Rendering.Universal;

//creates a custom dreamy bloom effect.
public class DreamyBloomPass : ScriptableRenderPass
{
    // Materials used for bloom and blur
    private readonly Material bloomMaterial;
    private readonly Material blurHorizontalMaterial;
    private readonly Material blurVerticalMaterial;

    private readonly DreamyBloomFeature.DreamyBloomSettings settings;

    private static readonly int ThresholdID =
        Shader.PropertyToID("_Threshold");

    private static readonly int IntensityID =
        Shader.PropertyToID("_Intensity");

    private static readonly int BlurSizeID =
        Shader.PropertyToID("_BlurSize");

    private static readonly int BloomTintID =
        Shader.PropertyToID("_BloomTint");

    private static readonly int BlurDirectionID =
        Shader.PropertyToID("_BlurDirection");

    private static readonly int BloomTexID =
        Shader.PropertyToID("_BloomTex");

    // Constructor
    // receives the materials and bloom settings
    public DreamyBloomPass(
        Material bloomMaterial,
        Material blurHorizontalMaterial,
        Material blurVerticalMaterial,
        DreamyBloomFeature.DreamyBloomSettings settings)
    {
        this.bloomMaterial = bloomMaterial;
        this.blurHorizontalMaterial = blurHorizontalMaterial;
        this.blurVerticalMaterial = blurVerticalMaterial;
        this.settings = settings;
    }

    // Records all render graph passes
    public override void RecordRenderGraph(
        RenderGraph renderGraph,
        ContextContainer frameData)
    {
        if (bloomMaterial == null)
        {
            return;
        }

        UniversalResourceData resourceData =
            frameData.Get<UniversalResourceData>();

        UniversalCameraData cameraData =
            frameData.Get<UniversalCameraData>();

        if (resourceData.isActiveTargetBackBuffer)
        {
            return;
        }

        TextureHandle source =
            resourceData.activeColorTexture;

        if (!source.IsValid())
        {
            return;
        }

        RenderTextureDescriptor cameraDesc =
            cameraData.cameraTargetDescriptor;

        cameraDesc.depthBufferBits = 0;
        cameraDesc.msaaSamples = 1;

        // Create a half-size texture
        // Half size, cheaper for blur
        RenderTextureDescriptor halfDesc = cameraDesc;
        halfDesc.width = Mathf.Max(1, cameraDesc.width / 2);
        halfDesc.height = Mathf.Max(1, cameraDesc.height / 2);

        //Texture for bright areas
        TextureHandle brightTex =
            UniversalRenderer.CreateRenderGraphTexture(
                renderGraph,
                halfDesc,
                "_DreamyBloom_Bright",
                false
            );

        //Temporary texture for blur
        TextureHandle blurA =
            UniversalRenderer.CreateRenderGraphTexture(
                renderGraph,
                halfDesc,
                "_DreamyBloom_BlurA",
                false
            );

        //Another temporary texture for blur
        TextureHandle blurB =
            UniversalRenderer.CreateRenderGraphTexture(
                renderGraph,
                halfDesc,
                "_DreamyBloom_BlurB",
                false
            );

        //Final full-size texture
        TextureHandle finalTex =
            UniversalRenderer.CreateRenderGraphTexture(
                renderGraph,
                cameraDesc,
                "_DreamyBloom_Final",
                false
            );

        //Update bloom parameters before rendering
        UpdateMaterialParameters();

        // extract bright areas from the scene
        RenderGraphUtils.BlitMaterialParameters brightParams =
            new RenderGraphUtils.BlitMaterialParameters(
                source,
                brightTex,
                bloomMaterial,
                0
            );

        renderGraph.AddBlitPass(
            brightParams,
            "Dreamy Bloom Bright Extract"
        );

        //blur the bright texture horizontally
        blurHorizontalMaterial.SetVector(
            BlurDirectionID,
            new Vector4(1, 0, 0, 0)
        );

        RenderGraphUtils.BlitMaterialParameters blurHParams =
            new RenderGraphUtils.BlitMaterialParameters(
                brightTex,
                blurA,
                blurHorizontalMaterial,
                1
            );

        renderGraph.AddBlitPass(
            blurHParams,
            "Dreamy Bloom Blur Horizontal"
        );

        //blur the texture vertically
        blurVerticalMaterial.SetVector(
            BlurDirectionID,
            new Vector4(0, 1, 0, 0)
        );

        RenderGraphUtils.BlitMaterialParameters blurVParams =
            new RenderGraphUtils.BlitMaterialParameters(
                blurA,
                blurB,
                blurVerticalMaterial,
                1
            );

        renderGraph.AddBlitPass(
            blurVParams,
            "Dreamy Bloom Blur Vertical"
        );

        // Save the blurred bloom texture as a global texture
        // composite pass will use it later
        using (var builder =
            renderGraph.AddRasterRenderPass<SetBloomTexturePassData>(
                "Dreamy Bloom Set Bloom Texture",
                out var passData))
        {
            passData.bloomTexture = blurB;

            builder.UseTexture(blurB, AccessFlags.Read);
            builder.SetGlobalTextureAfterPass(blurB, BloomTexID);
            builder.AllowPassCulling(false);

            builder.SetRenderFunc(
                static (
                    SetBloomTexturePassData data,
                    RasterGraphContext context) =>
                {
                    //only sends blurB to the shader
                }
            );
        }

        //Combine the original scene and the bloom texture
        RenderGraphUtils.BlitMaterialParameters compositeParams =
            new RenderGraphUtils.BlitMaterialParameters(
                source,
                finalTex,
                bloomMaterial,
                2
            );

        using (var builder =
            renderGraph.AddBlitPass(
                compositeParams,
                "Dreamy Bloom Composite",
                returnBuilder: true))
        {
            builder.UseGlobalTexture(BloomTexID, AccessFlags.Read);
        }

        // Use the final texture as the new camera color
        resourceData.cameraColor = finalTex;
    }

    // Update bloom values every frame.
    private void UpdateMaterialParameters()
    {
        // Create a value that changes between 0 and 1 over time
        float pulse =
            Mathf.Sin(Time.time * settings.glowSpeed) * 0.5f + 0.5f;

        // Use the pulse value to animate bloom intensity
        float animatedIntensity =
            Mathf.Lerp(
                settings.minIntensity,
                settings.maxIntensity,
                pulse
            );

        // Send the same values to all bloom materials
        SetCommonMaterialValues(bloomMaterial, animatedIntensity);
        SetCommonMaterialValues(blurHorizontalMaterial, animatedIntensity);
        SetCommonMaterialValues(blurVerticalMaterial, animatedIntensity);
    }

    // Set common shader values
    private void SetCommonMaterialValues(
        Material material,
        float animatedIntensity)
    {
        // Stop if the material is missing
        if (material == null)
        {
            return;
        }

        // Send settings to the shader
        material.SetFloat(ThresholdID, settings.threshold);
        material.SetFloat(IntensityID, animatedIntensity);
        material.SetFloat(BlurSizeID, settings.blurSize);
        material.SetColor(BloomTintID, settings.bloomTint);
    }

    // Data used by the render graph pass
    private class SetBloomTexturePassData
    {
        public TextureHandle bloomTexture;
    }
}