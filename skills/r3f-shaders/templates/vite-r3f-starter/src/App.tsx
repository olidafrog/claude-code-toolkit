import { Canvas } from '@react-three/fiber';
import { OrbitControls, Environment, Stats } from '@react-three/drei';
import { Suspense } from 'react';
import Scene from './Scene';

export default function App() {
  return (
    <Canvas
      shadows
      dpr={[1, 2]}
      camera={{ position: [3, 2, 5], fov: 50 }}
      gl={{ antialias: true }}
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
