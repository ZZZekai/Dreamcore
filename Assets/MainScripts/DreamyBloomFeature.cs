using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DreamyBloomFeature : ScriptableRendererFeature
{
    public static DreamyBloomFeature Instance;

    [System.Serializable]
    public class DreamyBloomSettings
    {
        public Shader shader;

        [Range(0f, 5f)]
        public float threshold = 0.8f;

        [Range(0f, 10f)]
        public float minIntensity = 0.5f;

        [Range(0f, 10f)]
        public float maxIntensity = 5.0f;

        [Range(0f, 10f)]
        public float glowSpeed = 2.0f;

        [Range(0.1f, 10f)]
        public float blurSize = 2.0f;

        public Color bloomTint = Color.white;
    }

    public DreamyBloomSettings settings = new DreamyBloomSettings();

    private Material bloomMaterial;
    private Material blurHorizontalMaterial;
    private Material blurVerticalMaterial;

    private DreamyBloomPass pass;

    public override void Create()
    {
        Instance = this;

        if (settings.shader == null)
        {
            return;
        }

        bloomMaterial = CoreUtils.CreateEngineMaterial(settings.shader);
        blurHorizontalMaterial = CoreUtils.CreateEngineMaterial(settings.shader);
        blurVerticalMaterial = CoreUtils.CreateEngineMaterial(settings.shader);

        pass = new DreamyBloomPass(
            bloomMaterial,
            blurHorizontalMaterial,
            blurVerticalMaterial,
            settings
        );

        pass.renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
    }

    public override void AddRenderPasses(
        ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (pass == null)
        {
            return;
        }

        if (renderingData.cameraData.cameraType != CameraType.Game)
        {
            return;
        }

        renderer.EnqueuePass(pass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(bloomMaterial);
        CoreUtils.Destroy(blurHorizontalMaterial);
        CoreUtils.Destroy(blurVerticalMaterial);
    }
}