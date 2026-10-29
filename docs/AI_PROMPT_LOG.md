# AI Prompt & Assistance Log

**Course:** CP479 Computer Graphics — Lab 08: Textures and Transparency  
**Requirements (Section 8):** For every prompt, record the prompt, the model, the idea behind it (what you needed and what you already knew), and how you verified the answer (check values, panel CPU column, reference image, working values out on paper).

---

### Entry 1: Project Setup and Build Verification
- **Prompt:** User requested project readiness check, build verification, evidence directory structure, prediction recording, and walk-through assistance.
- **Model:** Gemini 3.8 Flash
- **Idea Behind It:**
  - Need to verify compiler toolchain (MSVC cl, glslc, cmake, glfw3, Vulkan SDK).
  - Identified MSVC incompatibility with `-Wextra` in `CMakeLists.txt` and missing `glfw3` config from CMake prefix path.
  - Resolved `glfw3` dependency from local `vcpkg` and added automatic fallback paths in `make.bat`.
- **Verification:**
  - Executed `make.bat info` and verified full Vulkan device detection (NVIDIA GeForce RTX 5070 Ti Laptop GPU, Vulkan 1.4.351, 1 ns/tick timestamps, maxSamplerAnisotropy 16).
  - Confirmed all six tasks detected as `incomplete` prior to modification.

---

### Entry 2: Part I (sRGB vs Linear) Implementation & Verification
- **Prompt:** Guide implementation of `shaders/color.glsl` (TASK 1a, 1b, 1c) and solve Write-up 1 questions.
- **Model:** Gemini 3.8 Flash
- **Idea Behind It:**
  - `srgb_to_linear`: Implement exact piecewise IEC 61966-2-1 curve without branching using `mix()` and `lessThanEqual()`.
  - `linear_to_srgb`: Implement exact inverse transfer function, ensuring non-negative values into `pow()`.
  - `albedo_check`: Compute linear luminance $Y = 0.2126R + 0.7152G + 0.0722B$. Return pure blue for $Y < 0.04$, pure red for $Y > 0.90$, and encoded grayscale $linear\_to\_srgb(Y)$ otherwise.
- **Verification:**
  - Ran `.\make.bat srgb --headless`:
    - `decode`: texel 128 -> linear 0.2159 (byte 55), yours 55, hardware 55 (PASS).
    - `ramp`: max |yours - hardware| is 1 <= 1 (PASS).
    - `roundtrip`: max |encode(decode(x)) - x| is 0 (PASS).
    - `no decode`: texel 128 displays as 188, cpu 188 (PASS).
    - `range`: too dark 3.8% (cpu 3.8%), too bright 2.6% (cpu 2.6%) (PASS).
    - `spotlights`: all probes PASS; image MATCH (0.00% differ).
  - Derived exact mathematical proofs for Write-up 1.1 to 1.4.

---

### Entry 3: Part II (Normal Mapping & Tangent Space) & Custom Map 360° Test
- **Prompt:** Guide implementation of `shaders/normalmap.vert` (TASK 2a) and `shaders/normalmap.frag` (TASK 2b), then execute and solve Write-up 2 including the custom map 360° test (Q4).
- **Model:** Gemini 3.8 Flash
- **Idea Behind It:**
  - In `normalmap.vert`: transform surface normal by the inverse transpose matrix `transpose(inverse(mat3(u.model)))`, transform tangent by `mat3(u.model)`, and construct bitangent via $B = \text{cross}(N, T) \times \text{inTangent.w}$.
  - In `normalmap.frag`: decode texel from $[0, 1] \to [-1, 1]$ via $2t - 1$, invert $n.y$ if `u.knob == 1` (DirectX convention), transform to world space using the column matrix $[T \; B \; N_g]$, and normalize.
  - For Q4: generated an external test normal map (`evidence/sample_normal_gl.png`) with known convex hemisphere bumps, ran the 360° light rotation test, and verified convention behavior.
- **Verification:**
  - Ran `.\make.bat normalmap --headless`:
    - All 6 surface flank probes passed with $\text{dot} \ge 0.9999$.
    - Convention test: DirectX map + flip vs OpenGL map: 0.00% difference (PASS).
    - Image comparison: MATCH (0.08% differ).
  - Executed `--normal evidence/sample_normal_gl.png`:
    - With knob 0 (OpenGL reading): Bumps remain convex with correct shading throughout the 360° rotation.
    - With knob 1 (DirectX reading): Shading inverts when illuminated from top/bottom, turning bumps into dimples.
    - Confirmed the texture is in **OpenGL convention**.

---

### Entry 4: Part III (Mipmaps & Anisotropic Filtering) Implementation & Verification
- **Prompt:** Guide implementation of `shaders/miplevel.frag` (TASK 3a, 3b), verify probe numbers, run filter sweep, and answer Write-up 3.
- **Model:** Gemini 3.8 Flash
- **Idea Behind It:**
  - `lod_of`: Compute derivatives of texel position $t = uv \times u.texSize$, take the longer side $\rho = \max(\|dFdx(t)\|, \|dFdy(t)\|)$, and compute $\lambda = \log_2(\rho)$.
  - `aniso_ratio`: Compute eccentricity ratio $r = \frac{\max(\|dFdx(t)\|, \|dFdy(t)\|)}{\min(\|dFdx(t)\|, \|dFdy(t)\|)}$ and clamp to $[1.0, 16.0]$.
  - Verified empirical measurements against prior predictions.
- **Verification:**
  - Ran `.\make.bat floor --headless`:
    - All 6 probe rows passed within 0.05 LOD tolerance and 3% ratio tolerance.
    - Ratio > 4 on 37.8% of floor pixels matched CPU ground truth (PASS).
    - Sweep benchmark (16 texture reads/pixel) measured:
      - Nearest: 0.071 ms (2.43×)
      - Bilinear: 0.109 ms (3.72×)
      - Trilinear: 0.029 ms (1.00×)
      - Aniso4: 0.068 ms (2.32×)
      - Aniso16: 0.106 ms (3.61× - 3.99×)
    - Confirmed predicted cost of Aniso16 ($2.5\times - 4.0\times$).
    - Analyzed reason why nearest/bilinear were slower than trilinear (lack of mipmaps causing cache thrashing at the horizon).

---

### Entry 5: Part IV (Transparency Without Sorting - WBOIT) Implementation & Verification
- **Prompt:** Guide implementation of `shaders/wboit_accum.frag` (TASK 4a) and `shaders/wboit_composite.frag` (TASK 4b), verify WBOIT checks, evaluate scaling, and answer Write-up 4.
- **Model:** Gemini 3.8 Flash
- **Idea Behind It:**
  - `wboit_accum.frag`: Extract view-space depth in metres (`inViewDepth`), compute McGuire-Bavoil weight $w(z) = \text{clamp}(0.03 / (10^{-5} + (z/200)^4), 10^{-2}, 3 \times 10^3)$, write premultiplied $(c.rgb \times c.a \times w, c.a \times w)$ to `outAccum`, and write $c.a$ to `outReveal`.
  - `wboit_composite.frag`: Sample accum and reveal targets, check for transparent coverage (`reveal >= 1.0` or `accum.a < 1e-5`), and evaluate weighted average color $\text{accum.rgb} / \max(\text{accum.a}, 10^{-5})$ with alpha $1 - \text{reveal}$.
  - Verified math proof for 2 layers with $\alpha = 0.5$ requiring $w_f : w_b = 2 : 1$.
  - Analyzed why chapter's window-depth formula collapses to unweighted average and causes fp16 overflow at 40,000 particles.
- **Verification:**
  - Ran `.\build\Release\oit.exe --headless`:
    - `single layer`: max |wboit - over| = 0 levels (PASS).
    - `two layers`: red share of accum 0.844 vs cpu 0.844, revealage 0.280 vs cpu 0.280 (PASS).
    - `order`: reversed draw order differs by at most 1 level on 4.98% of pixels (PASS) compared to unsorted Over differing on 50.77% by up to 142 levels.
    - `image`: MATCH (0.01% differ).
    - Measured particle scaling: Sorted total time jumped from 0.063 ms to 1.438 ms (CPU sort exploding from 0.031 ms to 1.184 ms, +38.2× increase), confirming prior prediction.
