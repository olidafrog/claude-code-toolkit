# Stylized Shaders & Post-Processing Effects

Consolidated from: Moebius-style post-processing (2024), The Art of Dithering (2024), On Crafting Painterly Shaders (2024), Post-Processing as a Creative Medium (2025), Shades of Halftone (2026).

## Post-processing in R3F: two paths

There are two ways to add post-processing in R3F -- they solve the same problem but work differently:

### Pass (full control, stackable)
Each pass renders to its own buffer, feeds its output into the next. Use for custom multi-render-target effects (edge detection, multi-pass bloom):

    import { Pass } from 'postprocessing';

    class MyPass extends Pass {
      constructor(args) {
        super();
        this.material = new THREE.ShaderMaterial({...});
        this.fsQuad = new FullScreenQuad(this.material);
      }
      render(renderer, writeBuffer, readBuffer) {
        this.material.uniforms.tDiffuse.value = readBuffer.texture;
        if (this.renderToScreen) {
          renderer.setRenderTarget(null);
        } else {
          renderer.setRenderTarget(writeBuffer);
          if (this.clear) renderer.clear();
        }
        this.fsQuad.render(renderer);
      }
    }

Wire it up using extend then use as JSX inside <Effects>:

    import { Effects } from '@react-three/drei';
    extend({ MyPass });
    <Effects><myPass args={[{...}]} /></Effects>

### Effect (merged, more performant)
Multiple effects get merged into a single pass, so chaining is faster:

    import { Effect } from 'postprocessing';
    import { wrapEffect, EffectComposer } from '@react-three/postprocessing';

    class RetroEffectImpl extends Effect {
      constructor() {
        super('RetroEffect', fragmentShader, {
          uniforms: new Map([]),
        });
      }
    }
    const RetroEffect = wrapEffect(RetroEffectImpl);

    <EffectComposer><RetroEffect /></EffectComposer>

Effect fragment shaders use a mainImage function (not main) with auto-wired uniforms:

    void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
      vec4 color = texture2D(inputBuffer, uv);
      outputColor = color;
    }

### When to use which
- Use Effect by default -- simpler, mergeable, good performance
- Use Pass when you need multi-target rendering, depth buffers, or access to raw renderer/readBuffer/writeBuffer

## The shape of modern post-processing work

Virtually every stylized effect in Maxime's library follows the same two-step shape:

### 1. Remap or distort UV coordinates
This is how you pixelate, offset, stagger grids:

    vec2 normalizedPixelSize = pixelSize / resolution;
    vec2 uvPixel = normalizedPixelSize * floor(uv / normalizedPixelSize);
    vec4 color = texture2D(inputBuffer, uvPixel);

### 2. Shape, sculpt, or tweak each cell individually
Use fract to get cell-local UVs (0..1 within each cell), then draw patterns:

    vec2 cellUv = fract(uv / normalizedPixelSize);
    float dist = length(cellUv - 0.5);

Every stylised shader in Maxime's library -- receipts, halftone, ASCII art, Moebius, dithering -- is a variation on remap UVs then shape each cell.

## Dithering (retro/8-bit look)

### White noise dithering (first pass)

    float random(vec2 c) {
      return fract(sin(dot(c.xy, vec2(12.9898, 78.233))) * 43758.5453);
    }

    void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
      vec4 color = texture2D(inputBuffer, uv);
      float lum = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);
      outputColor = vec4(lum < random(uv) ? vec3(0.0) : vec3(1.0), 1.0);
    }

### Ordered dithering (Bayer matrix)
Much cleaner, more retro-feeling result. 4x4 Bayer matrix:

    const mat4 bayerMatrix4x4 = mat4(
       0.0,  8.0,  2.0, 10.0,
      12.0,  4.0, 14.0,  6.0,
       3.0, 11.0,  1.0,  9.0,
      15.0,  7.0, 13.0,  5.0
    ) / 16.0;

    int x = int(uv.x * resolution.x) % 4;
    int y = int(uv.y * resolution.y) % 4;
    float threshold = bayerMatrix4x4[y][x];
    vec3 color = lum < threshold + bias ? vec3(0.0) : vec3(1.0);

### Blue noise dithering
Least structured, still non-random. Use a LDR_RGBA_0.png-style blue noise texture:

    vec4 noise = texture2D(uNoise, gl_FragCoord.xy / 128.0);
    float threshold = noise.r;

Do not forget texture.wrapS = texture.wrapT = THREE.RepeatWrapping.

### Color quantization (8/16-bit palette look)
Round each colour channel to N discrete steps:

    color.rgb += threshold;
    color.r = floor(color.r * (colorNum - 1.0) + 0.5) / (colorNum - 1.0);
    color.g = floor(color.g * (colorNum - 1.0) + 0.5) / (colorNum - 1.0);
    color.b = floor(color.b * (colorNum - 1.0) + 0.5) / (colorNum - 1.0);

For colorNum = 2 you get 2^3 = 8 colours, for colorNum = 4 you get 64 colours.

### Custom palettes
Use a grayscale-sorted palette texture: sample it with the luma as U:

    float lum = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);
    vec3 paletteColor = texture2D(uPalette, vec2(lum, 0.5)).rgb;

## Moebius / hand-drawn outlines (edge detection)

Three render targets feed a Sobel filter:
1. **Main scene** (standard render)
2. **Depth texture** -- for outer/occlusion outlines
3. **Normal texture** -- for inner/crease outlines

### Getting the depth texture

    const depthTexture = new THREE.DepthTexture(window.innerWidth, window.innerHeight);
    const depthRenderTarget = useFBO(window.innerWidth, window.innerHeight, {
      depthTexture,
      depthBuffer: true,
    });

### Getting the normal texture (whole-scene override)
Do not attach NormalMaterial to each mesh -- use scene.overrideMaterial instead:

    const originalMaterial = scene.overrideMaterial;
    scene.matrixWorldNeedsUpdate = true;
    scene.overrideMaterial = normalMaterial;
    gl.setRenderTarget(normalRenderTarget);
    gl.render(scene, camera);
    scene.overrideMaterial = originalMaterial;

### Reading depth in a shader

    #include <packing>
    uniform sampler2D tDepth;
    uniform float cameraNear;
    uniform float cameraFar;

    float readDepth(sampler2D depthTexture, vec2 coord) {
      float fragCoordZ = texture2D(depthTexture, coord).x;
      float viewZ = perspectiveDepthToViewZ(fragCoordZ, cameraNear, cameraFar);
      return viewZToOrthographicDepth(viewZ, cameraNear, cameraFar);
    }

### Sobel edge detection filter
Apply 3x3 kernels to detect intensity gradients:

    const mat3 Sx = mat3(-1, -2, -1,  0, 0, 0,  1, 2, 1);
    const mat3 Sy = mat3(-1,  0,  1, -2, 0, 2, -1, 0, 1);

    float d00 = readDepth(tDepth, uv + thickness * texel * vec2(-1,  1));
    float d01 = readDepth(tDepth, uv + thickness * texel * vec2(-1,  0));
    // ... 9 samples total

    float gx = Sx[0][0]*d00 + Sx[0][1]*d01 + ...;
    float gy = Sy[0][0]*d00 + Sy[0][1]*d01 + ...;
    float edge = sqrt(gx*gx + gy*gy);

    if (edge > threshold) {
      outputColor = vec4(outlineColor.rgb, 1.0);
    } else {
      outputColor = sampledSceneColor;
    }

Combine the depth-based edges and normal-based edges with max() or weighted sum.

### Crosshatched shadows
For the Moebius crosshatched shadow effect, sample a crosshatch texture and mask it by light intensity:

    float shadow = 1.0 - dot(normal, lightDir);
    float hatch = texture2D(uHatchTexture, uv * hatchScale).r;
    float crosshatch = step(shadow, hatch);
    outputColor.rgb *= crosshatch;

## Painterly (Kuwahara filter)

The Kuwahara filter smooths images while preserving edges -- perfect for watercolour/gouache looks.

### Classic Kuwahara (4 sectors, square kernel)
For each pixel: sample 4 overlapping square boxes around it, compute the mean+variance of each, use the mean of the lowest-variance box:

    #define SECTOR_COUNT 4
    uniform int kernelSize;
    uniform sampler2D inputBuffer;
    uniform vec4 resolution;

    void getSectorVarianceAndAverageColor(vec2 offset, int boxSize, out vec3 avgColor, out float variance) {
      vec3 colorSum = vec3(0.0);
      vec3 squaredColorSum = vec3(0.0);
      float n = 0.0;

      for (int y = 0; y < boxSize; y++) {
        for (int x = 0; x < boxSize; x++) {
          vec3 c = sampleColor(offset + vec2(float(x), float(y)));
          colorSum += c;
          squaredColorSum += c * c;
          n += 1.0;
        }
      }

      avgColor = colorSum / n;
      vec3 varianceRes = (squaredColorSum / n) - (avgColor * avgColor);
      variance = dot(varianceRes, vec3(0.299, 0.587, 0.114));
    }

    void main() {
      vec3 avgs[SECTOR_COUNT];
      float vars[SECTOR_COUNT];
      getSectorVarianceAndAverageColor(vec2(-kernelSize, -kernelSize), kernelSize, avgs[0], vars[0]);
      getSectorVarianceAndAverageColor(vec2(0, -kernelSize),           kernelSize, avgs[1], vars[1]);
      getSectorVarianceAndAverageColor(vec2(-kernelSize, 0),           kernelSize, avgs[2], vars[2]);
      getSectorVarianceAndAverageColor(vec2(0, 0),                     kernelSize, avgs[3], vars[3]);

      float minVar = vars[0];
      vec3 result = avgs[0];
      for (int i = 1; i < SECTOR_COUNT; i++) {
        if (vars[i] < minVar) {
          minVar = vars[i];
          result = avgs[i];
        }
      }
      gl_FragColor = vec4(result, 1.0);
    }

### Papari extension (8 sectors, circular kernel)
The square kernel creates boxy artifacts at large sizes. Papari's extension uses a circular kernel with 8 sectors (like pizza slices):

    void getSectorVarianceAndAverageColor(float angle, float radius, out vec3 avgColor, out float variance) {
      for (float r = 1.0; r <= radius; r += 1.0) {
        for (float a = -0.392699; a <= 0.392699; a += 0.196349) {
          vec2 sampleOffset = r * vec2(cos(angle + a), sin(angle + a));
          vec3 c = sampleColor(sampleOffset);
        }
      }
    }

    for (int i = 0; i < 8; i++) {
      float angle = float(i) * 6.28318 / 8.0;
      getSectorVarianceAndAverageColor(angle, float(radius), avgs[i], vars[i]);
    }

### Further improvements
- **Gaussian weighting** -- weigh centre pixels more than edge pixels for smoother transitions
- **Anisotropic Kuwahara** -- orient sectors along local image structure using a Structure Tensor, gives actual brushstroke directionality
- **Colour correction + paper texture** -- multiply by a paper texture and lightly darken for final painting look

Reference: Papari's original paper, Kyprianidis et al. on Anisotropic Kuwahara.

## Pixel patterns (receipts, ASCII, halftone)

All based on the same remap UVs -> shape each cell pattern.

### Receipt-style bars
For each pixelated cell, draw a horizontal black bar whose width depends on the cell's luma:

    vec2 cellUv = fract(uv / normalizedPixelSize);
    float luma = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);

    float lineWidth = 0.0;
    if (luma > 0.0)  lineWidth = 1.0;
    if (luma > 0.3)  lineWidth = 0.7;
    if (luma > 0.5)  lineWidth = 0.5;
    if (luma > 0.7)  lineWidth = 0.3;
    if (luma > 0.9)  lineWidth = 0.1;
    if (luma > 0.99) lineWidth = 0.0;

    if (cellUv.y > 0.05 && cellUv.y < 0.95 && cellUv.x > 0.0 && cellUv.x < lineWidth) {
      color = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
      color = vec4(0.70, 0.74, 0.73, 1.0);
    }

### Halftone dots
Circles per cell, radius scaled by luma:

    vec2 normalizedPixelSize = pixelSize / resolution;
    vec2 uvPixel = normalizedPixelSize * floor(uv / normalizedPixelSize);
    vec4 color = texture2D(inputBuffer, uvPixel);
    float luma = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);

    vec2 cellUv = fract(uv / normalizedPixelSize);
    float dist = length(cellUv - 0.5);
    float radius = uRadius * (0.1 + luma);

    float circle = smoothstep(radius - 0.01, radius + 0.01, dist);
    color = mix(color, vec4(0.0, 0.0, 0.0, 1.0), circle);

### Staggered halftone (offset alternate rows)

    vec2 offsetUv = uv;
    float rowIndex = floor(uv.y / normalizedPixelSize.y);
    if (mod(rowIndex, 2.0) == 1.0) {
      offsetUv.x += normalizedPixelSize.x * 0.5;
    }
    vec2 uvPixel = normalizedPixelSize * floor(offsetUv / normalizedPixelSize);

This offset propagates through both pixelisation and dot drawing, giving a tighter-packed diagonal pattern.

### Ring halftone
Two circles subtracted:

    float outer = smoothstep(uRadius - 0.01, uRadius + 0.01, dist);
    float inner = smoothstep(uRadius - 0.1, uRadius - 0.08, dist);
    float ring = outer - inner;

### Inverted halftone (dark cells with white dots)
Luma-dependent white-dot-in-coloured-square:
- Dark pixel -> filled square with white dot in the middle
- Light pixel -> plain (or regular dot)
Mix between patterns based on luma threshold for distinctive look.

### ASCII art
Sample a character palette texture where characters are sorted by density:

    vec2 cellUv = fract(uv / normalizedPixelSize);
    float luma = dot(vec3(0.2126, 0.7152, 0.0722), color.rgb);
    int charIndex = int(luma * float(NUM_CHARS));
    vec2 charUv = vec2(
      (float(charIndex) + cellUv.x) / float(NUM_CHARS),
      cellUv.y
    );
    vec4 asciiSample = texture2D(uAsciiTexture, charUv);
    color = asciiSample.r > 0.5 ? textColor : bgColor;

## Iteration & composition tips

From Maxime's Post-Processing as a Creative Medium article -- what made him productive:

1. **Study references obsessively** -- whenever you see an effect you love (halftone, Moebius, receipt, painterly), screenshot it, annotate what you see: grid? colour quantization? edges? Then rebuild piece by piece.
2. **Always include leva for uniforms** -- every intensity, threshold, radius, colour becomes a live control. Tune by eye, then bake values in when happy.
3. **Start with a hello-world effect** -- a single outputColor = mix(inputColor, red, 0.5) confirms the Effect is wired before you try anything complex.
4. **Use half-res rendering for expensive effects** -- any Kuwahara filter at kernel size > 6, any volumetric pass, any multi-sample refraction: render to a smaller target, upscale in a second pass.
5. **Cap DPR at 2** -- on <Canvas dpr={[1, 2]}>. iPhone can push DPR to 3, which will tank your frame rate and subtly break screen-space sampling.
