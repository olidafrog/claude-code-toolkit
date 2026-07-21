# Raymarching & Volumetric Rendering

Consolidated from: Painting with Math: A Gentle Study of Raymarching (2023), Real-time Dreamy Cloudscapes with Volumetric Raymarching (2023).

## When to reach for raymarching

Raymarching is an alternative to rasterisation. Instead of rendering geometries with meshes/materials, you describe the scene with **Signed Distance Functions (SDFs)** -- mathematical functions that return the distance from a point to the surface of an object. Use raymarching for:

- Organic, blob-like, or fluid shapes that would need millions of vertices to rasterise
- Fractals and infinite repetition (cheap with modulo)
- Volumetric effects (clouds, smoke, god rays, fog)
- Fully procedural worlds with no geometry budget

Do not use raymarching for standard modelling work -- rasterisation is dramatically more efficient for solid, polygonal objects.

## The setup: a fullscreen plane as canvas

Raymarched scenes typically render onto a single fullscreen plane in R3F:

    const DPR = 0.75;

    const SDFCanvas = () => {
      const mesh = useRef();
      const { viewport } = useThree();

      const uniforms = {
        uTime: new THREE.Uniform(0.0),
        uResolution: new THREE.Uniform(new THREE.Vector2()),
      };

      useFrame((state) => {
        mesh.current.material.uniforms.uTime.value = state.clock.getElapsedTime();
        mesh.current.material.uniforms.uResolution.value = new THREE.Vector2(
          window.innerWidth * DPR,
          window.innerHeight * DPR
        );
      });

      return (
        <mesh ref={mesh} scale={[viewport.width, viewport.height, 1]}>
          <planeGeometry args={[1, 1]} />
          <shaderMaterial
            fragmentShader={fragmentShader}
            vertexShader={vertexShader}
            uniforms={uniforms}
          />
        </mesh>
      );
    };

### UV normalisation preamble (always in the fragment shader)

    void main() {
      vec2 uv = vUv;
      uv -= 0.5;
      uv.x *= uResolution.x / uResolution.y;
    }

## The raymarching algorithm

Start with these three constants:

    #define MAX_STEPS 100
    #define MAX_DIST 100.0
    #define SURFACE_DIST 0.01

The main loop: march from rayOrigin in rayDirection, stepping forward by the SDF each iteration. Stop when you are close enough to a surface or have gone too far:

    float raymarch(vec3 ro, vec3 rd) {
      float d0 = 0.0;
      for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * d0;
        float dS = scene(p);
        d0 += dS;
        if (d0 > MAX_DIST || dS < SURFACE_DIST) break;
      }
      return d0;
    }

    void main() {
      vec3 ro = vec3(0.0, 0.0, 5.0);
      vec3 rd = normalize(vec3(uv, -1.0));
      float d = raymarch(ro, rd);
    }

## Basic SDFs

Inigo Quilez's SDF library is the canonical reference. Start with:

    float sdSphere(vec3 p, float r) {
      return length(p) - r;
    }

    float sdBox(vec3 p, vec3 b) {
      vec3 q = abs(p) - b;
      return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
    }

    float sdTorus(vec3 p, vec2 t) {
      vec2 q = vec2(length(p.xz) - t.x, p.y);
      return length(q) - t.y;
    }

    float sdPlane(vec3 p) {
      return p.y;
    }

## SDF operations (the combinatorial magic)

### Union -- render multiple objects

    float scene(vec3 p) {
      return min(sdSphere(p, 1.0), sdPlane(p));
    }

### Intersection (CSG)

    return max(sdA(p), sdB(p));

### Smooth union (liquid/organic blending)

    float smoothmin(float a, float b, float k) {
      float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
      return mix(b, a, h) - k * h * (1.0 - h);
    }

This is the technique that makes multiple spheres blend like mercury or a lava lamp. Tune k to control softness.

### Transform: move, rotate, scale
SDFs work in an inverted way -- you transform the sampling point, not the object:

    float d = sdSphere(p - vec3(0.0, 1.0, 0.0), 1.0);

    vec3 p1 = rotateY(p, uTime);
    float d = sdSphere(p1, 1.0);

    float d = sdSphere(p / scale, 1.0) * scale;

### Infinite repetition

    vec3 q = mod(p + 0.5 * c, c) - 0.5 * c;
    float d = sdSphere(q, 0.5);

## Lighting raymarched scenes

Unlike rasterised meshes, you must compute normals yourself. Standard approach (4 extra SDF samples per pixel):

    vec3 getNormal(vec3 p) {
      vec2 e = vec2(0.01, 0.0);
      vec3 n = scene(p) - vec3(
        scene(p - e.xyy),
        scene(p - e.yxy),
        scene(p - e.yyx)
      );
      return normalize(n);
    }

Then classic Lambertian diffuse:

    vec3 normal = getNormal(p);
    vec3 lightDir = normalize(lightPos - p);
    float diffuse = max(dot(normal, lightDir), 0.0);
    vec3 color = materialColor * diffuse;

### Soft shadows (Inigo Quilez)

    float softshadow(vec3 ro, vec3 rd, float mint, float maxt, float k) {
      float res = 1.0;
      float t = mint;
      for (int i = 0; i < 256 && t < maxt; i++) {
        float h = scene(ro + rd * t);
        if (h < 0.001) return 0.0;
        res = min(res, k * h / t);
        t += h;
      }
      return res;
    }

Higher k -> sharper shadows. Usual value 8 to 32.

## Volumetric raymarching (clouds, smoke, fog)

The same algorithm, two critical tweaks:

1. **March with a constant step size** -- do not use the SDF to step, step uniformly through the volume
2. **SDF returns density, not distance** -- typically -sdSurface(p) (positive inside the object) plus FBM noise

    #define MAX_STEPS 100
    const float MARCH_SIZE = 0.08;

    float scene(vec3 p) {
      float sphere = sdSphere(p, 1.0);
      float f = fbm(p);
      return -sphere + f;
    }

    vec4 volumetricRaymarch(vec3 ro, vec3 rd) {
      float depth = 0.0;
      vec3 p = ro + depth * rd;
      vec4 res = vec4(0.0);

      for (int i = 0; i < MAX_STEPS; i++) {
        float density = scene(p);

        if (density > 0.0) {
          vec4 color = vec4(mix(vec3(1.0), vec3(0.0), density), density);
          color.rgb *= color.a;
          res += color * (1.0 - res.a);
        }

        depth += MARCH_SIZE;
        p = ro + depth * rd;
      }
      return res;
    }

### Cloud noise function
Standard volumetric noise function (seen across many Shadertoy demos):

    float noise(vec3 x) {
      vec3 p = floor(x);
      vec3 f = fract(x);
      vec2 u = f.xy * f.xy * (3.0 - 2.0 * f.xy);

      vec2 uv = (p.xy + vec2(37.0, 239.0) * p.z) + u.xy;
      vec2 tex = textureLod(uNoise, (uv + 0.5) / 256.0, 0.0).yx;

      return mix(tex.x, tex.y, f.z) * 2.0 - 1.0;
    }

    float fbm(vec3 p) {
      vec3 q = p + uTime * 0.5 * vec3(1.0, -0.2, -1.0);
      float f = 0.0;
      float scale = 0.5;
      float factor = 2.02;

      for (int i = 0; i < 6; i++) {
        f += scale * noise(q);
        q *= factor;
        factor += 0.21;
        scale *= 0.5;
      }
      return f;
    }

### Directional-derivative lighting (cheap volumetric diffuse)
For volumes, calculating a full normal is too expensive. Instead, sample density at the current point and at a point offset toward the light (Inigo Quilez's technique):

    float diffuse = clamp(
      (scene(p) - scene(p + 0.3 * sunDirection)) / 0.3,
      0.0, 1.0
    );

    vec3 lin = vec3(0.60, 0.60, 0.75) * 1.1
             + 0.8 * vec3(1.0, 0.6, 0.3) * diffuse;
    vec4 color = vec4(mix(vec3(1.0), vec3(0.0), density), density);
    color.rgb *= lin;
    color.rgb *= color.a;
    res += color * (1.0 - res.a);

Only works with a small number of light sources (sun = 1).

### Morphing clouds between shapes
Mix SDFs over time using a nextStep function for smooth transitions:

    float nextStep(float t, float len, float smo) {
      float tt = mod(t + smo, len);
      float stp = floor(t / len) - 1.0;
      return smoothstep(0.0, smo, tt) + stp;
    }

    float scene(vec3 p) {
      float s1 = sdTorus(p, vec2(1.3, 0.9));
      float s2 = sdCross(p * 2.0, 0.6);
      float s3 = sdSphere(p, 1.5);
      float t = mod(nextStep(uTime, 3.0, 1.2), 4.0);

      float d = mix(s1, s2, clamp(t, 0.0, 1.0));
      d = mix(d, s3, clamp(t - 1.0, 0.0, 1.0));
      d = mix(d, s1, clamp(t - 2.0, 0.0, 1.0));

      return -d + fbm(p);
    }

## Performance optimisation for volumetric scenes

Raymarching performance is roughly MAX_STEPS x pixels x cost_per_step. Four techniques to reclaim FPS:

1. **Half-res rendering** -- render the raymarched pass at 0.5x resolution, then upscale with a light blur. Most cloud detail is low-frequency anyway.
2. **Blue-noise dithering** -- offset each ray's starting point by blue noise to hide the step banding. Lets you use fewer steps without visible artefacts.
3. **Smaller DPR on canvas** -- set <Canvas dpr={0.5}> or lower on volumetric demos.
4. **Adaptive step size** -- step bigger when far from dense areas, smaller near them. Requires extra sampling.

## Sources and heroes
Maxime leans heavily on:
- Inigo Quilez (iquilezles.org) -- SDFs, soft shadows, smoothmin, derivatives
- The Art of Code (YouTube) -- great visual explanations
- Syntopia blog
- SimonDev (YouTube)
- The Book of Shaders

When you are stuck on a raymarching problem, these five sources almost always have the answer.
