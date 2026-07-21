#include <packing>

varying vec2 vUv;
uniform sampler2D tDiffuse;
uniform sampler2D tDepth;
uniform sampler2D tNormal;
uniform vec2 resolution;
uniform float cameraNear;
uniform float cameraFar;
uniform float outlineThickness;

float readDepth(sampler2D depthTexture, vec2 coord) {
  float fragCoordZ = texture2D(depthTexture, coord).x;
  float viewZ = perspectiveDepthToViewZ(fragCoordZ, cameraNear, cameraFar);
  return viewZToOrthographicDepth(viewZ, cameraNear, cameraFar);
}

// Sobel depth gradient -- detects outer edges
float sobelDepth(vec2 uv, vec2 texel) {
  float d00 = readDepth(tDepth, uv + outlineThickness * texel * vec2(-1,  1));
  float d01 = readDepth(tDepth, uv + outlineThickness * texel * vec2(-1,  0));
  float d02 = readDepth(tDepth, uv + outlineThickness * texel * vec2(-1, -1));
  float d10 = readDepth(tDepth, uv + outlineThickness * texel * vec2( 0,  1));
  float d12 = readDepth(tDepth, uv + outlineThickness * texel * vec2( 0, -1));
  float d20 = readDepth(tDepth, uv + outlineThickness * texel * vec2( 1,  1));
  float d21 = readDepth(tDepth, uv + outlineThickness * texel * vec2( 1,  0));
  float d22 = readDepth(tDepth, uv + outlineThickness * texel * vec2( 1, -1));

  float gx = -d00 - 2.0 * d01 - d02 + d20 + 2.0 * d21 + d22;
  float gy =  d00 + 2.0 * d10 + d20 - d02 - 2.0 * d12 - d22;
  return sqrt(gx * gx + gy * gy);
}

void main() {
  vec2 texel = vec2(1.0) / resolution;
  vec4 sceneColor = texture2D(tDiffuse, vUv);

  float edge = sobelDepth(vUv, texel);
  float outline = step(0.01, edge);

  gl_FragColor = mix(sceneColor, vec4(0.0, 0.0, 0.0, 1.0), outline);
}
