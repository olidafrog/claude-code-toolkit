# GPGPU & FBO Particles (100k+)

Consolidated from: The Magical World of Particles with R3F and Shaders (2022).

## When to reach for FBO particles

Use standard <bufferGeometry> with attributes when you have up to ~10,000 particles and only need simple per-frame attribute updates. Use **FBO (Frame Buffer Object) particles** when:

- You need 100,000+ particles without frame drops
- Particle positions depend on their previous positions (attractors, flow fields)
- You want fully GPU-side physics (curl noise, flocking, reaction-diffusion)

The technique: store positions as pixels in a texture, update them in a fragment shader running on an offscreen scene, then read the texture in the render pass.

## The core idea

Think of RGBA channels as xyzw coordinates:
- R = position.x
- G = position.y
- B = position.z
- A = anything else (age, state, seed)

A 128x128 texture stores 16,384 particle positions. Each frame: render a fullscreen quad into this texture with a shader that updates each pixel (i.e. each particle). Then in the main render pass, the vertex shader reads this texture to place points in 3D.

## The three phases per frame

1. **Simulation pass** -- render a SimulationMaterial onto a fullscreen quad in an offscreen scene. Its fragment shader reads current positions (texture input), computes new positions, outputs them as the next frame's positions texture.
2. **Render pass** -- in the main scene, a points mesh uses a shaderMaterial whose vertex shader reads this texture and sets gl_Position per-particle.
3. **Texture swap** -- the FBO's texture is fed into both the simulation shader (as input) and the render shader (as input) for the next frame.

## Full implementation

### SimulationMaterial (the physics engine)

    class SimulationMaterial extends THREE.ShaderMaterial {
      constructor(size) {
        const positionsTexture = new THREE.DataTexture(
          generatePositions(size, size),
          size, size,
          THREE.RGBAFormat,
          THREE.FloatType
        );
        positionsTexture.needsUpdate = true;

        super({
          uniforms: {
            positions: { value: positionsTexture },
            uTime:     { value: 0 },
            uFrequency:{ value: 0.25 },
          },
          vertexShader: simulationVertexShader,
          fragmentShader: simulationFragmentShader,
        });
      }
    }

    extend({ SimulationMaterial });

    const generatePositions = (width, height) => {
      const length = width * height * 4;
      const data = new Float32Array(length);
      for (let i = 0; i < width * height; i++) {
        const i4 = i * 4;
        const r = Math.sqrt(Math.random()) * 1.0;
        const theta = Math.random() * Math.PI * 2;
        const phi = Math.random() * Math.PI;
        data[i4]   = r * Math.sin(phi) * Math.cos(theta);
        data[i4+1] = r * Math.sin(phi) * Math.sin(theta);
        data[i4+2] = r * Math.cos(phi);
        data[i4+3] = 1.0;
      }
      return data;
    };

### Simulation fragment shader (curl noise example)

    uniform sampler2D positions;
    uniform float uTime;
    uniform float uFrequency;
    varying vec2 vUv;

    void main() {
      vec3 pos = texture2D(positions, vUv).rgb;
      vec3 curl = curlNoise(pos * uFrequency + uTime * 0.1);
      pos += curl * 0.01;
      gl_FragColor = vec4(pos, 1.0);
    }

### FBOParticles component

    import { useFBO } from '@react-three/drei';
    import { useFrame, createPortal } from '@react-three/fiber';
    import { useMemo, useRef } from 'react';

    const FBOParticles = () => {
      const size = 128;
      const points = useRef();
      const simulationMaterialRef = useRef();

      const scene = useMemo(() => new THREE.Scene(), []);
      const camera = useMemo(() => new THREE.OrthographicCamera(-1, 1, 1, -1, 1/Math.pow(2,53), 1), []);

      const squarePositions = useMemo(() => new Float32Array([
        -1, -1, 0,  1, -1, 0,  1, 1, 0,
        -1, -1, 0,  1,  1, 0, -1, 1, 0
      ]), []);
      const squareUvs = useMemo(() => new Float32Array([
        0, 0,  1, 0,  1, 1,
        0, 0,  1, 1,  0, 1
      ]), []);

      const renderTarget = useFBO(size, size, {
        minFilter: THREE.NearestFilter,
        magFilter: THREE.NearestFilter,
        format: THREE.RGBAFormat,
        stencilBuffer: false,
        type: THREE.FloatType,
      });

      const particleRefUvs = useMemo(() => {
        const length = size * size;
        const uvs = new Float32Array(length * 3);
        for (let i = 0; i < length; i++) {
          uvs[i*3]   = (i % size) / size;
          uvs[i*3+1] = Math.floor(i / size) / size;
          uvs[i*3+2] = 0;
        }
        return uvs;
      }, []);

      const uniforms = useMemo(() => ({
        uPositions: { value: null },
        uTime: { value: 0 },
      }), []);

      useFrame(({ gl, clock }) => {
        gl.setRenderTarget(renderTarget);
        gl.clear();
        gl.render(scene, camera);
        gl.setRenderTarget(null);

        points.current.material.uniforms.uPositions.value = renderTarget.texture;
        simulationMaterialRef.current.uniforms.uTime.value = clock.elapsedTime;
      });

      return (
        <>
          {createPortal(
            <mesh>
              <simulationMaterial ref={simulationMaterialRef} args={[size]} />
              <bufferGeometry>
                <bufferAttribute attach='attributes-position' count={squarePositions.length / 3} array={squarePositions} itemSize={3} />
                <bufferAttribute attach='attributes-uv' count={squareUvs.length / 2} array={squareUvs} itemSize={2} />
              </bufferGeometry>
            </mesh>,
            scene
          )}

          <points ref={points}>
            <bufferGeometry>
              <bufferAttribute attach='attributes-position' count={particleRefUvs.length / 3} array={particleRefUvs} itemSize={3} />
            </bufferGeometry>
            <shaderMaterial
              blending={THREE.AdditiveBlending}
              depthWrite={false}
              transparent
              fragmentShader={renderFragment}
              vertexShader={renderVertex}
              uniforms={uniforms}
            />
          </points>
        </>
      );
    };

### Render vertex shader (read positions from texture)

    uniform sampler2D uPositions;
    uniform float uTime;

    void main() {
      vec3 pos = texture2D(uPositions, position.xy).rgb;
      vec4 modelPosition = modelMatrix * vec4(pos, 1.0);
      vec4 viewPosition = viewMatrix * modelPosition;
      gl_Position = projectionMatrix * viewPosition;
      gl_PointSize = 2.0 * (1.0 / -viewPosition.z);
    }

### Render fragment shader (the point appearance)

    void main() {
      float d = distance(gl_PointCoord, vec2(0.5));
      float strength = 1.0 - smoothstep(0.0, 0.5, d);
      strength = pow(strength, 3.0);
      gl_FragColor = vec4(vec3(1.0), strength);
    }

## What to feed into the simulation shader

Beyond curl noise, the simulation shader can implement any iterative update rule. Ideas:

- **Attractor fields** -- position updates based on nearest attractor point
- **Flocking / boids** -- each particle reads its neighbours from the positions texture (you get this for free -- every particle is readable!)
- **Spring / verlet physics** -- store previous position in .w channel, use verlet integration
- **Morph between shapes** -- lerp between a start-shape positions texture and a target-shape positions texture

## Morphing between shapes
Two DataTextures for start/target positions, lerp in the simulation shader:

    uniform sampler2D uStartPositions;
    uniform sampler2D uTargetPositions;
    uniform float uProgress;

    void main() {
      vec3 start = texture2D(uStartPositions, vUv).rgb;
      vec3 target = texture2D(uTargetPositions, vUv).rgb;
      vec3 pos = mix(start, target, smoothstep(0.0, 1.0, uProgress));
      gl_FragColor = vec4(pos, 1.0);
    }

Maxime achieved 250k+ particles morphing between shapes on an M1 MacBook without breaking a sweat.

## Performance notes

- size = 128 -> 16,384 particles. size = 256 -> 65,536. size = 512 -> 262,144.
- **Always** use THREE.FloatType on the render target -- HalfFloatType causes visible jitter on positions
- **Always** use THREE.NearestFilter for min/mag -- interpolation corrupts positions
- Additive blending + small point sizes = that magical fireflies / starfield glow
- With size = 128, a 2020 M1 Pro easily hits 120fps. Push beyond 512 only for GPU-class demos.

## WebGPU/TSL equivalent

With WebGPU, this becomes dramatically simpler using compute shaders and storage buffers -- no render target gymnastics needed. See references/webgpu-tsl.md for the TSL version of this pattern.
