import { Canvas } from '@react-three/fiber';
import { OrbitControls, Environment, Stats } from '@react-three/drei';
import { Suspense } from 'react';
import * as THREE from 'three/webgpu';
import Scene from './Scene';

export default function App() {
  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: [3, 2, 5], fov: 50 }}
      gl={async (props) => {
        const renderer = new THREE.WebGPURenderer({
          ...props,
          antialias: true,
          forceWebGL: false,
        });
        await renderer.init();
        return renderer;
      }}
    >
      <Suspense fallback={null}>
        <Scene />
        <Environment preset='studio' />
        <OrbitControls makeDefault enableDamping />
      </Suspense>
      <Stats />
    </Canvas>
  );
}
