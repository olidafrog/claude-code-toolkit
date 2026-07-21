void main() {
  float d = distance(gl_PointCoord, vec2(0.5));
  float strength = 1.0 - smoothstep(0.0, 0.5, d);
  strength = pow(strength, 3.0);
  gl_FragColor = vec4(vec3(1.0), strength);
}
