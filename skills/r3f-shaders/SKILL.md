---
name: r3f-shaders
description: Comprehensive guide for building Three.js / React Three Fiber scenes and WebGL/WebGPU shaders. Use this skill for any R3F scene work -- scaffolding new projects, custom shader materials, post-processing effects (dithering, Moebius outlines, painterly/Kuwahara, halftone), render-target techniques (refraction, caustics, portals), raymarching (SDFs, volumetric clouds, god-rays/volumetric lighting), high-count particle systems (FBO/GPGPU, 100k+), and WebGPU/TSL migration. Trigger this skill whenever the user mentions Three.js, R3F, shaders, GLSL, WGSL, TSL, WebGPU, vertex/fragment shaders, creative coding with 3D on the web, or references Maxime Heckel's work. Also trigger for stylized/non-photorealistic rendering (outlines, dithering, painterly, halftone, ASCII, retro/CRT effects), light effects (refraction, dispersion, chromatic aberration, caustics, Fresnel, god rays), volumetric effects (clouds, smoke, fog), and performance-critical 3D on the web.
---

# R3F / Shaders / WebGPU Skill

This skill distils the entire body of Maxime Heckel's shader and real-time 3D work into an actionable playbook for Three.js / React Three Fiber projects, covering WebGL + GLSL and WebGPU + TSL.

## What this skill helps with

**Scaffolding new R3F projects** with sensible defaults (Vite, drei, postprocessing, leva, WebGPU-ready).

**Building custom shaders** -- custom materials, post-processing passes and effects, raymarched scenes, GPGPU particles.

**Mid-project guidance** -- picking the right technique, diagnosing common issues (shader freezes, wrong colours, performance cliffs), reviewing code against best practices.

**Design-to-effect translation** -- given a reference (a tweet, dribbble, film still), which techniques combine to reproduce it.

## How to use this skill

1. **Read this SKILL.md first** for the overall map and decision-making guidance.
2. **Load the specific reference file** for the technique at hand (see 'Reference files' below).
3. **Use templates/** as a starting point for new projects or new shader types.

## Decision tree: which reference to load

When the task is:

- **'Set up a new R3F project'** -> Use `templates/vite-r3f-starter/`. If the person wants WebGPU, use `templates/vite-r3f-webgpu-starter/`.
- **'Help me write my first shader' / What is a uniform?** -> Load `references/fundamentals.md`.
- **'Build a halftone/Moebius/dithering/painterly/ASCII effect'** -> Load `references/stylized-shaders.md`.
- **'Make this mesh transparent / glass / dispersive'** -> Load `references/light-effects.md`.
- **'Build a portal / mirror / lens'** -> Load `references/light-effects.md` (render targets section).
- **'Build clouds / smoke / volumetric fog'** -> Load `references/raymarching.md`.
- **'Make a fractal / blob / organic shape procedurally'** -> Load `references/raymarching.md` (SDFs section).
- **'Render 100,000+ particles'** -> Load `references/particles-advanced.md`.
- **'Add god rays / volumetric lighting'** -> Load `references/volumetric-lighting.md`.
- **'Port this to WebGPU / How does TSL work?'** -> Load `references/webgpu-tsl.md`.
- **'Add caustics under this glass mesh'** -> Load `references/light-effects.md` (caustics section).

For multi-technique requests (e.g. 'a dreamy cloud scene with god rays'), load multiple references.

## Reference files

| File | Covers |
|---|---|
| references/fundamentals.md | Scene anatomy, vertex + fragment shaders, uniforms/varyings/attributes, noise, particles intro, lamina, post-processing basics, common pitfalls |
| references/light-effects.md | Render targets (FBO), transparency via screen-space UV, refraction, chromatic dispersion, Fresnel, specular/diffuse, caustics, portals, custom post-processing pipelines |
| references/raymarching.md | SDFs, raymarching algorithm, standard + volumetric raymarching, cloud rendering, soft shadows, smoothmin operations, FBM noise |
| references/stylized-shaders.md | Pass vs Effect, Sobel edge detection + Moebius outlines, ordered/blue-noise dithering, colour quantization, Kuwahara painterly filter, halftone, receipt, ASCII, pixel patterns |
| references/particles-advanced.md | FBO/GPGPU particle systems, simulation materials, 100k+ particles, curl noise, morphing between shapes |
| references/volumetric-lighting.md | God rays, volumetric spotlights, screen-to-world reconstruction via depth buffer, shadow-mapped volumetric light |
| references/webgpu-tsl.md | WebGPU renderer, TSL syntax, Node System, positionNode/normalNode/colorNode, compute shaders, GLSL/WGSL migration |

## Templates

| Template | When to use |
|---|---|
| templates/vite-r3f-starter/ | New R3F project, WebGL/GLSL. Vite + React 18 + R3F + drei + postprocessing + leva. |
| templates/vite-r3f-webgpu-starter/ | New R3F project, WebGPU-first with WebGL fallback. Same stack, WebGPURenderer + TSL. |
| templates/custom-shader-material/ | Boilerplate for a custom shaderMaterial with vertex/fragment, uniforms (u_time, u_resolution, u_mouse), hot reloadable. |
| templates/post-processing-effect/ | Boilerplate for a custom Effect class (mergeable post-processing). |
| templates/post-processing-pass/ | Boilerplate for a custom Pass class (for multi-render-target effects like Moebius). |
| templates/fbo-particles/ | Boilerplate for a GPGPU particle system with simulation + render materials. |
| templates/raymarching-canvas/ | Boilerplate for a fullscreen-plane raymarched scene, with common uniforms and UV setup. |

Copy the template directory into the target project as a starting point, then adapt.

## Non-negotiable rules (the things that always bite)

These come up in virtually every R3F/shader project. Follow them without thinking.

### Memoise uniform objects

WRONG (shader freezes after first re-render):
    const uniforms = { u_time: { value: 0 } };

RIGHT:
    const uniforms = useMemo(() => ({ u_time: { value: 0 } }), []);

### Cap device pixel ratio

Use <Canvas dpr={[1, 2]}> -- not [1, 3], because iPhone DPR=3 will kill framerate.

### Use elapsed time, never frame deltas

WRONG (faster on 120Hz, slower on 30Hz):
    plane.position.z += 0.05;

RIGHT:
    plane.position.z = state.clock.getElapsedTime() * 0.15;

### Tone-mapping + colourspace in custom fragment shaders that sample FBOs

Add these at the end of every custom fragment main() that reads an FBO texture:
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
Without them, colours sampled from an FBO look washed out or muddy.

### attach='attributes-position' not attributes.position

R3F's attribute syntax uses dashes, not dots. This is a common 30-minute bug.

### needsUpdate = true after mutating attribute arrays

After directly editing an attribute array in useFrame:
    points.current.geometry.attributes.position.needsUpdate = true;

### Post-processing needs gamma correction (classic EffectComposer)

If using raw EffectComposer (not @react-three/postprocessing), add a GammaCorrectionShader pass last or colours look washed out.

## Typical workflow patterns

### Workflow A: scaffold -> iterate -> stylise
1. Start from templates/vite-r3f-starter/
2. Build the simplest scene first (a cube, one light, OrbitControls via drei)
3. Add the actual geometry + materials you need
4. Add leva sliders for every value you are unsure about
5. Tune by eye until it feels right
6. Only then wrap in post-processing / stylise

### Workflow B: reproduce a reference
1. Screenshot + annotate: what are the key visual layers? (outlines, hatching, colour palette, grain, distortion?)
2. For each layer, map to a technique from the references (outlines -> Sobel; hatching -> crosshatch texture masked by lighting; grain -> blue noise dither).
3. Build each layer in isolation as a toggleable leva control
4. Combine. Usually the composition reveals issues (e.g. two effects fighting). Resolve by adjusting order or intensities.

### Workflow C: effect -> reusable component
1. Build the effect inline in a test scene until it works
2. Extract the shaderMaterial or Effect class into its own file
3. Expose props / uniforms for the values you tuned with leva
4. Drop into other scenes via a clean component interface

## Maxime's style conventions

This skill's templates and examples follow conventions from Maxime's work:
- u_ prefix for uniforms (e.g. u_time, u_color, u_mouse)
- v_ prefix for varyings (e.g. v_uv, v_normal)
- a_ prefix for custom attributes (built-ins like position, uv, normal do not get renamed)
- Vertex shaders kept minimal by default -- pass vUv through, set gl_Position, done
- Fragment shaders are where the fun happens

## WebGPU or WebGL? (for new projects in 2026)

**Default: WebGPU-first with automatic WebGL fallback** via WebGPURenderer({ forceWebGL: false }). This gives:
- Near-native GPU performance
- Compute shaders for GPGPU work (simpler than FBO dance)
- Cross-platform via the Node System and TSL
- Automatic fallback where WebGPU is not supported

Use pure WebGL + GLSL only when:
- Porting a large existing codebase with no migration budget
- You need features not yet in TSL (very rare now)
- You want raw GLSL for educational purposes

See references/webgpu-tsl.md for migration guidance.

## When in doubt

- **Which noise function?** -> Start with Simplex or Perlin. Use FBM when you want cloud/terrain texture. Use curl noise for particle flow fields.
- **Should this be a material or a post-processing pass?** -> If it needs the rendered scene behind it, use post-processing. If it is a per-mesh property, use a material.
- **Material vs Lamina vs custom shader?** -> Stock Three material for PBR. Lamina when layering effects on top of a PBR material. Full custom shader when you need complete control.
- **Pass vs Effect?** -> Effect by default (mergeable, faster). Pass when you need multiple render targets, depth, or raw renderer access.
- **Why is my scene black after switching materials?** -> You switched to MeshStandardMaterial or similar PBR material and forgot to add a light. Add <ambientLight /> and/or <directionalLight />.
- **Why does my shader compile error just give a black screen?** -> Check the browser console, the shader compile log is there, often with a line number.

## Canonical sources (when this skill does not cover it)

When stuck on a topic this skill does not fully answer:
- blog.maximeheckel.com -- original source of everything in this skill
- iquilezles.org/articles -- definitive source on SDFs, raymarching, lighting math
- thebookofshaders.com -- GLSL fundamentals
- threejs.org/docs and threejs.org/examples
- docs.pmnd.rs -- R3F, drei, postprocessing
- shadertoy.com -- inspiration and reference implementations
- threejs.org/examples/webgpu_tsl_transpiler.html -- when migrating GLSL to TSL
