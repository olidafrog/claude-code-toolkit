# Light Effects & Render Targets

Consolidated from: Refraction, Dispersion & Other Shader Light Effects (2023), Beautiful & Mind-Bending WebGL Render Targets (2023), Shining a Light on Caustics (2024), On Shaping Light (2025).

## Render targets -- the most important tool

A WebGLRenderTarget (FBO) lets you render any scene to an offscreen buffer, then use that buffer's pixel data as a texture in another shader. It's the foundation of post-processing, transparency, portals, caustics, GPGPU particles -- essentially every advanced effect.

### Setup in R3F

Always use useFBO from drei. Never manually instantiate WebGLRenderTarget unless you need specific options:

    import { useFBO } from '@react-three/drei';

    const renderTarget = useFBO();
    const renderTarget = useFBO(2000, 2000, {
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      format: THREE.RGBAFormat,
      type: THREE.FloatType,
      stencilBuffer: false,
    });

### Canonical render-to-texture pattern

Every render-target effect follows this shape inside useFrame:

    useFrame(({ gl, scene, camera }) => {
      gl.setRenderTarget(renderTarget);
      gl.render(scene, camera);
      mesh.current.material.uniforms.uTexture.value = renderTarget.texture;
      gl.setRenderTarget(null);
    });

### The transparent mesh trick

To make any mesh appear transparent (and then apply refraction/dispersion/caustics to the passthrough image):

1. Set mesh.visible = false
2. Render the surrounding scene to an FBO
3. Feed the FBO texture into the mesh's shader
4. Set mesh.visible = true
5. In the fragment shader, sample the texture using **screen coordinates** (not UVs): vec2 uv = gl_FragCoord.xy / winResolution.xy

Crucial: multiply winResolution by the device pixel ratio. Also cap DPR to 2 on <Canvas dpr={[1, 2]}>.

## UV coordinates vs screen coordinates

This distinction shapes every shader-based rendering decision:

- **UV coordinates** (vUv) -- map the texture *onto* the geometry, stretched to fit. Use when you want the texture to act as a surface of the mesh (portal effect, decal).
- **Screen coordinates** (gl_FragCoord.xy / winResolution.xy) -- map the texture *as if projected from the screen*, revealing what's behind the mesh at that pixel. Use for transparency, lensing, post-processing.

    // UV mapping
    vec4 color = texture2D(uTexture, vUv);

    // Screen coordinates
    uniform vec2 winResolution;
    vec4 color = texture2D(uTexture, gl_FragCoord.xy / winResolution.xy);

## Tone mapping + colorspace (essential post-processing fix)

Any custom shader that samples an FBO texture will render darker/off by default because the FBO outputs are linear and the render is sRGB. Always include these at the end of your fragment main():

    #include <tonemapping_fragment>
    #include <colorspace_fragment>

Without these, your colours will look muddy after any FBO pass.

## Refraction (bending light)

GLSL has a built-in refract(incident, normal, iorRatio) function. To use it you need:

1. eyeVector -- vector from camera to surface, computed in the **vertex shader**:

       vec4 worldPos = modelMatrix * vec4(position, 1.0);
       eyeVector = normalize(worldPos.xyz - cameraPosition);

2. worldNormal -- surface normal in world space:

       worldNormal = normalize(normalMatrix * normal);

3. IOR ratio. Common values: water 1.33, glass 1.5, diamond 2.42.

In the fragment shader, sample the background texture with the refraction offset:

    vec3 refractVec = refract(eyeVector, worldNormal, 1.0 / 1.31);
    vec4 color = texture2D(uTexture, gl_FragCoord.xy / winResolution.xy + refractVec.xy);

## Chromatic dispersion (rainbow glass)

Real dispersion happens because IOR varies with wavelength. Fake it by refracting each RGB channel with its own IOR:

    vec3 refractR = refract(eyeVector, normal, 1.0 / uIorR);
    vec3 refractG = refract(eyeVector, normal, 1.0 / uIorG);
    vec3 refractB = refract(eyeVector, normal, 1.0 / uIorB);

    float R = texture2D(uTexture, uv + refractR.xy).r;
    float G = texture2D(uTexture, uv + refractG.xy).g;
    float B = texture2D(uTexture, uv + refractB.xy).b;

For smoother dispersion, iterate N times (samples) with progressive offsets -- this is the Junni technique:

    for (int i = 0; i < LOOP; i++) {
      float slide = float(i) / float(LOOP) * 0.1;
      color.r += texture2D(uTexture, uv + refractR.xy * (uRefractPower + slide * 1.0) * uChromaticAberration).r;
      color.g += texture2D(uTexture, uv + refractG.xy * (uRefractPower + slide * 2.0) * uChromaticAberration).g;
      color.b += texture2D(uTexture, uv + refractB.xy * (uRefractPower + slide * 3.0) * uChromaticAberration).b;
    }
    color /= float(LOOP);

Watch performance: each extra sample is an extra texture lookup per pixel.

### Saturation boost
After dispersion, colours tend to look washed out. Bring saturation back with the luminance trick:

    vec3 sat(vec3 rgb, float intensity) {
      vec3 L = vec3(0.2125, 0.7154, 0.0721);
      vec3 grayscale = vec3(dot(rgb, L));
      return mix(grayscale, rgb, intensity);
    }

### Extending to 6 channels (rygcbv)
For even more colourful dispersion, split RGB into 6 channels (Red, Yellow, Green, Cyan, Blue, Violet) via Fourier interpolation -- each with its own IOR:

    r = R/2,  y = (2R + 2G - B)/6
    g = G/2,  c = (2G + 2B - R)/6
    b = B/2,  v = (2B + 2R - G)/6

Then return to RGB:

    R = r + (2v + 2y - c)/3
    G = g + (2y + 2c - v)/3
    B = b + (2c + 2v - y)/3

## Lighting: Blinn-Phong (specular + diffuse + fresnel)

For any transparent/glossy material, add these three light terms:

    float specular(vec3 light, float shininess, float diffuseness) {
      vec3 lightVector = normalize(-light);
      vec3 halfVector = normalize(eyeVector + lightVector);
      float NdotL = dot(worldNormal, lightVector);
      float NdotH = dot(worldNormal, halfVector);
      float NdotH2 = NdotH * NdotH;
      float kDiffuse = max(0.0, NdotL);
      float kSpecular = pow(NdotH2, shininess);
      return kSpecular + kDiffuse * diffuseness;
    }

    float fresnel(vec3 eyeVector, vec3 worldNormal, float power) {
      float f = abs(dot(eyeVector, worldNormal));
      return pow(1.0 - f, power);
    }

Fresnel mimics real-world behaviour: glass reflects more when viewed at an angle, less when viewed head-on. Always add a Fresnel pass on transparent meshes -- it sells the glass/crystal look.

## Multi-side rendering (frontside + backside dispersion)

For dispersion that looks truly glass-like, render both sides:

    useFrame(({ gl, scene, camera }) => {
      mesh.current.visible = false;

      gl.setRenderTarget(backRenderTarget);
      gl.render(scene, camera);
      mesh.current.material.uniforms.uTexture.value = backRenderTarget.texture;
      mesh.current.material.side = THREE.BackSide;
      mesh.current.visible = true;

      gl.setRenderTarget(mainRenderTarget);
      gl.render(scene, camera);
      mesh.current.material.uniforms.uTexture.value = mainRenderTarget.texture;
      mesh.current.material.side = THREE.FrontSide;

      gl.setRenderTarget(null);
    });

This creates the beautiful dispersion-inside-dispersion effect -- the backside's specular becomes refracted/dispersed through the frontside.

## Caustics (light swirls through glass/water)

Caustics are the beautiful light patterns that form when rays pass through a curved transmissive surface and converge. True caustics require raytracing; the WebGL approach (Evan Wallace's technique) simulates them:

### Pipeline
1. **Normal extraction**: render the target mesh with a NormalMaterial to an FBO, using a camera positioned *at the light source* and looking at the mesh. Lock camera.up = new Vector3(0, 1, 0) to prevent weird rotations.
2. **Caustic computation**: in a fragment shader running on a FullScreenQuad, read the normal texture, compute refracted rays, and compare pre/post-refraction surface areas using dFdx/dFdy:

       uniform sampler2D uTexture;
       uniform vec3 uLight;
       varying vec3 vPosition;
       varying vec2 vUv;

       void main() {
         vec3 normal = normalize(texture2D(uTexture, vUv).rgb);
         vec3 lightDir = normalize(uLight);
         vec3 ray = refract(lightDir, normal, 1.0 / 1.25);

         vec3 newPos = vPosition.xyz + ray;
         vec3 oldPos = vPosition.xyz;

         float lightArea    = length(dFdx(oldPos)) * length(dFdy(oldPos));
         float newLightArea = length(dFdx(newPos)) * length(dFdy(newPos));

         float value = lightArea / newLightArea;
         float scale = clamp(value, 0.0, 1.0) * uIntensity;
         scale *= scale;

         gl_FragColor = vec4(vec3(scale), 1.0);
       }

3. **Project the caustic texture** onto the receiving plane (the ground under your object).

Key gotcha: always clamp the value to [0, 1] or it'll render incorrectly when viewed through MeshTransmissionMaterial.

## Portal scene / scene within a scene

The most versatile render-target trick. Use createPortal to render an offscreen scene, then map its texture onto a mesh:

    const Scene = () => {
      const mesh = useRef();
      const otherCamera = useRef();
      const otherScene = useMemo(() => new THREE.Scene(), []);
      const renderTarget = useFBO();

      useFrame(({ gl }) => {
        gl.setRenderTarget(renderTarget);
        gl.render(otherScene, otherCamera.current);
        mesh.current.material.map = renderTarget.texture;
        gl.setRenderTarget(null);
      });

      return (
        <>
          <PerspectiveCamera manual ref={otherCamera} aspect={1.5/1} />
          <mesh ref={mesh}>
            <planeGeometry args={[3, 2]} />
            <meshBasicMaterial />
          </mesh>
          {createPortal(
            <mesh><sphereGeometry args={[1, 64]} /><meshBasicMaterial /></mesh>,
            otherScene
          )}
        </>
      );
    };

For parallax mimicking, copy the main camera's matrix into the portal camera:

    otherCamera.current.matrixWorldInverse.copy(camera.matrixWorldInverse);

### Drei shortcut
If you do not need the fine control, drei provides <RenderTexture attach='map'> that wraps all this:

    <meshBasicMaterial>
      <RenderTexture attach='map'>
        <PerspectiveCamera makeDefault manual aspect={1.5/1} />
        <mesh>...</mesh>
      </RenderTexture>
    </meshBasicMaterial>

## Custom post-processing pipeline

As an alternative to EffectComposer, use render targets + fullscreen triangles. Can be clearer and faster for custom chains:

    const getFullscreenTriangle = () => {
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute([-1,-1, 3,-1, -1,3], 2));
      g.setAttribute('uv', new THREE.Float32BufferAttribute([0,0, 2,0, 0,2], 2));
      return g;
    };

Use one render target per effect, chain them: render scene -> RT1, apply effect1 to RT1 -> RT2, apply effect2 to RT2 -> screen.

## Transition between scenes (noise reveal)

Mix two scene textures via Perlin noise and a progress uniform:

    uniform sampler2D textureA;
    uniform sampler2D textureB;
    uniform float uProgress;
    varying vec2 vUv;

    void main() {
      vec4 colorA = texture2D(textureA, vUv);
      vec4 colorB = texture2D(textureB, vUv);
      float noise = clamp(cnoise(vUv * 2.5) + uProgress * 2.0, 0.0, 1.0);
      gl_FragColor = mix(colorA, colorB, noise);
    }

Perf tip: ping-pong the two scene renders (alternate frames, not both each frame).

## Optical illusion lens / magnifier trick

Swap materials/visibility in the render loop to show different states through a mesh:

    useFrame(({ gl }) => {
      const oldMatA = meshA.current.material;

      meshMain.current.visible = false;
      meshA.current.material = wireframeMaterial;

      gl.setRenderTarget(renderTarget);
      gl.render(scene, camera);
      lensMesh.current.material.uniforms.uTexture.value = renderTarget.texture;

      meshMain.current.visible = true;
      meshA.current.material = oldMatA;

      gl.setRenderTarget(null);
    });

Pair with MeshTransmissionMaterial (drei) and its buffer prop for a beautiful lens look.

## Performance watchouts
- Every render target is a full re-render of the scene. Each additional FBO roughly doubles the render cost.
- Ping-pong (A frame renders texture A, B frame renders texture B) to avoid double-rendering per frame.
- Use useFBO(w, h, opts) with a lower-resolution target when the output does not need to be pixel-perfect.
- For transparent meshes, you MUST match the FBO resolution with the screen DPR, or the refraction will look wrong.
