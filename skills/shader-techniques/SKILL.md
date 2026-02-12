# Shader Techniques Skill

A collection of shader programming techniques curated from XorDev (@XorDev), a graphics programmer with 14+ years of shader experience. These techniques are practical, efficient, and production-ready.

**Source:** [XorDev's Twitter Thread](https://x.com/XorDev/status/2021356467115462961) & [GM Shaders Tutorials](https://mini.gmshaders.com/)

---

## Table of Contents

1. [Turbulence (Fluid Simulation)](#1-turbulence-fluid-simulation)
2. [Signed Distance Fields (SDFs)](#2-signed-distance-fields-sdfs)
3. [Raymarching](#3-raymarching)
4. [Volumetric Rendering](#4-volumetric-rendering)
5. [Tonemapping (HDR)](#5-tonemapping-hdr)
6. [Dot Noise (Cheap 3D Noise)](#6-dot-noise-cheap-3d-noise)
7. [Mix Function Tricks](#7-mix-function-tricks)
8. [3D Rotation](#8-3d-rotation)
9. [fwidth() Outlines](#9-fwidth-outlines)
10. [Common Shader Mistakes](#10-common-shader-mistakes)
11. [Tiny Shader Techniques (Code Golf)](#11-tiny-shader-techniques-code-golf)
12. [Resources](#12-resources)

---

## 1. Turbulence (Fluid Simulation)

Create fluid-like motion for water, fire, smoke, fog, and magic effects without expensive Navier-Stokes simulations.

### Core Concept
Layer sine waves with rotation to create swirling, turbulent motion.

### Basic Implementation

```glsl
// Turbulence parameters
#define TURB_NUM 10.0     // Number of turbulence waves
#define TURB_AMP 0.7      // Wave amplitude
#define TURB_SPEED 0.3    // Animation speed
#define TURB_FREQ 2.0     // Starting frequency
#define TURB_EXP 1.4      // Frequency multiplier per octave

vec2 turbulence(vec2 pos, float time) {
    float freq = TURB_FREQ;
    
    // Rotation matrix (angle ~53°, avoids axis alignment)
    mat2 rot = mat2(0.6, -0.8, 0.8, 0.6);
    
    for(float i = 0.0; i < TURB_NUM; i++) {
        // Scroll along rotated y coordinate
        float phase = freq * (pos * rot).y + TURB_SPEED * time + i;
        
        // Add perpendicular sine wave offset
        pos += TURB_AMP * rot[0] * sin(phase) / freq;
        
        // Rotate and scale for next octave
        rot *= mat2(0.6, -0.8, 0.8, 0.6);
        freq *= TURB_EXP;
    }
    return pos;
}
```

### Use Cases
- **Water ripples**: Low amplitude, slow speed
- **Fire/flames**: Add upward scrolling, stretch vertically
- **Smoke/fog**: Higher octaves, slower movement
- **Magic effects**: High amplitude, vibrant colors

**Demo:** [ShaderToy - Turbulence](https://www.shadertoy.com/view/WclSWn)

---

## 2. Signed Distance Fields (SDFs)

Functions that return the distance to a shape's surface (negative if inside).

### Basic Shapes

```glsl
// Circle/Sphere
float sdCircle(vec2 p, float r) {
    return length(p) - r;
}

// Box
float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}
```

### SDF Operations

```glsl
// Union (combine shapes)
float union_dist = min(shape1, shape2);

// Subtraction (cut holes)
float sub_dist = max(shape1, -shape2);

// Intersection (overlap)
float intersect_dist = max(shape1, shape2);

// Smooth union (blending)
float smin(float a, float b, float k) {
    float r = exp2(-a/k) + exp2(-b/k);
    return -k * log2(r);
}
```

### SDF Modifications

```glsl
// Rounded edges
float rounded = shape_dist - thickness;

// Hollow/outline
float hollow = abs(shape_dist) - thickness;

// Onion layers
float layered = abs(mod(shape_dist + spacing/2.0, spacing) - spacing/2.0) - thickness;

// Mirror axis
pos.y = abs(pos.y);

// Infinite tiling
vec2 repeat_pos = mod(pos + spacing/2.0, spacing) - spacing/2.0;
```

### Anti-aliasing with SDFs

```glsl
// Smooth edge (1 pixel AA)
float aa = fwidth(dist);
float alpha = smoothstep(aa, -aa, dist);
```

**Reference:** [Inigo Quilez - 2D SDF](https://iquilezles.org/articles/distfunctions2d) | [3D SDF](https://iquilezles.org/articles/distfunctions)

---

## 3. Raymarching

Render 3D scenes using distance fields - simpler than raytracing, with built-in soft shadows and glow.

### Basic Raymarcher

```glsl
#define MAX_STEPS 100
#define MAX_DIST 50.0
#define EPSILON 0.01

vec4 raymarch(vec3 origin, vec3 dir) {
    float d = 0.0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        vec3 p = origin + dir * d;
        float step_dist = scene_sdf(p);  // Your distance field
        d += step_dist;
        
        if(step_dist < EPSILON || d > MAX_DIST) break;
    }
    
    return vec4(origin + dir * d, d);
}
```

### Ray Direction

```glsl
// Calculate ray direction from screen coordinates
vec3 getRayDir(vec2 uv, vec2 resolution) {
    return normalize(vec3(uv - 0.5 * resolution, resolution.y));
}
```

### Surface Normal (for lighting)

```glsl
vec3 getNormal(vec3 p) {
    vec2 e = vec2(0.001, 0.0);
    return normalize(vec3(
        scene_sdf(p + e.xyy) - scene_sdf(p - e.xyy),
        scene_sdf(p + e.yxy) - scene_sdf(p - e.yxy),
        scene_sdf(p + e.yyx) - scene_sdf(p - e.yyx)
    ));
}
```

**Demo:** [ShaderToy - Raymarching Demo](https://www.shadertoy.com/view/7ldfzj)

---

## 4. Volumetric Rendering

Render clouds, fire, smoke, and light rays by accumulating samples along a ray.

### Density Field (instead of SDF)

```glsl
float volume(vec3 p) {
    // Tunnel with noise
    return 3.5 - 0.25 * length(p.xy) + 0.5 * dot(sin(p), cos(p * 0.618).yzx);
}
```

### Glow Accumulation

```glsl
#define BRIGHTNESS 0.002

vec3 col = vec3(0.0);

for(float i = 0.0; i < STEPS; i++) {
    float vol = volume(pos);
    pos += dir * vol;
    
    // Accumulate glow (color / distance)
    col += vec3(3.0, 2.0, 1.0) / vol;
}

// Tonemap result
col = tanh(BRIGHTNESS * col);
```

### Alpha Blending (for clouds/smoke)

```glsl
vec4 color = vec4(0.0);

for(...) {
    float density = volume(pos);
    vec3 sample_rgb = getColor(pos);
    float sample_alpha = density * step_size;
    
    // Alpha blend
    color = mix(color, vec4(sample_rgb, 1.0), (1.0 - color.a) * sample_alpha);
    
    // Early exit when opaque
    if(color.a > 0.998) break;
}
```

**Demo:** [ShaderToy - Clouds](https://www.shadertoy.com/view/WcdSz2)

---

## 5. Tonemapping (HDR)

Map HDR colors to displayable range while preserving color ratios.

### Common Tonemapping Functions

```glsl
// ACES Filmic (sharp, punchy)
vec3 tonemap_ACES(vec3 x) {
    const float a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
    return (x * (a * x + b)) / (x * (c * x + d) + e);
}

// Uncharted 2 (soft, cinematic)
vec3 tonemap_Uncharted2(vec3 x) {
    x *= 16.0;
    const float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F)) - E/F;
}

// Unreal (bright, smooth)
vec3 tonemap_Unreal(vec3 x) {
    return x / (x + 0.155) * 1.019;
}

// Quick tanh (similar to ACES)
vec3 tonemap_tanh(vec3 x) {
    x = clamp(x, -40.0, 40.0);
    vec3 exp_neg_2x = exp(-2.0 * x);
    return -1.0 + 2.0 / (1.0 + exp_neg_2x);
}
```

### When to Use
- Sun/light sources with brightness > 1.0
- Bloom/glow post-processing
- Any additive blending that exceeds 1.0

---

## 6. Dot Noise (Cheap 3D Noise)

A fast alternative to Perlin/Simplex noise using modified gyroids.

### Implementation

```glsl
float dot_noise(vec3 p) {
    const float PHI = 1.618033988;  // Golden ratio
    
    // Golden angle rotation matrix
    const mat3 GOLD = mat3(
        -0.571464913, +0.814921382, +0.096597072,
        -0.278044873, -0.303026659, +0.911518454,
        +0.772087367, +0.494042493, +0.399753815
    );
    
    // Gyroid with irrational orientations
    return dot(cos(GOLD * p), sin(PHI * p * GOLD));
    // Returns [-3, +3]
}
```

### Use Cases
- Volumetric cloud detail
- Fast procedural textures
- Any place you'd use 3D Simplex but need speed

**Demo:** [ShaderToy - Dot Noise](https://www.shadertoy.com/view/wfsyRX)

---

## 7. Mix Function Tricks

Beyond basic color blending.

### Saturation Control

```glsl
float gray = dot(col.rgb, vec3(0.2126, 0.7152, 0.0722));
col = mix(vec3(gray), col, SATURATION);  // >1.0 boosts saturation
```

### Contrast & Brightness

```glsl
col = mix(vec3(BRIGHTNESS), col, CONTRAST);
```

### Radial Blur / Chromatic Aberration

```glsl
vec3 col = vec3(0.0);
for(float i = 0.0; i < 1.0; i += 0.05) {
    vec2 tuv = mix(uv, vec2(0.5), i * intensity);
    col += texture(tex, tuv).rgb * 0.05;
}
```

### Remap Function

```glsl
// Map x from [a,b] to [c,d]
float remap(float a, float b, float c, float d, float x) {
    return (x - a) / (b - a) * (d - c) + c;
}
```

---

## 8. 3D Rotation

Multiple approaches to rotating vectors in 3D space.

### Euler Angles (Roll, Pitch, Yaw)

Simple 2D rotations applied to each axis. Easy to understand but can cause gimbal lock.

```glsl
// 2D rotation helper
mat2 rotate2D(float angle) {
    return mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
}

// Apply Euler rotations (order matters!)
void eulerRotate(inout vec3 v, float roll, float pitch, float yaw) {
    v.yz = rotate2D(roll) * v.yz;   // Roll (x-axis)
    v.xz = rotate2D(pitch) * v.xz;  // Pitch (y-axis)
    v.xy = rotate2D(yaw) * v.xy;    // Yaw (z-axis)
}
```

### Axis-Angle Rotation

Rotate around any arbitrary axis. More efficient and avoids gimbal lock.

```glsl
// Rotate vector around arbitrary axis by angle (axis must be normalized)
vec3 rotateAxisAngle(vec3 v, vec3 axis, float angle) {
    return mix(dot(v, axis) * axis, v, cos(angle)) 
         + sin(angle) * cross(v, axis);
}

// Compact 3D rotation matrix version
mat3 rotate3D(float angle, vec3 axis) {
    vec3 a = normalize(axis);
    float s = sin(angle), c = cos(angle), r = 1.0 - c;
    return mat3(
        a.x*a.x*r + c,     a.y*a.x*r + a.z*s, a.z*a.x*r - a.y*s,
        a.x*a.y*r - a.z*s, a.y*a.y*r + c,     a.z*a.y*r + a.x*s,
        a.x*a.z*r + a.y*s, a.y*a.z*r - a.x*s, a.z*a.z*r + c
    );
}
```

### When to Use What

| Method | Pros | Cons |
|--------|------|------|
| Euler Angles | Simple, intuitive | Gimbal lock, order-dependent |
| Axis-Angle | Efficient, no gimbal lock | Harder to visualize |
| Quaternions | Best for interpolation | Complex to understand |

**Tutorial:** [mini.gmshaders.com/p/3d-rotation](https://mini.gmshaders.com/p/3d-rotation)

---

## 9. fwidth() Outlines

Add outlines to any procedural shape using screen-space derivatives.

### The Technique

`fwidth()` returns the rate of change of a value across adjacent pixels - perfect for detecting edges.

```glsl
// Add outline to any SDF or procedural pattern
float addOutline(float value, float thickness) {
    float edge = fwidth(value);
    // Creates outline where value changes rapidly
    return smoothstep(edge * thickness, 0.0, abs(value));
}

// Example: outlined procedural circles
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    
    // Procedural pattern (e.g., distance to grid)
    float pattern = sin(uv.x * 20.0) * sin(uv.y * 20.0);
    
    // Outline using fwidth
    float outline = fwidth(pattern) * 2.0;
    float edge = smoothstep(outline, 0.0, abs(pattern));
    
    fragColor = vec4(vec3(edge), 1.0);
}
```

### Anti-aliased SDF Edges

```glsl
// Smooth, anti-aliased edges for any SDF
float sdfEdge(float dist) {
    float aa = fwidth(dist);
    return smoothstep(aa, -aa, dist);
}

// Outlined SDF shape
vec3 outlinedShape(float dist, vec3 fillColor, vec3 outlineColor, float outlineWidth) {
    float aa = fwidth(dist);
    float fill = smoothstep(aa, -aa, dist);
    float outline = smoothstep(aa, -aa, abs(dist) - outlineWidth);
    return mix(fillColor * fill, outlineColor, outline * (1.0 - fill));
}
```

### Use Cases
- Procedural outlines without textures
- Toon/cel shading edges
- UI elements with dynamic outlines
- Debug visualization

---

## 10. Common Shader Mistakes

A checklist of common pitfalls and how to avoid them.

### NaN (Not-a-Number) Errors

NaN values propagate through all operations and cause black pixels.

```glsl
// DANGER: These can produce NaN
sqrt(-1.0)           // Negative sqrt
log(-1.0)            // Negative log
pow(-1.0, 0.5)       // Negative base with fractional exponent
0.0 / 0.0            // Zero divided by zero
acos(1.5)            // Input outside [-1, 1]

// SAFE: Prevent NaN
sqrt(max(x, 0.0))    // Clamp to non-negative
log(max(x, 1e-10))   // Clamp to positive
pow(abs(x), y)       // Use absolute value
x / max(y, 1e-10)    // Prevent zero division
acos(clamp(x, -1.0, 1.0))  // Clamp to valid range
```

### Precision Issues

```glsl
// Mobile devices often default to mediump
// Use appropriate precision for the job:
lowp vec3 color;     // Colors (0-1 range)
mediump vec2 uv;     // Texture coordinates
highp vec3 position; // World positions
highp float time;    // Time uniforms

// Time overflow after hours of runtime
float safeTime = mod(iTime, 600.0);  // Loop every 10 minutes
```

### Texture Coordinate Gotchas

```glsl
// Don't assume 0-1 range (texture atlases!)
// Use provided UV bounds when available

// Remap to [0, 1] range
vec2 normalizeUV(vec2 coord, vec4 uvBounds) {
    return (coord - uvBounds.xy) / uvBounds.zw;
}

// Remap from [0, 1] range back to atlas coords
vec2 unnormalizeUV(vec2 coord, vec4 uvBounds) {
    return coord * uvBounds.zw + uvBounds.xy;
}
```

### Mipmap Artifacts

```glsl
// 2x2 block artifacts from UV discontinuities
// Solution 1: Calculate derivatives manually
vec4 textureSafe(sampler2D tex, vec2 uv) {
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    return textureGrad(tex, uv, dx, dy);
}

// Solution 2: Use textureLod for consistent LOD
vec4 col = textureLod(tex, uv, 0.0);
```

### Quick Checklist

- ✅ Prevent negative sqrt/log inputs
- ✅ Guard against division by zero
- ✅ Clamp asin/acos inputs to [-1, 1]
- ✅ Test on mobile (lower precision)
- ✅ Loop time variables to prevent overflow
- ✅ Handle gamma correction properly
- ✅ Don't assume normalized UV coordinates
- ✅ Add anti-aliasing to hard edges

**Tutorial:** [mini.gmshaders.com/p/mistakes](https://mini.gmshaders.com/p/mistakes)

---

## 11. Tiny Shader Techniques (Code Golf)

Tips for writing ultra-compact shaders (#つぶやきGLSL style).

### Common Abbreviations

```glsl
// Standard twigl.app / Shadertoy shorthand
#define FC gl_FragCoord
#define r iResolution
#define t iTime
#define o fragColor

// Normalize coordinates in one line
vec2 p = (FC.xy - r*.5) / r.y;  // Centered, aspect-corrected
```

### Space-Saving Tricks

```glsl
// Combine operations
o += col/++i;           // Increment and divide
for(;i++<N;)           // Loop without initialization

// Use vec4 for RGB+alpha in one
o = vec4(col, 1);

// Swizzle for repetition
p.xy = p.yx;           // Swap x and y
vec3 v = p.xyx;        // Repeat x

// Scientific notation
1e3 = 1000.0
1e-3 = 0.001
5e2 = 500.0

// Implicit type conversion
vec3(1)  // Same as vec3(1.0, 1.0, 1.0)
```

### Compact Patterns

```glsl
// Cheap hash (for noise)
fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5)

// Quick glow accumulation
o += .1 / length(p - center);

// Tanh tonemapping (compact ACES-like)
o = tanh(o);

// Compact raymarching
for(float d, i; i++ < 99.; p += d * ray)
    d = map(p);
```

### Example: Minimal Fire Shader

```glsl
// ~200 chars
void mainImage(out vec4 o, vec2 FC) {
    vec2 p = (FC.xy - iResolution.xy*.5) / iResolution.y;
    for(float i, s = 3.; i++ < 8.; s *= 1.5)
        p += sin(p.yx * s + iTime) / s;
    o = vec4(1, .5, .2, 1) * (1. - length(p));
}
```

**Reference:** [#つぶやきGLSL on Twitter](https://x.com/hashtag/つぶやきGLSL)

---

## 12. Resources

### XorDev Links
- **Website:** [xordev.com](https://www.xordev.com/)
- **Shader Arsenal:** [xordev.com/arsenal](https://www.xordev.com/arsenal) (412+ tiny shaders)
- **Tutorials:** [mini.gmshaders.com](https://mini.gmshaders.com/)
- **Twitter:** [@XorDev](https://x.com/XorDev)
- **GitHub:** [github.com/XorDev](https://github.com/XorDev)

### Key GM Shaders Tutorials
- [3D Rotation](https://mini.gmshaders.com/p/3d-rotation) - Euler Angles & Axis-Angle
- [Common Shader Mistakes](https://mini.gmshaders.com/p/mistakes) - Debugging guide
- [Radiance Cascades](https://mini.gmshaders.com/p/radiance-cascades) - GI technique
- [Design Choices](https://mini.gmshaders.com/p/design-choices) - Visual improvement tips
- [Modeling the World in 280 Chars](https://mini.gmshaders.com/p/modeling-the-world) - Code golf mindset

### Essential References
- **Inigo Quilez (iq):** [iquilezles.org](https://iquilezles.org) - The godfather of SDF techniques
- **ShaderToy:** [shadertoy.com](https://www.shadertoy.com) - Test and share shaders
- **The Book of Shaders:** [thebookofshaders.com](https://thebookofshaders.com) - Beginner-friendly
- **Shadertoy Unofficial:** [shadertoyunofficial.wordpress.com](https://shadertoyunofficial.wordpress.com/2019/01/02/programming-tricks-in-shadertoy-glsl/) - Code golf tricks
- **twigl.app:** [twigl.app](https://twigl.app/) - Tiny shader playground

### Key ShaderToy Demos
- [Turbulence](https://www.shadertoy.com/view/WclSWn)
- [Fire with Turbulence](https://www.shadertoy.com/view/wffXDr)
- [Volumetric Clouds](https://www.shadertoy.com/view/Wf3SWn)
- [Raymarching Burgers](https://www.shadertoy.com/view/WsXSDH)
- [Dot Noise Spiral](https://www.shadertoy.com/view/wfsyRX)
- [Atlantic Ocean](https://x.com/XorDev/status/1922716290545783182) - Compact ocean shader

---

## Quick Reference Card

| Technique | Use Case | Cost |
|-----------|----------|------|
| Turbulence | Fluids, fire, smoke | Low |
| SDF | Vector shapes, raymarching | Low |
| Raymarching | 3D rendering without meshes | Medium |
| Volumetrics | Clouds, fog, light rays | High |
| Tonemapping | HDR → LDR conversion | Very Low |
| Dot Noise | Cheap 3D procedural noise | Very Low |
| 3D Rotation | Camera, object transforms | Very Low |
| fwidth() Outlines | Procedural edges, toon shading | Very Low |
| Code Golf | Demos, twitter shaders | N/A |

---

## Cheat Sheet: Preventing Common Errors

```glsl
// Safe operations
sqrt(max(x, 0.0))           // Prevent negative sqrt
x / max(y, 1e-10)           // Prevent div by zero
acos(clamp(x, -1.0, 1.0))   // Prevent NaN from acos/asin
mod(time, 600.0)            // Prevent time overflow

// Compact helpers
#define S smoothstep
#define T tanh
vec2 p = (FC.xy - r*.5) / r.y;  // Centered UV
```

---

*Last updated: February 2026*
*Curated from XorDev's 14+ years of shader programming experience*
