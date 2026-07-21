uniform sampler2D uPositions;

void main() {
  // position.xy is the UV into the positions texture
  vec3 pos = texture2D(uPositions, position.xy).rgb;
  vec4 modelPos = modelMatrix * vec4(pos, 1.0);
  vec4 viewPos = viewMatrix * modelPos;
  gl_Position = projectionMatrix * viewPos;
  gl_PointSize = 2.5 * (1.0 / -viewPos.z);
}
