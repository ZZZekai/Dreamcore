using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenu("Custom/Dreamcore Effect")]
public class DreamcoreVolume : VolumeComponent, IPostProcessComponent
{
    [Tooltip("Global switch for the effect.")]
    public BoolParameter enableEffect = new BoolParameter(false);

    [Tooltip("Intensity of the pixelation/mosaic effect.")]
    public ClampedFloatParameter pixelation = new ClampedFloatParameter(0f, 0f, 1f);

    [Tooltip("Intensity of the screen/space distortion.")]
    public ClampedFloatParameter distortion = new ClampedFloatParameter(0f, 0f, 1f);

    [Tooltip("Intensity of the red/cyan chromatic aberration.")]
    public ClampedFloatParameter aberration = new ClampedFloatParameter(0f, 0f, 1f);

    [Tooltip("Strength of the analog static/snow noise.")]
    public ClampedFloatParameter noiseStrength = new ClampedFloatParameter(0f, 0f, 1f);

    // --- New Feature: Fisheye / Barrel Distortion ---
    [Tooltip("Curvature of the retro CRT monitor lens (0 = Flat, 1 = Strongly Convex).")]
    public ClampedFloatParameter lensCurvature = new ClampedFloatParameter(0f, 0f, 1f);

    [Tooltip("Color of the environmental tint filter.")]
    public ColorParameter tintColor = new ColorParameter(Color.white);

    [Tooltip("Blend weight of the tint color.")]
    public ClampedFloatParameter tintStrength = new ClampedFloatParameter(0f, 0f, 1f);

    // [Core Fix: Multi-condition bypass to eliminate silent culling]
    public bool IsActive() => enableEffect.value ||
                              pixelation.value > 0f ||
                              distortion.value > 0f ||
                              aberration.value > 0f ||
                              lensCurvature.value > 0f ||
                              tintStrength.value > 0f;

    public bool IsTileCompatible() => false;
}