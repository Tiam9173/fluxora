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

float roundedRectDistance(vec2 p, vec2 halfExtent, float radius) {
  vec2 q = abs(p) - halfExtent + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
  // The viewport may clip a scrolled lens. Sample only the texture the engine
  // supplied, keeping the rounded geometry on the same pixel scale.
  float pixelsPerUnit = u_size.x / max(u_extent.x, 1.0);
  vec2 halfExtent = min(u_size / pixelsPerUnit, u_extent) * 0.5;
  vec2 p = (uv - 0.5) * u_size / pixelsPerUnit;
  float radius = min(u_radius, min(halfExtent.x, halfExtent.y));
  float distance = roundedRectDistance(p, halfExtent, radius);
  vec2 x = vec2(2.0, 0.0);
  vec2 y = vec2(0.0, 2.0);
  vec2 normal = vec2(
    roundedRectDistance(p + x, halfExtent, radius) - roundedRectDistance(p - x, halfExtent, radius),
    roundedRectDistance(p + y, halfExtent, radius) - roundedRectDistance(p - y, halfExtent, radius)
  ) * 0.25;
  float rim = exp(-abs(distance) / (3.5 + 7.0 * u_strength));
  vec2 pixel = pixelsPerUnit / u_size;
  vec2 refracted = uv - normal * rim * u_strength * 16.0 * pixel;

  // One pass avoids mismatched blur and refraction bounds while softening text.
  vec2 spread = (1.25 + 4.75 * (1.0 - u_clarity)) * pixel;
  vec4 color = sampleBackdrop(refracted) * 0.36;
  color += sampleBackdrop(refracted + spread) * 0.16;
  color += sampleBackdrop(refracted - spread) * 0.16;
  color += sampleBackdrop(refracted + vec2(spread.x, -spread.y)) * 0.16;
  color += sampleBackdrop(refracted + vec2(-spread.x, spread.y)) * 0.16;
  vec3 rgb = mix(color.rgb / max(color.a, 0.0001), u_tint, 0.24 - 0.20 * u_clarity);
  // Protect foreground contrast when bright/dark content passes underneath.
  vec3 linear = pow(max(rgb, 0.0), vec3(2.2));
  float luminance = dot(linear, vec3(0.2126, 0.7152, 0.0722));
  if (u_dark > 0.5 && luminance > 0.10) {
    float shoulder = 0.10 + 0.10 * (1.0 - exp(-(luminance - 0.10) * 2.0));
    linear *= shoulder / luminance;
  } else if (u_dark < 0.5) {
    float minimum = 0.86 - 0.23 * u_clarity;
    if (luminance < minimum) {
      linear = mix(linear, vec3(1.0), (minimum - luminance) / max(1.0 - luminance, 0.001));
    }
  }
  rgb = pow(linear, vec3(1.0 / 2.2));
  float glint = pow(rim, 3.0) * (0.5 + 0.5 * dot(normal, normalize(vec2(-0.6, -0.8))));
  if (u_dark < 0.5) {
    rgb = mix(rgb, vec3(0.50, 0.63, 0.83), pow(rim, 2.0) * (1.0 - glint) * 0.055);
  }
  rgb = mix(rgb, vec3(1.0), glint * (0.08 + 0.16 * u_strength));
  fragColor = vec4(rgb * color.a, color.a);
}
