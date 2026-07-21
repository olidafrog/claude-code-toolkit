# R3F + Shader Fundamentals

Consolidated from Maxime Heckel's foundational posts (2022): Building a Vaporwave Scene, The Study of Shaders with R3F, The Magical World of Particles.

## Scene anatomy

A Three.js / R3F scene always reduces to these parts:

- **Scene** -- the container for all objects
- **Mesh = Geometry + Material** -- the object itself
- **Camera** -- the point of view (use PerspectiveCamera; near plane ~0.01, far plane tuned to scene scale)
- **Renderer** -- draws to a canvas. Always set renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2)) to cap DPR and avoid tanking performance on retina displays.
- **Tick function** -- animates per-frame via requestAnimationFrame. In R3F this is handled automatically by <Canvas> + useFrame.
- **Resize handler** -- update camera.aspect, call camera.updateProjectionMatrix(), and re-call renderer.setSize(). R3F handles this automatically.

## Frame-rate independence (critical)

**Never** do plane.position.z += 0.05 in a tick function -- this runs faster on 120fps monitors and slower on 30fps monitors. Always use elapsed time:

    const clock = new THREE.Clock();
    const tick = () => {
      const elapsedTime = clock.getElapsedTime();
      plane.position.z = elapsedTime * 0.15;
    };

In R3F: useFrame((state) => { state.clock.getElapsedTime() }).

## Endless-scroll plane trick

To fake infinite terrain moving toward the camera, use two planes and modulo the elapsed time:

    plane.position.z  =  (elapsedTime * 0.15) % 2;
    plane2.position.z = ((elapsedTime * 0.15) % 2) - 2;

Add scene.fog = new THREE.Fog('#000000', 1, 2.5) to hide the seam at the back of the scene.

## Texture-based terrain

Three layered textures drive the Vaporwave look:
- map -- base colour texture (grid PNG)
- displacementMap -- greyscale heightmap; lighter = higher. Pair with displacementScale (~0.4).
- metalnessMap -- controls per-pixel metalness so only some squares reflect light

Keep the centre of the displacement map black if you want a flat path through the middle.

## Lighting quickstart

- MeshBasicMaterial -- ignores lights, always visible
- MeshStandardMaterial -- physically based, **needs light** (without ambientLight, the scene is black)
- SpotLight('#d53c3d', intensity, distance, angle, penumbra) -- add .target.position.set(...) and scene.add(spotlight.target) to aim it

Common trap: switching from MeshBasicMaterial to MeshStandardMaterial makes everything black until you add a light.

## Shaders: vertex + fragment

A shader is a GLSL program running on the GPU. Two functions:

- **Vertex shader** -- runs per vertex, outputs gl_Position (screen-space coordinates)
- **Fragment shader** -- runs per visible pixel, outputs gl_FragColor (RGBA 0.0 to 1.0)

Wire them to a mesh via shaderMaterial:

    <mesh>
      <planeGeometry args={[1, 1, 32, 32]} />
      <shaderMaterial
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
      />
    </mesh>

### Default vertex shader (always start here)

    void main() {
      vec4 modelPosition = modelMatrix * vec4(position, 1.0);
      vec4 viewPosition = viewMatrix * modelPosition;
      vec4 projectedPosition = projectionMatrix * viewPosition;
      gl_Position = projectedPosition;
    }

modelMatrix, viewMatrix, projectionMatrix, position, and uv are injected automatically by Three.js -- do not declare them.

### Debugging reality
- No console.log -- GLSL has no debugger. Visualise values by writing them into gl_FragColor.
- A compile error = **blank screen**. Check the browser console for the shader compile log.
- Watch the shader compile error log; TSL/GLSL errors are verbose but parseable.

## Data flow: uniforms, varyings, attributes

Three ways to get data into/through shaders. Know when to use which:

| Carrier | JS to GPU | Per-vertex? | Where readable |
|---|---|---|---|
| Uniform | Yes | No, same for all | Both vertex + fragment |
| Attribute | Yes | Yes | Vertex only |
| Varying | No (GPU internal) | Yes (interpolated) | Vertex writes, fragment reads |

### Uniforms (JS to shader)

Convention: prefix with u_ (e.g. u_time, u_mouse, u_color).

    const uniforms = useMemo(() => ({
      u_time:  { value: 0 },
      u_color: { value: new THREE.Color('#ff00ff') },
    }), []);

    useFrame(({ clock }) => {
      meshRef.current.material.uniforms.u_time.value = clock.getElapsedTime();
    });

**CRITICAL**: always useMemo the uniforms object. If any state change triggers a re-render, a new uniforms object is created, the useFrame update targets the *old* reference, and the shader appears frozen.

### Varyings (vertex to fragment)

Convention: prefix with v_. Typical UV pass-through:

    // vertex
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }

    // fragment
    varying vec2 vUv;
    void main() {
      gl_FragColor = vec4(vUv, 0.0, 1.0);
    }

### Attributes (per-vertex data)

Built-in attributes you get for free: position, uv, normal. Custom attributes are defined via bufferAttribute:

    <bufferGeometry>
      <bufferAttribute
        attach='attributes-position'
        count={positions.length / 3}
        array={positions}
        itemSize={3}
      />
    </bufferGeometry>

Note the attributes-NAME attach syntax -- this is a common pitfall (it looks like it should be attributes.position but is not).

## Noise (the one trick)

For organic randomness, use noise functions -- never Math.random() per pixel (looks like static).
- **Perlin** -- smooth, classic, good for terrain
- **Simplex** -- faster, less directional artefacts
- **Curl noise** -- divergence-free, excellent for flow fields / particles
- **FBM (Fractal Brownian Motion)** -- stacked octaves of noise, produces cloud/mountain textures

Practical: install glsl-noise and import the function you need:

    #pragma glslify: snoise = require(glsl-noise/simplex/3d)
    float n = snoise(vec3(vUv * 5.0, u_time * 0.2));

## Particle systems

points = geometry + material (analogous to mesh).

### Small particle count: pointsMaterial
Use for a few hundred particles. Props: size, sizeAttenuation, color, map, transparent.

### Custom geometry: bufferGeometry + attributes
For arbitrary layouts (sphere surface, box, galaxy spiral):

    const positions = useMemo(() => {
      const arr = new Float32Array(count * 3);
      for (let i = 0; i < count; i++) {
        arr[i*3]   = (Math.random() - 0.5) * 2;
        arr[i*3+1] = (Math.random() - 0.5) * 2;
        arr[i*3+2] = (Math.random() - 0.5) * 2;
      }
      return arr;
    }, [count]);

### Large particle count: shaders + gl_PointSize
Replace pointsMaterial with shaderMaterial. In vertex shader set gl_PointSize (size attenuation: gl_PointSize = size * (1.0 / -viewPosition.z)).

In fragment shader, shape the particle using gl_PointCoord (0..1 across each point quad):

    void main() {
      float strength = 1.0 - distance(gl_PointCoord, vec2(0.5));
      strength = pow(strength, 3.0);
      vec3 color = mix(vec3(0.0), u_color, strength);
      gl_FragColor = vec4(color, strength);
    }

Set blending={THREE.AdditiveBlending} and depthWrite={false} on the material for glowing light-points effect.

### GPGPU / FBO particles (100k+ particles)
When animating 100k+ particles, per-frame JS loops die. Instead: store positions as an RGBA texture, update them in a fragment shader (simulation pass), then read the texture in the render pass's vertex shader.

See references/particles-advanced.md for the full FBO pipeline.

## Composable materials: Lamina

For when you want physically-correct lighting + custom shader effects layered on top. lamina from pmndrs lets you stack layers on top of a base material:

    import { LayerMaterial, Depth, Fresnel } from 'lamina';

    <LayerMaterial>
      <CustomLayer u_colorA='pink' u_colorB='orange' />
      <Depth colorA='purple' colorB='red' />
      <Fresnel color='pink' intensity={1.5} />
    </LayerMaterial>

Custom layers require minor rewrites of your shader code (uniforms prefixed u_, varyings v_, fragment returns return fragColor, vertex returns return position).

## Post-processing

Post-processing applies effects on the whole rendered image via EffectComposer. Basic setup:

    const composer = new EffectComposer(renderer);
    composer.addPass(new RenderPass(scene, camera));
    composer.addPass(new ShaderPass(RGBShiftShader));
    // replace renderer.render() with composer.render()

**Gotcha**: after any post-processing pass, add a GammaCorrectionShader pass at the end, or colours will look washed-out/dark.

In R3F, use @react-three/postprocessing:

    import { EffectComposer, Bloom, ChromaticAberration } from '@react-three/postprocessing';

    <EffectComposer>
      <Bloom intensity={1.0} />
      <ChromaticAberration offset={[0.002, 0.002]} />
    </EffectComposer>

## Recommended dependencies

Starter project always needs these: three, @react-three/fiber, @react-three/drei, @react-three/postprocessing, leva.

Shader tooling: vite-plugin-glsl, glsl-noise, glslify-loader.

For WebGPU work: three/tsl, three/webgpu.

## The iteration loop that works

From Maxime's process, across many posts:

1. **Study reference material** -- find an effect you like (dribbble, ShaderToy, a film still), annotate it, break it down into layers (outlines, hatching, colour, post). Do not try to one-shot the whole effect.
2. **Build the simplest scene first** -- one cube, one light, white material. Confirm camera and controls work.
3. **Add effects one at a time** -- each as its own pass or material property. Comment in/out to check what each layer contributes.
4. **Use leva for uniforms** -- never hard-code magic numbers during iteration. Add sliders for everything you are unsure about, tune by eye, then bake the values in once happy.
5. **Reverse-engineer references** -- pick a scene you love and try to reproduce it. This is the fastest way to learn.

## Common early mistakes

- Forgetting useMemo on uniforms -> shader freezes after first re-render
- Forgetting needsUpdate = true after mutating an attribute array -> nothing changes on screen
- Mixing pointsMaterial sizeAttenuation with shaderMaterial -- the latter needs manual gl_PointSize = size * (1.0 / -viewPosition.z)
- Black scene after switching to MeshStandardMaterial -- you need a light
- attach='attributes.position' instead of attach='attributes-position' -- dashes, not dots
- Wrong renderer output encoding after post-processing -- add GammaCorrectionShader
- Pixel ratio not capped -- use Math.min(window.devicePixelRatio, 2) or the scene will be unusable on retina
