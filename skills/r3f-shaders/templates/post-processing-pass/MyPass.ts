import { Pass, FullScreenQuad } from 'postprocessing';
import * as THREE from 'three';
import vertexShader from './pass.vert';
import fragmentShader from './pass.frag';

interface PassArgs {
  depthRenderTarget?: THREE.WebGLRenderTarget;
  normalRenderTarget?: THREE.WebGLRenderTarget;
  camera?: THREE.Camera;
}

export class MyPass extends Pass {
  material: THREE.ShaderMaterial;
  fsQuad: FullScreenQuad;

  constructor({ depthRenderTarget, normalRenderTarget, camera }: PassArgs) {
    super();

    this.material = new THREE.ShaderMaterial({
      vertexShader,
      fragmentShader,
      uniforms: {
        tDiffuse:    { value: null },                      // input from prev pass -- auto-filled in render()
        tDepth:      { value: depthRenderTarget?.depthTexture ?? null },
        tNormal:     { value: normalRenderTarget?.texture ?? null },
        resolution:  { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
        cameraNear:  { value: (camera as THREE.PerspectiveCamera)?.near ?? 0.1 },
        cameraFar:   { value: (camera as THREE.PerspectiveCamera)?.far ?? 1000 },
        outlineThickness: { value: 2.0 },
      },
    });

    this.fsQuad = new FullScreenQuad(this.material);
  }

  dispose() {
    this.material.dispose();
    this.fsQuad.dispose();
  }

  render(
    renderer: THREE.WebGLRenderer,
    writeBuffer: THREE.WebGLRenderTarget,
    readBuffer: THREE.WebGLRenderTarget,
  ) {
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
