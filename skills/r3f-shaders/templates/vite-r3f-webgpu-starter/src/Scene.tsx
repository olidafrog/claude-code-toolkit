import { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import { Mesh } from 'three';
import { uniform, Fn, positionLocal, vec3, cnoise, add } from 'three/tsl';
import { useControls } from 'leva';

export default function Scene() {
  const meshRef = useRef<Mesh>(null!);

  const { color, rotationSpeed, displacement } = useControls({
    color: '#ff6b9d',
    rotationSpeed: { value: 0.3, min: 0, max: 3 },
    displacement: { value: 0.2, min: 0, max: 1 },
  });

  const { nodes, uniforms } = useMemo(() => {
    const time = uniform(0.0);
    const displacementAmount = uniform(0.2);

    const positionNode = Fn(() => {
      const pos = positionLocal;
      const noise = cnoise(vec3(pos).add(vec3(time))).mul(displacementAmount);
      return add(pos, noise);
    })();

    return {
      nodes: { positionNode },
      uniforms: { time, displacementAmount },
    };
  }, []);

  useFrame((state) => {
    const t = state.clock.getElapsedTime();
    uniforms.time.value = t;
    uniforms.displacementAmount.value = displacement;
    meshRef.current.rotation.y = t * rotationSpeed;
  });

  return (
    <>
      <ambientLight intensity={0.3} />
      <directionalLight position={[5, 10, 5]} intensity={2} castShadow />

      <mesh ref={meshRef} castShadow receiveShadow>
        <icosahedronGeometry args={[1, 60]} />
        {/* @ts-expect-error meshStandardNodeMaterial isnt typed in JSX yet */}
        <meshStandardNodeMaterial
          color={color}
          metalness={0.3}
          roughness={0.4}
          positionNode={nodes.positionNode}
        />
      </mesh>

      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -1.5, 0]} receiveShadow>
        <planeGeometry args={[20, 20]} />
        {/* @ts-expect-error */}
        <meshStandardNodeMaterial color='#222' />
      </mesh>
    </>
  );
}
