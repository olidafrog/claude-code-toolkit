# vite-r3f-webgpu-starter

WebGPU-first R3F starter with TSL. Runs on WebGPU where available, falls back to WebGL automatically.

Requires React 19 + R3F v9 (async gl prop support).

## Stack additions over the WebGL starter

- three/webgpu -- the WebGPU renderer and Node material classes
- three/tsl -- Three Shading Language functions (Fn, uniform, cnoise, etc.)
- Node material JSX (meshStandardNodeMaterial) instead of stock materials

## When to use this over the WebGL starter

Use this unless you have a specific reason not to (existing GLSL codebase, target devices without WebGPU support and no fallback, etc.).

## Testing both backends

Set forceWebGL: true in App.tsx -- forces WebGL path for testing.

## Adding TSL shaders

    import { Fn, uv, mix, vec3, vec4 } from 'three/tsl';

    const colorNode = Fn(() => {
      const uvCoord = uv();
      return vec4(uvCoord.x, uvCoord.y, 1.0, 1.0);
    })();

    <meshBasicNodeMaterial colorNode={colorNode} />

For compute shaders and advanced TSL, see the skills references/webgpu-tsl.md.

## Migration from GLSL

Three.js ships an online transpiler: https://threejs.org/examples/webgpu_tsl_transpiler.html -- paste GLSL, get TSL out.
