using UnityEngine;

public class MaskController : MonoBehaviour
{
    public Material maskMaterial;

    [Header("Mask Shape")]
    public float radius = 0.48f;
    public float softness = 0.04f;

    [Header("Edge Distortion")]
    public float edgeDistortion = 0.015f;
    public float distortionScale = 12f;
    public float distortionSpeed = 0.4f;

    void Start()
    {
        ApplySettings();
    }

    void Update()
    {
        ApplySettings();
    }

    void ApplySettings()
    {
        if (maskMaterial == null)
        {
            return;
        }

        maskMaterial.SetFloat("_Radius", radius);
        maskMaterial.SetFloat("_Softness", softness);
        maskMaterial.SetFloat("_EdgeDistortion", edgeDistortion);
        maskMaterial.SetFloat("_DistortionScale", distortionScale);
        maskMaterial.SetFloat("_DistortionSpeed", distortionSpeed);
    }
}