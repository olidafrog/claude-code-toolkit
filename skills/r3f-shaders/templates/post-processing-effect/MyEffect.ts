import { Effect } from 'postprocessing';
import { Uniform } from 'three';
import fragmentShader from './effect.frag';

export class MyEffectImpl extends Effect {
  constructor({ intensity = 1.0 }: { intensity?: number } = {}) {
    super('MyEffect', fragmentShader, {
      uniforms: new Map<string, Uniform>([
        ['intensity', new Uniform(intensity)],
      ]),
    });
  }
}

// Wrap for JSX usage:
import { wrapEffect } from '@react-three/postprocessing';
export const MyEffect = wrapEffect(MyEffectImpl);
