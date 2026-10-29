#version 450
#extension GL_GOOGLE_include_directive : require

#include <params.glsl>

layout(location = 0) out vec4 outColor;

void main() {
  ivec2 p = ivec2(gl_FragCoord.xy);

  vec4  accum  = texelFetch(tex0, p, 0);
  float reveal = texelFetch(tex1, p, 0).r;

  // Where nothing transparent was drawn (reveal 1), leave the scene alone.
  if (reveal >= 1.0 || accum.a < 1e-5) {
    outColor = vec4(0.0);
    return;
  }

  // weighted average colour accum.rgb / accum.a with alpha 1 - reveal.
  vec3 col = accum.rgb / max(accum.a, 1e-5);
  outColor = vec4(col, 1.0 - reveal);
}
