import * as THREE from 'three';
import simVertex from './simulation.vert';
import simFragment from './simulation.frag';

function generateInitialPositions(width: number, height: number): Float32Array {
  const length = width * height * 4;
  const data = new Float32Array(length);
  for (let i = 0; i < width * height; i++) {
    const i4 = i * 4;
    // Initialise on sphere surface -- customise as needed
    const r = 1.0;
    const theta = Math.random() * Math.PI * 2;
    const phi = Math.acos(2 * Math.random() - 1);
    data[i4]     = r * Math.sin(phi) * Math.cos(theta);
    data[i4 + 1] = r * Math.sin(phi) * Math.sin(theta);
    data[i4 + 2] = r * Math.cos(phi);
    data[i4 + 3] = 1.0;
  }
  return data;
}

export class SimulationMaterial extends THREE.ShaderMaterial {
  constructor(size: number) {
    const positionsTexture = new THREE.DataTexture(
      generateInitialPositions(size, size),
      size, size,
      THREE.RGBAFormat,
      THREE.FloatType,
    );
    positionsTexture.needsUpdate = true;

    super({
      uniforms: {
        positions: { value: positionsTexture },
        uTime:     { value: 0 },
        uFrequency:{ value: 0.25 },
      },
      vertexShader: simVertex,
      fragmentShader: simFragment,
    });
  }
}
