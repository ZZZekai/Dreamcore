using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;

public class DreamcoreRenderFeature : ScriptableRendererFeature
{
    public static class RuntimeValues
    {
        public static float pixelation = 0.0f;
        public static float distortion = 0.0f;
        public static float aberration = 0.0f;
        public static float noiseStrength = 0.0f;
        public static float lensCurvature = 0.0f;
    }

    class DreamcorePass : ScriptableRenderPass
    {
        private Material m_Material;
        private Material m_CopyMaterial;
        private Settings settings;

        public DreamcorePass(Material material, Material copyMaterial, Settings settings)
        {
            m_Material = material;
            m_CopyMaterial = copyMaterial;
            this.settings = settings;

            renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        }

        class PassData
        {
            public Material material;
            public TextureHandle srcTexture;

            public float pixelation;
            public float distortion;
            public float aberration;
            public float noiseStrength;
            public float lensCurvature;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalCameraData cameraData = frameData.Get<UniversalCameraData>();

            if (cameraData.cameraType == CameraType.Preview)
                return;

            if (m_Material == null || m_CopyMaterial == null)
                return;

            TextureHandle activeColorTex = resourceData.activeColorTexture;

            if (!activeColorTex.IsValid())
                return;

            var desc = renderGraph.GetTextureDesc(activeColorTex);
            desc.name = "DreamcoreTemp";
            desc.clearBuffer = false;
            desc.depthBufferBits = 0;

            TextureHandle tempDst = renderGraph.CreateTexture(desc);

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                "Dreamcore Effect Pass",
                out var passData))
            {
                passData.material = m_Material;
                passData.srcTexture = activeColorTex;

                if (Application.isPlaying)
                {
                    passData.pixelation = RuntimeValues.pixelation;
                    passData.distortion = RuntimeValues.distortion;
                    passData.aberration = RuntimeValues.aberration;
                    passData.noiseStrength = RuntimeValues.noiseStrength;
                    passData.lensCurvature = RuntimeValues.lensCurvature;
                }
                else
                {
                    passData.pixelation = settings.pixelation;
                    passData.distortion = settings.distortion;
                    passData.aberration = settings.aberration;
                    passData.noiseStrength = settings.noiseStrength;
                    passData.lensCurvature = settings.lensCurvature;
                }

                builder.UseTexture(activeColorTex, AccessFlags.Read);
                builder.SetRenderAttachment(tempDst, 0, AccessFlags.Write);
                builder.AllowGlobalStateModification(true);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    data.material.SetFloat("_Pixelation", data.pixelation);
                    data.material.SetFloat("_Distortion", data.distortion);
                    data.material.SetFloat("_Aberration", data.aberration);
                    data.material.SetFloat("_NoiseStrength", data.noiseStrength);
                    data.material.SetFloat("_LensCurvature", data.lensCurvature);

                    context.cmd.SetGlobalTexture("_MainTex", data.srcTexture);
                    context.cmd.SetGlobalTexture("_BlitTexture", data.srcTexture);

                    Blitter.BlitTexture(
                        context.cmd,
                        data.srcTexture,
                        new Vector4(1, 1, 0, 0),
                        data.material,
                        0
                    );
                });
            }

            using (var builder = renderGraph.AddRasterRenderPass<PassData>(
                "Dreamcore Copy Back",
                out var copyPassData))
            {
                copyPassData.material = m_CopyMaterial;
                copyPassData.srcTexture = tempDst;

                builder.UseTexture(tempDst, AccessFlags.Read);
                builder.SetRenderAttachment(activeColorTex, 0, AccessFlags.Write);
                builder.AllowGlobalStateModification(true);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    context.cmd.SetGlobalTexture("_MainTex", data.srcTexture);
                    context.cmd.SetGlobalTexture("_BlitTexture", data.srcTexture);

                    Blitter.BlitTexture(
                        context.cmd,
                        data.srcTexture,
                        new Vector4(1, 1, 0, 0),
                        data.material,
                        0
                    );
                });
            }
        }
    }

    [System.Serializable]
    public class Settings
    {
        public Shader dreamcoreShader;

        [Range(0f, 1f)] public float pixelation = 0.0f;
        [Range(0f, 1f)] public float distortion = 0.0f;
        [Range(0f, 1f)] public float aberration = 0.0f;
        [Range(0f, 1f)] public float noiseStrength = 0.0f;
        [Range(0f, 1f)] public float lensCurvature = 0.0f;
    }

    public Settings settings = new Settings();

    private Material m_Material;
    private Material m_CopyMaterial;
    private DreamcorePass m_ScriptablePass;

    public override void Create()
    {
        if (settings.dreamcoreShader == null)
            return;

        m_Material = CoreUtils.CreateEngineMaterial(settings.dreamcoreShader);
        m_CopyMaterial = CoreUtils.CreateEngineMaterial("Hidden/Universal Render Pipeline/Blit");

        m_ScriptablePass = new DreamcorePass(
            m_Material,
            m_CopyMaterial,
            settings
        );
    }

    public override void AddRenderPasses(
        ScriptableRenderer renderer,
        ref RenderingData renderingData)
    {
        if (m_ScriptablePass == null)
            return;

        renderer.EnqueuePass(m_ScriptablePass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(m_Material);
        CoreUtils.Destroy(m_CopyMaterial);
    }
}