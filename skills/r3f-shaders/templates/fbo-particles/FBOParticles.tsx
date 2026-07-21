import { useRef, useMemo } from 'react';
import { createPortal, useFrame, extend } from '@react-three/fiber';
import { useFBO } from '@react-three/drei';
import * as THREE from 'three';
import { SimulationMaterial } from './SimulationMaterial';
import renderVertex from './render.vert';
import renderFragment from './render.frag';

extend({ SimulationMaterial });

const SIZE = 128; // 128x128 = 16384 particles. 256 = 65k. 512 = 262k.

export default function FBOParticles() {
  const points = useRef<THREE.Points>(null!);
  const simRef = useRef<SimulationMaterial>(null!);

  const { scene, camera, squarePositions, squareUvs, particleUvs } = useMemo(() => {
    const scene = new THREE.Scene();
    const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 1 / Math.pow(2, 53), 1);

    const squarePositions = new Float32Array([-1,-1,0, 1,-1,0, 1,1,0, -1,-1,0, 1,1,0, -1,1,0]);
    const squareUvs = new Float32Array([0,0, 1,0, 1,1, 0,0, 1,1, 0,1]);

    const particleUvs = new Float32Array(SIZE * SIZE * 3);
    for (let i = 0; i < SIZE * SIZE; i++) {
      particleUvs[i * 3]     = (i % SIZE) / SIZE;
      particleUvs[i * 3 + 1] = Math.floor(i / SIZE) / SIZE;
    }

    return { scene, camera, squarePositions, squareUvs, particleUvs };
  }, []);

  const renderTarget = useFBO(SIZE, SIZE, {
    minFilter: THREE.NearestFilter,
    magFilter: THREE.NearestFilter,
    format: THREE.RGBAFormat,
    type: THREE.FloatType,        // critical for positional precision
    stencilBuffer: false,
  });

  const uniforms = useMemo(() => ({ uPositions: { value: null } }), []);

  useFrame(({ gl, clock }) => {
    gl.setRenderTarget(renderTarget);
    gl.clear();
    gl.render(scene, camera);
    gl.setRenderTarget(null);

    // @ts-ignore
    points.current.material.uniforms.uPositions.value = renderTarget.texture;
    simRef.current.uniforms.uTime.value = clock.elapsedTime;
  });

  return (
    <>
      {createPortal(
        <mesh>
          {/* @ts-ignore extended */}
          <simulationMaterial ref={simRef} args={[SIZE]} />
          <bufferGeometry>
            <bufferAttribute attach='attributes-position' count={squarePositions.length / 3} array={squarePositions} itemSize={3} />
            <bufferAttribute attach='attributes-uv' count={squareUvs.length / 2} array={squareUvs} itemSize={2} />
          </bufferGeometry>
        </mesh>,
        scene,
      )}

      <points ref={points}>
        <bufferGeometry>
          <bufferAttribute attach='attributes-position' count={particleUvs.length / 3} array={particleUvs} itemSize={3} />
        </bufferGeometry>
        <shaderMaterial
          blending={THREE.AdditiveBlending}
          depthWrite={false}
          transparent
          vertexShader={renderVertex}
          fragmentShader={renderFragment}
          uniforms={uniforms}
        />
      </points>
    </>
  );
}
