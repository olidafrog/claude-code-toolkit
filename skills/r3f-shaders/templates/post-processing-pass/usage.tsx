import { useMemo } from 'react';
import { useFrame, useThree, extend } from '@react-three/fiber';
import { Effects, useFBO } from '@react-three/drei';
import * as THREE from 'three';
import { MyPass } from './MyPass';

extend({ MyPass });

export function ScenePasses() {
  const { camera } = useThree();

  // Depth render target with dedicated DepthTexture
  const depthTexture = useMemo(
    () => new THREE.DepthTexture(window.innerWidth, window.innerHeight),
    [],
  );
  const depthRT = useFBO(window.innerWidth, window.innerHeight, {
    depthTexture,
    depthBuffer: true,
  });

  // Normal render target (override whole scene's material)
  const normalRT = useFBO();
  const normalMaterial = useMemo(() => new THREE.MeshNormalMaterial(), []);

  useFrame(({ gl, scene }) => {
    // Capture depth
    gl.setRenderTarget(depthRT);
    gl.render(scene, camera);

    // Capture normals via scene.overrideMaterial
    const original = scene.overrideMaterial;
    scene.overrideMaterial = normalMaterial;
    gl.setRenderTarget(normalRT);
    gl.render(scene, camera);
    scene.overrideMaterial = original;

    gl.setRenderTarget(null);
  });

  return (
    <Effects>
      {/* @ts-expect-error JSX typing for extended class */}
      <myPass args={[{ depthRenderTarget: depthRT, normalRenderTarget: normalRT, camera }]} />
    </Effects>
  );
}
