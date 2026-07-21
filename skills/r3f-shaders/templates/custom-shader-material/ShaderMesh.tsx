import { useRef, useMemo } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import { ShaderMaterial, Vector2 } from 'three';
import vertexShader from './shader.vert';
import fragmentShader from './shader.frag';

interface Props {
  // Pass any extra uniforms as props; they get merged into the uniforms object
  color?: string;
}

export default function ShaderMesh({ color = '#ff6b9d' }: Props) {
  const materialRef = useRef<ShaderMaterial>(null!);
  const { size } = useThree();

  // CRITICAL: memoise uniforms or the material freezes on re-render
  const uniforms = useMemo(
    () => ({
      u_time:       { value: 0 },
      u_resolution: { value: new Vector2(size.width, size.height) },
      u_mouse:      { value: new Vector2(0.5, 0.5) },
      u_color:      { value: [1, 0.42, 0.62] },
    }),
    [], // eslint-disable-line react-hooks/exhaustive-deps
  );

  useFrame(({ clock, pointer }) => {
    materialRef.current.uniforms.u_time.value = clock.getElapsedTime();
    materialRef.current.uniforms.u_mouse.value.set(
      pointer.x * 0.5 + 0.5,
      pointer.y * 0.5 + 0.5,
    );
  });

  return (
    <mesh>
      <planeGeometry args={[2, 2, 64, 64]} />
      <shaderMaterial
        ref={materialRef}
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
      />
    </mesh>
  );
}
