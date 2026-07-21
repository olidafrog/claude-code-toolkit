# vite-r3f-starter

Vite + React + React Three Fiber starter with sensible defaults baked in.

## Stack

- **Vite** -- fast dev server + bundler
- **React Three Fiber** -- React renderer for Three.js
- **drei** -- common R3F helpers (OrbitControls, Environment, Stats, useFBO, etc.)
- **postprocessing** + @react-three/postprocessing -- effects pipeline
- **leva** -- runtime controls for tuning by eye
- **vite-plugin-glsl** -- import .glsl / .vert / .frag as strings with #include support

## Baked-in conventions

- dpr={[1, 2]} on the Canvas -- caps device pixel ratio to avoid iPhone DPR=3 killing framerate
- shadows enabled, studio environment lighting
- useFrame always reads elapsed time, never accumulates deltas
- <Stats /> in the corner for FPS monitoring

## Get started

    npm install
    npm run dev

Then open src/Scene.tsx and replace the demo cube with your work.

## Add shaders

Drop a .glsl, .vert, or .frag file next to your component, then:

    import fragmentShader from './my-shader.frag';
    import vertexShader from './my-shader.vert';

For a full custom shaderMaterial with uniforms, copy the custom-shader-material/ template.

## Add post-processing

    import { EffectComposer, Bloom, ChromaticAberration } from '@react-three/postprocessing';

    <EffectComposer>
      <Bloom intensity={0.8} mipmapBlur />
      <ChromaticAberration offset={[0.002, 0.002]} />
    </EffectComposer>

For custom effects, copy the post-processing-effect/ template.
