#define MAX_STEPS 100
#define MAX_DIST  100.0
#define SURF_DIST 0.01

uniform float uTime;
uniform vec2  uResolution;
uniform vec2  uMouse;
varying vec2  vUv;

// --- SDFs ---
float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdBox(vec3 p, vec3 b) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float smoothmin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// --- The scene. Edit this to describe your world ---
float scene(vec3 p) {
  float sphere = sdSphere(p - vec3(sin(uTime) * 0.5, 0.0, 0.0), 0.8);
  float plane  = p.y + 1.0;
  return smoothmin(sphere, plane, 0.3);
}

// --- Normals via SDF gradient (4 samples) ---
vec3 getNormal(vec3 p) {
  vec2 e = vec2(0.01, 0.0);
  vec3 n = scene(p) - vec3(
    scene(p - e.xyy),
    scene(p - e.yxy),
    scene(p - e.yyx)
  );
  return normalize(n);
}

// --- The march ---
float raymarch(vec3 ro, vec3 rd) {
  float d0 = 0.0;
  for (int i = 0; i < MAX_STEPS; i++) {
    vec3 p = ro + rd * d0;
    float dS = scene(p);
    d0 += dS;
    if (d0 > MAX_DIST || dS < SURF_DIST) break;
  }
  return d0;
}

void main() {
  // Centre + aspect-correct UVs
  vec2 uv = vUv - 0.5;
  uv.x *= uResolution.x / uResolution.y;

  vec3 ro = vec3(0.0, 0.0, 3.0);
  vec3 rd = normalize(vec3(uv, -1.0));

  float d = raymarch(ro, rd);
  vec3 color = vec3(0.0);

  if (d < MAX_DIST) {
    vec3 p = ro + rd * d;
    vec3 n = getNormal(p);
    vec3 lightDir = normalize(vec3(1.0, 2.0, 1.0));
    float diff = max(dot(n, lightDir), 0.0);
    color = vec3(diff);
  }

  gl_FragColor = vec4(color, 1.0);
}
