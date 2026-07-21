import { useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { Mesh } from 'three';
import { useControls } from 'leva';

export default function Scene() {
  const meshRef = useRef<Mesh>(null!);

  const { color, rotationSpeed, metalness, roughness } = useControls({
    color: '#ff6b9d',
    rotationSpeed: { value: 0.5, min: 0, max: 3 },
    metalness: { value: 0.5, min: 0, max: 1 },
    roughness: { value: 0.3, min: 0, max: 1 },
  });

  useFrame((state) => {
    const t = state.clock.getElapsedTime();
    meshRef.current.rotation.y = t * rotationSpeed;
  });

  return (
    <>
      <ambientLight intensity={0.3} />
      <directionalLight position={[5, 10, 5]} intensity={2} castShadow />

      <mesh ref={meshRef} castShadow receiveShadow>
        <boxGeometry args={[1, 1, 1]} />
        <meshStandardMaterial color={color} metalness={metalness} roughness={roughness} />
      </mesh>

      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.5, 0]} receiveShadow>
        <planeGeometry args={[20, 20]} />
        <meshStandardMaterial color='#222' />
      </mesh>
    </>
  );
}
