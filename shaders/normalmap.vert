#version 450
#extension GL_GOOGLE_include_directive : require

#include <params.glsl>

layout(location = 0) in vec3 inPos;
layout(location = 1) in vec3 inNormal;
layout(location = 2) in vec2 inUV;
layout(location = 3) in vec4 inTangent;

layout(location = 0) out vec2 outUV;
layout(location = 1) out vec3 outNormal;
layout(location = 2) out vec3 outTangent;
layout(location = 3) out vec3 outBitangent;

void main() {
  vec4 world  = u.model * vec4(inPos, 1.0);
  outUV       = inUV;
  gl_Position = u.proj * u.view * world;

  mat3 normalMatrix = transpose(inverse(mat3(u.model)));
  vec3 N = normalMatrix * inNormal;
  vec3 T = mat3(u.model) * inTangent.xyz;
  vec3 B = cross(N, T) * inTangent.w;

  outNormal    = N;
  outTangent   = T;
  outBitangent = B;
}
