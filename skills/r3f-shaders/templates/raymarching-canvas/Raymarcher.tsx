import { useRef, useMemo } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import { ShaderMaterial, Vector2 } from 'three';
import vertexShader from './ray.vert';
import fragmentShader from './ray.frag';

export default function Raymarcher() {
  const matRef = useRef<ShaderMaterial>(null!);
  const { viewport } = useThree();

  const uniforms = useMemo(() => ({
    uTime:       { value: 0 },
    uResolution: { value: new Vector2() },
    uMouse:      { value: new Vector2(0.5, 0.5) },
  }), []);

  useFrame(({ clock, pointer, size }) => {
    matRef.current.uniforms.uTime.value = clock.getElapsedTime();
    matRef.current.uniforms.uResolution.value.set(size.width, size.height);
    matRef.current.uniforms.uMouse.value.set(
      pointer.x * 0.5 + 0.5,
      pointer.y * 0.5 + 0.5,
    );
  });

  return (
    <mesh scale={[viewport.width, viewport.height, 1]}>
      <planeGeometry args={[1, 1]} />
      <shaderMaterial
        ref={matRef}
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
      />
    </mesh>
  );
}
