#version 450
#extension GL_GOOGLE_include_directive : require

#include <params.glsl>
#include <transparent.glsl>

layout(location = 0) out vec4 outAccum;
layout(location = 1) out vec4 outReveal;

void main() {
  vec4 c = surface();

  // The weight: w = clamp(0.03 / (1e-5 + (z / 200)^4), 1e-2, 3e3), with z the
  // VIEW-SPACE depth in metres (inViewDepth), not the window depth gl_FragCoord.z.
  float z = inViewDepth;
  float w = clamp(0.03 / (1e-5 + pow(z / 200.0, 4.0)), 1e-2, 3e3);

  // accum: the colour premultiplied by alpha, times w, and alpha times w.
  outAccum = vec4(c.rgb * c.a * w, c.a * w);

  // reveal: the alpha, so the blend leaves the product of (1 - alpha).
  outReveal = vec4(c.a);
}
