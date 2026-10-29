#ifndef COLOR_GLSL_INCLUDED
#define COLOR_GLSL_INCLUDED

// sRGB-encoded value (what the bytes of a colour texture mean) -> linear light.
// The exact piecewise curve, not pow(c, 2.2).
vec3 srgb_to_linear(vec3 c) {
  vec3 low = c / 12.92;
  vec3 high = pow((c + vec3(0.055)) / 1.055, vec3(2.4));
  return mix(high, low, lessThanEqual(c, vec3(0.04045)));
}

// Linear light -> sRGB-encoded value (what the UNORM target and the screen expect).
// The exact inverse of srgb_to_linear.
vec3 linear_to_srgb(vec3 c) {
  vec3 clamped = max(c, vec3(0.0));
  vec3 low = clamped * 12.92;
  vec3 high = 1.055 * pow(clamped, vec3(1.0 / 2.4)) - 0.055;
  return mix(high, low, lessThanEqual(clamped, vec3(0.0031308)));
}

// A debug view for albedo textures: luminance of the LINEAR colour, too dark
// (< 0.04) shows blue, too bright (> 0.9) shows red, anything else shows that
// luminance as a grey, encoded for display.
vec3 albedo_check(vec3 lin) {
  float Y = 0.2126 * lin.r + 0.7152 * lin.g + 0.0722 * lin.b;
  if (Y < 0.04) {
    return vec3(0.0, 0.0, 1.0);
  } else if (Y > 0.9) {
    return vec3(1.0, 0.0, 0.0);
  } else {
    return linear_to_srgb(vec3(Y));
  }
}

#endif
