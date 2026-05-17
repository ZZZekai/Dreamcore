using UnityEngine;

public class ShaderController : MonoBehaviour
{
    [Header("Noise / Collapse Object Renderers")]
    public Renderer[] targetRenderers;
    private MaterialPropertyBlock block;

    void Awake()
    {
        block = new MaterialPropertyBlock();
    }

    // ---------- DreamCore Renderer Feature ----------

    public void SetPixelation(float value)
    {
        DreamcoreRenderFeature.RuntimeValues.pixelation = value;
    }

    public void SetDistortion(float value)
    {
        DreamcoreRenderFeature.RuntimeValues.distortion = value;
    }

    public void SetAberration(float value)
    {
        DreamcoreRenderFeature.RuntimeValues.aberration = value;
    }

    public void SetNoiseStrength(float value)
    {
        DreamcoreRenderFeature.RuntimeValues.noiseStrength = value;
    }

    public void SetLensCurvature(float value)
    {
        DreamcoreRenderFeature.RuntimeValues.lensCurvature = value;
    }

    // ---------- Bloom Renderer Feature ----------

    public void SetBloomIntensity(float value)
    {
        if (DreamyBloomFeature.Instance != null)
        {
            DreamyBloomFeature.Instance.settings.minIntensity = value * 0.3f;
            DreamyBloomFeature.Instance.settings.maxIntensity = value;
        }
    }

    public void SetBloomThreshold(float value)
    {
        if (DreamyBloomFeature.Instance != null)
            DreamyBloomFeature.Instance.settings.threshold = value;
    }

    public void SetBloomGlowSpeed(float value)
    {
        if (DreamyBloomFeature.Instance != null)
            DreamyBloomFeature.Instance.settings.glowSpeed = value;
    }

    public void SetBloomBlurSize(float value)
    {
        if (DreamyBloomFeature.Instance != null)
            DreamyBloomFeature.Instance.settings.blurSize = value;
    }

    public void SetBloomTint(Color color)
    {
        if (DreamyBloomFeature.Instance != null)
            DreamyBloomFeature.Instance.settings.bloomTint = color;
    }

    // ---------- DreamNoiseHX_Lit.shader / Object Material ----------

    public void SetDisplaceAmount(float value)
    {
        SetRendererFloat("_DisplaceAmount", value);
    }

    public void SetNoiseScale(float value)
    {
        SetRendererFloat("_NoiseScale", value);
    }

    public void SetCollapseAmount(float value)
    {
        SetRendererFloat("_CollapseAmount", value);
    }

    public void SetTopBias(float value)
    {
        SetRendererFloat("_TopBias", value);
    }

    public void SetHeightFalloff(float value)
    {
        SetRendererFloat("_HeightFalloff", value);
    }

    public void SetAmbientStrength(float value)
    {
        SetRendererFloat("_AmbientStrength", value);
    }

    private void SetRendererFloat(string propertyName, float value)
    {
        if (targetRenderers == null) return;
        foreach (Renderer r in targetRenderers)
        {
            if (r == null) continue;
            r.GetPropertyBlock(block);
            block.SetFloat(propertyName, value);
            r.SetPropertyBlock(block);
        }
    }
}