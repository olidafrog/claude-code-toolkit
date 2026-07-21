uniform float intensity;

// Effect fragment shaders use mainImage(), not main().
// Pre-injected by postprocessing: inputBuffer, time, resolution.
void mainImage(const in vec4 inputColor, const in vec2 uv, out vec4 outputColor) {
  vec4 color = texture2D(inputBuffer, uv);

  // Starter: tint red by intensity amount -- replace with your effect
  vec3 tinted = mix(color.rgb, vec3(1.0, 0.2, 0.3), intensity * 0.3);

  outputColor = vec4(tinted, color.a);
}
