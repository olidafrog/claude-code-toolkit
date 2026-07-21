# WebGPU & TSL (Three Shading Language)

Consolidated from: Field Guide to TSL and WebGPU (2025).

## Quick decision: WebGL or WebGPU?

In 2026, the answer is almost always: **use WebGPU via TSL, fall back to WebGL automatically**. Three.js's WebGPURenderer auto-falls-back to WebGL when WebGPU is not available, so you ship one codebase that targets everything.

Why:
- WebGPU has near-native performance (on par with Vulkan/Metal/DirectX)
- Compute shaders unlock GPGPU patterns (particles, simulation) with much simpler code than the FBO-dance
- Older WebGL codebases can use TSL and still run on both backends

Exceptions where you would stick with pure WebGL + GLSL:
- Existing large codebase with no WebGPU migration budget
- Heavily customised RawShaderMaterial that you do not want to port
- Niche shader features not yet in TSL (rare and shrinking)

## Terminology

| Name | What it is |
|---|---|
| **WebGPU** | Browser API for modern GPU access. Successor to WebGL. |
| **WGSL** | WebGPU's shading language (like GLSL, but for WebGPU) |
| **TSL** | Three Shading Language -- a JS-based abstraction that targets both WGSL and GLSL |
| **Node System** | TSL's way of composing shader logic as objects you hook onto material slots |
| **Compute shader** | A shader that runs arbitrary GPU computation (not tied to rendering). WebGPU-only. |

Critical: you **cannot write raw WebGPU/WGSL shaders** directly with Three.js -- it is all abstracted through TSL. You can write inline WGSL using wgslFn or GLSL using glslFn, but TSL is the only way to wire them into materials.

## Setup: WebGPU renderer in R3F

Requires React Three Fiber v9+ (supports async gl prop):

    import * as THREE from 'three/webgpu';

    const Scene = () => (
      <Canvas
        shadows
        gl={async (props) => {
          const renderer = new THREE.WebGPURenderer(props);
          await renderer.init();
          return renderer;
        }}
      >
        {/* scene */}
      </Canvas>
    );

To force WebGL (for testing cross-backend compatibility):

    const renderer = new THREE.WebGPURenderer({ ...props, forceWebGL: true });

## TSL syntax basics

TSL is functional and chainable. Everything is a node that composes into a graph:

    import { Fn, uv, vec3, vec4, mix, add, uniform } from 'three/tsl';

    const colorNode = Fn(([baseColor]) => {
      const uvCoord = uv();
      const red = uvCoord.x.add(2.3).mul(0.3);
      const green = uvCoord.y.add(1.7).div(8.2);
      const blue = add(uvCoord.x, uvCoord.y).mod(10.0);
      const tint = vec4(red, green, blue, 1.0);
      return mix(baseColor, tint, uvCoord.x);
    });

For GLSL equivalents: uvCoord.x.add(2.3).mul(0.3) is the same as (uv.x + 2.3) * 0.3.

Yes, the syntax is verbose. Tradeoff: maintainability, cross-backend portability, no string concatenation, explicit node composition.

### Escape hatch: inline native code
If TSL's syntax is too much for a complex shader, embed raw GLSL or WGSL:

    import { glslFn, wgslFn, uniform } from 'three/tsl';

    const colorGLSL = glslFn(`
      vec4 colorFn(vec4 baseColor, vec2 uv) {
        float red = (uv.x + 2.3) * 0.3;
        return mix(baseColor, vec4(red, 0.0, 0.0, 1.0), uv.x);
      }
    `);

    const colorNode = colorGLSL({
      baseColor: uniform(new THREE.Vector4(1, 1, 1, 1)),
      uv: uv(),
    });

But note: glslFn only works on the WebGL backend. For cross-backend, use wgslFn or keep everything in TSL syntax.

### Use the transpiler
Three.js ships an online GLSL-to-TSL transpiler and a TSL editor. When migrating an existing GLSL shader, paste it in, get TSL out, refine by hand.

## The Node System (the killer feature)

Every standard Three.js material has a NodeMaterial equivalent in TSL:

| Classic | Node equivalent |
|---|---|
| MeshBasicMaterial | MeshBasicNodeMaterial |
| MeshStandardMaterial | MeshStandardNodeMaterial |
| MeshPhysicalMaterial | MeshPhysicalNodeMaterial |
| MeshPhongMaterial | MeshPhongNodeMaterial |

Each exposes hooks you can override without rewriting the whole material:

    <meshPhongNodeMaterial
      color='white'
      positionNode={myDisplacementShader}
      normalNode={myNormalShader}
      colorNode={myColorShader}
    />

This replaces onBeforeCompile + string munging. Huge win for maintainability.

## Displacement + recomputed normals example

The classic blob shader, now in TSL:

    const { nodes, uniforms } = useMemo(() => {
      const time = uniform(0.0);
      const vNormal = varying(vec3(), 'vNormal');

      const updatePos = Fn(([pos, time]) => {
        const noise = cnoise(vec3(pos).add(vec3(time))).mul(0.2);
        return add(pos, noise);
      });

      const positionNode = Fn(() => {
        const pos = positionLocal;
        const updatedPos = updatePos(pos, time);

        const theta = float(0.001);
        const vecTangent = orthogonal();
        const vecBiTangent = normalize(cross(normalLocal, vecTangent));

        const n1 = updatePos(pos.add(vecTangent.mul(theta)), time);
        const n2 = updatePos(pos.add(vecBiTangent.mul(theta)), time);

        const dispTangent = n1.sub(updatedPos);
        const dispBitangent = n2.sub(updatedPos);
        const normal = normalize(cross(dispTangent, dispBitangent));

        vNormal.assign(normal);
        return updatedPos;
      })();

      const normalNode = Fn(() => {
        return transformNormalToView(vNormal);
      })();

      return { nodes: { positionNode, normalNode }, uniforms: { time } };
    }, []);

    useFrame(({ clock }) => {
      uniforms.time.value = clock.getElapsedTime();
    });

    return (
      <mesh>
        <icosahedronGeometry args={[1.5, 200]} />
        <meshPhongNodeMaterial
          color='white'
          normalNode={nodes.normalNode}
          positionNode={nodes.positionNode}
          emissive={new THREE.Color('white').multiplyScalar(0.25)}
          shininess={400.0}
        />
      </mesh>
    );

## Uniforms in TSL

Between WebGL and WebGPU, uniforms work differently under the hood (uniform buffers, bind groups) -- but TSL hides this:

    const time = uniform(0.0);
    const color = uniform(new THREE.Color('red'));
    const offset = uniform(new THREE.Vector2(1, 2));

    useFrame(({ clock }) => {
      time.value = clock.getElapsedTime();
    });

Supported types: boolean, number, Color, Vector2, Vector3, Vector4, Matrix3, Matrix4. For textures, use texture(myTexture) instead.

## Organisation pattern for TSL nodes

Wrap all TSL in a useMemo that returns { nodes, uniforms }:

    const { nodes, uniforms } = useMemo(() => {
      const time = uniform(0.0);
      // ... build nodes here ...
      return {
        nodes: { positionNode, colorNode, normalNode },
        uniforms: { time },
      };
    }, []);

This prevents accidental recreation of uniforms on re-render (same pitfall as with shaderMaterial).

## Compute shaders (WebGPU only)

Compute shaders let you run arbitrary GPU computation -- not tied to vertex/fragment rendering. Opens up:

- **Simpler GPGPU particles** -- no more FBO dance, just a compute shader that reads/writes a storage buffer
- **Instanced mesh simulation** -- compute positions for N instances in parallel
- **Post-processing** -- some filters are simpler as compute
- **Physics / simulation** -- fluids, cloth, reaction-diffusion

TSL's compute() function:

    import { compute, Fn, storage } from 'three/tsl';

    const positions = storage(particleBuffer, 'vec3', COUNT);
    const velocities = storage(velocityBuffer, 'vec3', COUNT);

    const updateCompute = Fn(() => {
      const i = instanceIndex;
      const pos = positions.element(i);
      const vel = velocities.element(i);
      pos.addAssign(vel.mul(deltaTime));
    });

    renderer.computeAsync(compute(updateCompute, COUNT));

Compute shaders are the main reason to graduate from WebGL/GLSL to WebGPU/TSL: once you use them for particles, the old FBO pattern feels archaic.

## Pitfalls encountered during migration

From Maxime's field-guide post:
- extend() from R3F has some quirks with node materials -- sometimes you have to add lights via scene.add() rather than JSX
- three/webgpu vs three -- watch your imports, mixing them breaks things silently
- meshStandardMaterial in a WebGPU scene is actually MeshStandardNodeMaterial -- name looks identical
- uniform() only supports the listed primitive types -- for textures, use texture(); for samplers, use sampler()
- Vary statements (varying) work differently between backends but TSL unifies them -- you just use varying(vec3(), 'vNormal')

## Recommended migration order

If you have an existing WebGL codebase you want to port:

1. **Swap renderer first** -- switch to WebGPURenderer with forceWebGL: true. Should work identically.
2. **Swap materials one at a time** -- MeshStandardMaterial -> MeshStandardNodeMaterial. Most just work.
3. **Port custom ShaderMaterials** -- use the transpiler to get initial TSL, then refine
4. **Replace onBeforeCompile hacks with node slots** -- easier and more maintainable
5. **Remove forceWebGL: true** -- ship with auto-fallback
6. **(Optional) Move GPGPU work to compute shaders** -- biggest performance and clarity win

## Key takeaway

TSL is a leaky abstraction that requires some ceremony, but it is the only way to target WebGPU with Three.js, and the Node System is genuinely better than onBeforeCompile for extending built-in materials. For new projects in 2026: start with WebGPU/TSL.
