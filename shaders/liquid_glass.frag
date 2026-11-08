#version 460 core
#include <flutter/runtime_effect.glsl>

// The first vec2 and sampler are supplied by ImageFilter.shader.
uniform vec2 u_size;
uniform vec2 u_extent;
uniform float u_radius;
uniform float u_strength;
uniform float u_dark;
uniform vec3 u_tint;
uniform float u_clarity;
uniform sampler2D u_background;
out vec4 fragColor;

vec4 sampleBackdrop(vec2 uv) {
  uv = clamp(uv, 0.5 / u_size, 1.0 - 0.5 / u_size);
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_background, uv);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  // Filter textures can have vertical padding; keep the lens geometry isotropic.
  float pixelsPerUnit = u_size.x / u_extent.x;
  vec2 p = (FlutterFragCoord().xy - u_size * 0.5) / pixelsPerUnit;
  float radius = min(u_radius, min(u_extent.x, u_extent.y) * 0.5);
  vec2 q = abs(p) - u_extent * 0.5 + radius;
  float distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
  vec2 normal = q.x > 0.0 && q.y > 0.0
      ? normalize(max(q, vec2(0.0001))) * sign(p)
      : (q.x > q.y ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y)));
  float rim = exp(-max(-distance, 0.0) / (4.0 + 8.0 * u_strength));
  vec2 refracted = (uv - 0.5) / (1.0 + 0.035 * u_strength) + 0.5
      - normal * rim * u_strength * 14.0 * pixelsPerUnit / u_size;
  // Keep background text from competing with the navigation labels.
  vec2 spread = vec2((3.2 - 1.4 * u_clarity) * pixelsPerUnit) / u_size;
  vec4 color = sampleBackdrop(refracted) * 0.25
      + sampleBackdrop(refracted + vec2(spread.x, 0.0)) * 0.125
      + sampleBackdrop(refracted - vec2(spread.x, 0.0)) * 0.125
      + sampleBackdrop(refracted + vec2(0.0, spread.y)) * 0.125
      + sampleBackdrop(refracted - vec2(0.0, spread.y)) * 0.125
      + sampleBackdrop(refracted + spread) * 0.0625
      + sampleBackdrop(refracted - spread) * 0.0625
      + sampleBackdrop(refracted + vec2(spread.x, -spread.y)) * 0.0625
      + sampleBackdrop(refracted + vec2(-spread.x, spread.y)) * 0.0625;
  vec3 rgb = mix(color.rgb / max(color.a, 0.0001), u_tint, 0.24 - 0.20 * u_clarity);
  // Protect foreground contrast when bright/dark content passes underneath.
  vec3 linear = pow(max(rgb, 0.0), vec3(2.2));
  float luminance = dot(linear, vec3(0.2126, 0.7152, 0.0722));
  if (u_dark > 0.5 && luminance > 0.10) {
    linear *= 0.10 / luminance;
  } else if (u_dark < 0.5 && luminance < 0.70 - 0.16 * u_clarity) {
    linear = mix(linear, vec3(1.0), clamp((0.70 - 0.16 * u_clarity - luminance) / max(1.0 - luminance, 0.001), 0.0, 1.0));
  }
  rgb = pow(linear, vec3(1.0 / 2.2));
  float glint = pow(rim, 3.0) * (0.5 + 0.5 * dot(normal, normalize(vec2(-0.6, -0.8))));
  rgb = mix(rgb, vec3(1.0), glint * (0.08 + 0.16 * u_strength));
  fragColor = vec4(rgb * color.a, color.a);
}
