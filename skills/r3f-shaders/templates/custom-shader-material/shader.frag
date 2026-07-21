uniform float u_time;
uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform vec3 u_color;

varying vec2 vUv;
varying vec3 vNormal;
varying vec3 vPosition;

void main() {
  vec2 uv = vUv;

  // Mouse-aware radial gradient -- starter pattern, replace with your effect
  float d = distance(uv, u_mouse);
  float ring = smoothstep(0.3, 0.28, d) - smoothstep(0.2, 0.18, d);

  vec3 color = u_color * (0.5 + 0.5 * sin(u_time + uv.x * 6.28));
  color = mix(color, vec3(1.0), ring);

  gl_FragColor = vec4(color, 1.0);
}
