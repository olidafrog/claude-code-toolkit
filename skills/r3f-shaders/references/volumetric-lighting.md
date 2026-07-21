# Volumetric Lighting via Post-Processing

Consolidated from: On Shaping Light (2025).

## When to use this

When you want those beautiful cinematic beams of light shining through gaps -- god rays, spotlight cones through fog, sun shafts through trees. The effect works in screen space on top of an existing 3D scene, so its cost is decoupled from scene complexity.

Combines two techniques covered elsewhere in this skill:
- **Volumetric raymarching** (see references/raymarching.md)
- **Custom post-processing effects** (see references/stylized-shaders.md)

## The core challenge: screen-space to world-space

Post-processing runs per screen pixel (2D). Raymarching runs in 3D world space. So we need to reconstruct the 3D world position of each screen pixel using the depth buffer.

### Coordinate systems summary

    Object/Model space  -> modelMatrix         -> World space
    World space         -> viewMatrix          -> View space (camera at origin)
    View space          -> projectionMatrix    -> Clip space
    Clip space          -> /w                  -> NDC (-1..1)
    NDC                 -> * 0.5 + 0.5         -> UV/screen space

### The screen-to-world formula

    vec3 getWorldPosition(vec2 uv, float depth) {
      float clipZ = depth * 2.0 - 1.0;
      vec2 ndc = uv * 2.0 - 1.0;
      vec4 clip = vec4(ndc, clipZ, 1.0);

      vec4 view = projectionMatrixInverse * clip;
      vec4 world = viewMatrixInverse * view;

      return world.xyz / world.w;
    }

Important: matrix multiplication is **not commutative**. Order matters. It is always projectionInverse * clip, then viewMatrixInverse * view. Reverse them and you get garbage.

## Volumetric lighting effect class

    import { Effect, EffectAttribute } from 'postprocessing';

    class VolumetricLightingEffectImpl extends Effect {
      constructor(
        cameraFar = 500,
        projectionMatrixInverse = new THREE.Matrix4(),
        viewMatrixInverse = new THREE.Matrix4(),
        cameraPosition = new THREE.Vector3(),
        lightDirection = new THREE.Vector3(),
        lightPosition = new THREE.Vector3(),
        coneAngle = 40.0
      ) {
        const uniforms = new Map([
          ['cameraFar',               new THREE.Uniform(cameraFar)],
          ['projectionMatrixInverse', new THREE.Uniform(projectionMatrixInverse)],
          ['viewMatrixInverse',       new THREE.Uniform(viewMatrixInverse)],
          ['cameraPosition',          new THREE.Uniform(cameraPosition)],
          ['lightDirection',          new THREE.Uniform(lightDirection)],
          ['lightPosition',           new THREE.Uniform(lightPosition)],
          ['coneAngle',               new THREE.Uniform(coneAngle)],
        ]);

        super('VolumetricLightingEffect', fragmentShader, {
          attributes: EffectAttribute.DEPTH,
          uniforms,
        });
        this.uniforms = uniforms;
      }

      update(_renderer, _inputBuffer, _deltaTime) {
        this.uniforms.get('projectionMatrixInverse').value = this.projectionMatrixInverse;
        this.uniforms.get('viewMatrixInverse').value = this.viewMatrixInverse;
        this.uniforms.get('cameraPosition').value = this.cameraPosition;
      }
    }

Key move: EffectAttribute.DEPTH makes depthBuffer sampler automatically available in your fragment shader.

## Volumetric raymarching fragment shader

    uniform float cameraFar;
    uniform mat4 projectionMatrixInverse;
    uniform mat4 viewMatrixInverse;
    uniform vec3 cameraPosition;
    uniform vec3 lightDirection;
    uniform vec3 lightPosition;
    uniform float coneAngle;

    #define NUM_STEPS 64
    #define STEP_SIZE 0.5

    void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
      float depth = readDepth(depthBuffer, uv);
      vec3 worldPos = getWorldPosition(uv, depth);

      vec3 rayOrigin = cameraPosition;
      vec3 rayDir = normalize(worldPos - rayOrigin);
      vec3 lightPos = lightPosition;
      vec3 lightDir = normalize(lightDirection);

      float coneAngleRad = radians(coneAngle);
      float halfCone = coneAngleRad * 0.5;

      float fogAmount = 0.0;
      float lightIntensity = 1.0;
      float t = STEP_SIZE;

      for (int i = 0; i < NUM_STEPS; i++) {
        vec3 samplePos = rayOrigin + rayDir * t;
        if (t > cameraFar) break;

        float rayDepth = length(samplePos - rayOrigin);
        if (rayDepth > length(worldPos - rayOrigin)) break;

        vec3 toSample = normalize(samplePos - lightPos);
        float cosAngle = dot(toSample, lightDir);
        if (cosAngle < cos(halfCone)) {
          t += STEP_SIZE;
          continue;
        }

        float distToLight = length(samplePos - lightPos);
        float attenuation = exp(-0.05 * distToLight);
        fogAmount += attenuation * lightIntensity;

        t += STEP_SIZE;
      }

      vec3 litColor = inputColor.rgb + vec3(fogAmount * 0.02);
      outputColor = vec4(litColor, 1.0);
    }

### Depth-based stopping (critical)
Without the depth check, light shines through solid walls. Always compare the current ray distance against the geometry depth at that screen pixel -- stop raymarching if you have passed behind something visible.

### Shadow mapping
For light that respects scene geometry (god rays blocked by objects), transform each sample point into light space using the light's projection/view matrices, then sample the shadow map. If the sample is in shadow, do not accumulate. This is identical to classic shadow-mapped lighting, just done in the raymarching loop.

### Multiple lights
Wrap the accumulation loop in an outer loop over your lights. Keep the number of lights reasonable -- cost is NUM_STEPS * NUM_LIGHTS * screen_pixels.

## Performance

This technique is expensive. Typical mitigations:

- **Half-res rendering** -- render the volumetric pass at 0.5x resolution, upsample to screen. Volumetric detail is low-frequency so the upsampling is invisible.
- **Dither ray starting positions** -- blue noise offset so the stepping artefacts are hidden, letting you drop to 32 steps without visible banding.
- **Skip far rays** -- if the full scene depth at this pixel is close, there is no point stepping past it.
- **Distance culling** -- if the light source is off-screen and its cone does not intersect the view frustum, skip the effect for that pixel.

## Passing the camera matrices
Remember to keep the uniforms synced each frame -- the camera moves, so projectionMatrixInverse and matrixWorld need updating:

    <EffectComposer>
      <VolumetricLighting
        cameraFar={camera.far}
        projectionMatrixInverse={camera.projectionMatrixInverse}
        viewMatrixInverse={camera.matrixWorld}
        cameraPosition={camera.position}
        lightPosition={lightRef.current.position}
        lightDirection={/* light's target - position */}
        coneAngle={30}
      />
    </EffectComposer>

The update method on the Effect class is where you copy these into the uniforms each frame.
