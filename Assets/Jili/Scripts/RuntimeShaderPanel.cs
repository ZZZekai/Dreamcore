using UnityEngine;
using UnityEngine.Rendering;

public class DreamShaderRuntimeController : MonoBehaviour
{
    [Header("Dreamcore Post Processing")]
    public Volume dreamcoreVolume;
    private DreamcoreVolume dreamcore;

    [Header("Noise / Collapse Object Renderers")]
    public Renderer[] targetRenderers;

    private MaterialPropertyBlock block;

    void Start()
    {
        block = new MaterialPropertyBlock();

        if (dreamcoreVolume != null)
        {
            dreamcoreVolume.profile.TryGet(out dreamcore);

            if (dreamcore != null)
            {
                dreamcore.enableEffect.overrideState = true;
                dreamcore.enableEffect.value = true;

                dreamcore.pixelation.overrideState = true;
                dreamcore.distortion.overrideState = true;
                dreamcore.aberration.overrideState = true;
                dreamcore.noiseStrength.overrideState = true;
                dreamcore.lensCurvature.overrideState = true;
                dreamcore.tintColor.overrideState = true;
                dreamcore.tintStrength.overrideState = true;
            }
        }
    }

    // ---------- DreamcoreCore.shader / DreamcoreVolume ----------

    public void SetPixelation(float value)
    {
        if (dreamcore != null)
            dreamcore.pixelation.value = value;
    }

    public void SetDistortion(float value)
    {
        if (dreamcore != null)
            dreamcore.distortion.value = value;
    }

    public void SetAberration(float value)
    {
        if (dreamcore != null)
            dreamcore.aberration.value = value;
    }

    public void SetNoiseStrength(float value)
    {
        if (dreamcore != null)
            dreamcore.noiseStrength.value = value;
    }

    public void SetLensCurvature(float value)
    {
        if (dreamcore != null)
            dreamcore.lensCurvature.value = value;
    }

    public void SetTintStrength(float value)
    {
        if (dreamcore != null)
            dreamcore.tintStrength.value = value;
    }

    public void SetTintColor(Color color)
    {
        if (dreamcore != null)
            dreamcore.tintColor.value = color;
    }

    // ---------- DreamNoiseHX_Lit.shader ----------

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
        if (targetRenderers == null)
            return;

        foreach (Renderer r in targetRenderers)
        {
            if (r == null)
                continue;

            r.GetPropertyBlock(block);
            block.SetFloat(propertyName, value);
            r.SetPropertyBlock(block);
        }
    }
}