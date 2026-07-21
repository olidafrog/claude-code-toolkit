import { EffectComposer } from '@react-three/postprocessing';
import { MyEffect } from './MyEffect';

// Drop this inside your <Canvas>:
export function PostEffects() {
  return (
    <EffectComposer>
      <MyEffect intensity={0.8} />
    </EffectComposer>
  );
}
