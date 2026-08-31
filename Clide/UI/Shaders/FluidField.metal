// Ported from clide.dev's own WebGL hero shader (site.js, FLUID_FRAG) —
// same simplex-noise domain-warp math, same colour-mix structure, same
// light/vignette/grain terms. Deliberately dropped: the two-pass GPU flow-map
// simulation that lets the web version distort around the mouse cursor —
// wiring pointer position into a SwiftUI colorEffect risks fighting hit
// testing for real buttons, which is not a tradeoff worth making for a
// decorative background. Everything else — the noise field itself, the five
// -stop colour blend, the static light glow, vignette, grain — is the same
// math as the site, not a lookalike invented from scratch.
//
// `[[ stitchable ]]` is what makes this callable from SwiftUI's
// `ShaderLibrary` / `.colorEffect(_:)` (available exactly at this project's
// deployment target, macOS 14 / iOS 17, no availability gate needed).
#include <metal_stdlib>
using namespace metal;

static float3 mod289v3(float3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
static float4 mod289v4(float4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
static float4 permute(float4 x) { return mod289v4(((x * 34.0) + 1.0) * x); }
static float4 taylorInvSqrt(float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

// Ashima Arts' classic 3D simplex noise — identical to the GLSL original.
static float snoise(float3 v) {
    const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);
    const float4 D = float4(0.0, 0.5, 1.0, 2.0);

    float3 i = floor(v + dot(v, C.yyy));
    float3 x0 = v - i + dot(i, C.xxx);

    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);

    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy;
    float3 x3 = x0 - D.yyy;

    i = mod289v3(i);
    float4 p = permute(permute(permute(
        i.z + float4(0.0, i1.z, i2.z, 1.0))
        + i.y + float4(0.0, i1.y, i2.y, 1.0))
        + i.x + float4(0.0, i1.x, i2.x, 1.0));

    float n_ = 0.142857142857;
    float3 ns = n_ * D.wyz - D.xzx;

    float4 j = p - 49.0 * floor(p * ns.z * ns.z);
    float4 x_ = floor(j * ns.z);
    float4 y_ = floor(j - 7.0 * x_);

    float4 x = x_ * ns.x + ns.yyyy;
    float4 y = y_ * ns.x + ns.yyyy;
    float4 h = 1.0 - abs(x) - abs(y);

    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);

    float4 s0 = floor(b0) * 2.0 + 1.0;
    float4 s1 = floor(b1) * 2.0 + 1.0;
    float4 sh = -step(h, float4(0.0));

    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    float3 p0 = float3(a0.xy, h.x);
    float3 p1 = float3(a0.zw, h.y);
    float3 p2 = float3(a1.xy, h.z);
    float3 p3 = float3(a1.zw, h.w);

    float4 norm = taylorInvSqrt(float4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;

    float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    return 42.0 * dot(m * m, float4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

static float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Single-octave fbm, matching the site's own (it only loops once too).
static float fbm(float3 p) {
    return 0.6 * snoise(p);
}

static float fluidNoise(float2 uv, float t) {
    float n1 = fbm(float3(uv * 0.6, t * 0.06));
    float n2 = fbm(float3(uv * 0.6 + 5.2, t * 0.06 + 1.3));
    float2 w1 = float2(n1, n2) * 0.6;

    float n3 = fbm(float3((uv + w1) * 0.7 + 1.7, t * 0.05 + 3.1));
    float n4 = fbm(float3((uv + w1) * 0.7 + 9.2, t * 0.05 + 5.7));
    float2 w2 = float2(n3, n4) * 0.5;

    return fbm(float3((uv + w1 + w2) * 0.5, t * 0.04));
}

static float2 curlish(float2 uv, float t) {
    float eps = 0.02;
    float n = snoise(float3(uv * 0.8, t));
    float nx = snoise(float3((uv + float2(eps, 0.0)) * 0.8, t));
    float ny = snoise(float3((uv + float2(0.0, eps)) * 0.8, t));
    return float2(-(ny - n) / eps, (nx - n) / eps) * 0.003;
}

/// Arguments mirror the site's uniforms, minus the mouse/flowmap terms.
/// `resolution` is the view size in points; `scale`/`offset` reposition the
/// noise field the same way the site's own scale/offsetX/offsetY do.
[[ stitchable ]] half4 fluidField(
    float2 position,
    half4 color,
    float time,
    float2 resolution,
    float scale,
    float2 offset,
    float grain,
    half4 c1in, half4 c2in, half4 c3in, half4 c4in, half4 c5in,
    half4 glowColor1in, half4 glowColor2in, half4 glowColor3in,
    float glowIntensity,
    float2 lightPos, float lightCore, float lightHalo,
    float vignetteAmount
) {
    float3 c1 = float3(c1in.rgb), c2 = float3(c2in.rgb), c3 = float3(c3in.rgb);
    float3 c4 = float3(c4in.rgb), c5 = float3(c5in.rgb);
    float3 glowColor1 = float3(glowColor1in.rgb);
    float3 glowColor2 = float3(glowColor2in.rgb);
    float3 glowColor3 = float3(glowColor3in.rgb);

    float aspect = resolution.x / resolution.y;
    float2 uv = position / resolution;
    float2 suv = float2(uv.x * aspect, uv.y) * scale + offset;
    float t = time;

    float2 curl = curlish(suv, t * 0.04);
    float2 uvD = suv + curl * 12.0;
    float f = fluidNoise(uvD, t);
    float swirl = snoise(float3(uvD * 0.8 + f * 1.5, t * 0.035)) * 0.5 + 0.5;
    float n = f * 0.5 + 0.5;

    float3 col = mix(c1, c2, smoothstep(0.2, 0.5, n));
    col = mix(col, c3, smoothstep(0.35, 0.65, n + swirl * 0.25));
    col = mix(col, c4, smoothstep(0.6, 0.85, swirl) * 0.55);
    col = mix(col, c5, smoothstep(0.5, 0.8, n * swirl) * 0.35);

    // The site's "glow" term responds to mouse-driven flow influence, which
    // this static version doesn't have — a gentle noise-driven flicker
    // stands in so the glow colours still show up in the field.
    float glowNoise = snoise(float3(uvD * 1.5, t * 0.08)) * 0.5 + 0.5;
    float3 glowMix = mix(glowColor3, glowColor2, glowNoise);
    glowMix = mix(glowMix, glowColor1, glowNoise * swirl);
    col = mix(col, glowMix, glowNoise * 0.15 * glowIntensity);

    if (grain > 0.0) {
        float2 gp = floor(position / 5.0);
        float gr = hash(gp) * 2.0 - 1.0;
        col += gr * grain;
    }

    float ld = length((uv - lightPos) * float2(aspect, 1.0));
    float core = exp(-ld * ld * 4.5);
    float halo = exp(-ld * 1.8);
    col += float3(1.0, 0.98, 0.95) * core * lightCore + float3(0.8, 0.95, 1.0) * halo * lightHalo;

    float vig = 1.0 - smoothstep(0.35, 0.75, length(uv - 0.5));
    col = mix(mix(col, float3(1.0), vignetteAmount), col, vig);

    return half4(half3(col), color.a);
}
