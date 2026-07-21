uniform sampler2D positions;
uniform float uTime;
uniform float uFrequency;
varying vec2 vUv;

// --- Paste your favourite curlNoise(vec3) here ---
// Maxime uses this pattern with a curl-noise glsl include
vec3 curlNoise(vec3 p) {
  // Placeholder: swap for real curl noise from a glsl noise package
  return vec3(sin(p.y), sin(p.z), sin(p.x)) * 0.01;
}

void main() {
  vec3 pos = texture2D(positions, vUv).rgb;
  vec3 curl = curlNoise(pos * uFrequency + uTime * 0.1);
  pos += curl;
  gl_FragColor = vec4(pos, 1.0);
}
