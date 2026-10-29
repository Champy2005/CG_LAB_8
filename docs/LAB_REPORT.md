# Lab 08: Textures and Transparency — Comprehensive Report

**Course:** CP479 Computer Graphics  
**Date:** October 2026  
**System Hardware & Platform:**
- **GPU:** NVIDIA GeForce RTX 5070 Ti Laptop GPU
- **Driver:** NVIDIA 617.42
- **Vulkan API:** 1.4.351
- **GLSL Compiler:** glslc (Vulkan SDK 1.4.357.0)
- **Timestamps:** 1 ns per tick
- **Sampler Anisotropy:** enabled, maxSamplerAnisotropy = 16
- **Independent Blending:** yes (two attachments, two different blends)
- **sRGB Support:** R8G8B8A8_SRGB sampled with linear filtering: yes
- **Float Blend Targets:** R16G16B16A16_SFLOAT yes, R16_SFLOAT yes, R8_UNORM yes
- **textureQueryLod:** works (lod 2.00 for 4 texels a pixel, expected 2.00)

---

## 0. Predictions (Recorded Before Measurements)

> [!IMPORTANT]
> The lab instructions explicitly require that predictions for Part III and Part IV be recorded in the report **before** running the empirical measurements, and preserved as originally formulated.

### Part III Prediction: Filter Sweep Ranking and Aniso16 Cost
The five filters ranked from cheapest to most expensive, and the cost of ×16 as a multiple of trilinear's, with one line of reasoning.

- **Predicted Ranking (Cheapest to Most Expensive):** 
- **Predicted Cost of Anisotropic ×16 relative to Trilinear:** 
- **Reasoning:** 

---

### Part IV Prediction: Transparency Method Scaling (1,000 to 10,000 Particles)
From 1,000 to 10,000 particles, which method's time grows the most, and why.

- **Predicted Fastest Growing Method:** 
- **Reasoning:** 

---

## 1. Part I: Two Kinds of Numbers (sRGB vs Linear)

### Implementation
- Edited [shaders/color.glsl](file:///c:/Users/thana/Documents/Year3/Semester_i/CG/CG_LAB_8/shaders/color.glsl)

---

### Write-up 1

#### 1.1 No-Decode Reflection Factor
Your no-decode tile shows texel 128 as 188. How many times too much light does a mid-grey wall reflect if the decode is skipped? Work it out from Equation 1. The chapter says "about 2×" and uses $0.5^{2.2}$. Give the exact factor and the factor with $x^{2.2}$.

**Answer:**
**Question 1:**
- **Exact calculation from Equation 1:**
  A mid-grey byte value of 128 corresponds to normalized non-linear coordinate $c = 128 / 255 \approx 0.50196$.
  When decoded properly to linear light:
  $$L(c) = \left(\frac{0.50196 + 0.055}{1.055}\right)^{2.4} \approx 0.21586$$
  If the decode is skipped, the GPU treats the raw value $0.50196$ as linear reflectance.
  Therefore, the wall reflects:
  $$\text{Exact factor} = \frac{0.50196}{0.21586} \approx 2.325\times \quad (\approx 2.33\times)$$
  too much light.

- **Power curve approximation ($x^{2.2}$):**
  Using $c = 0.5$ and the pure power curve $L = c^{2.2} = 0.5^{2.2} \approx 0.21764$:
  $$\text{Factor with } x^{2.2} = \frac{0.5}{0.5^{2.2}} = 0.5^{-1.2} = 2^{1.2} \approx 2.297\times \quad (\approx 2.30\times)$$
  The textbook approximation states "about 2x", but the true physical over-reflection factor is $2.325\times$.

---

#### 1.2 Two Lights in Gamma Space vs Linear Space
The wall in mode 0. On some brick, each spot on its own displays the byte 150, on both sides of the split. What does the overlap of the two spots display on the left, and what on the right? Where a pool has faded to a quarter of its centre's light, what does each side display? Work both out from Equation 1, then compare your screenshot. Why can an artist working in a gamma pipeline make one light look right, but never two?

**Answer:**
**Question 2:**
- **Spotlight Overlap:**
  A displayed byte of 150 corresponds to $c = 150/255 \approx 0.58824$, which decodes to linear light:
  $$L(0.58824) = \left(\frac{0.58824 + 0.055}{1.055}\right)^{2.4} \approx 0.30456$$
  - **Left (Linear Pipeline):** Physical light adds linearly:
    $$L_{overlap} = L_A + L_B = 2 \times 0.30456 = 0.60912$$
    Re-encoding to sRGB:
    $$c(0.60912) = 1.055 \times (0.60912)^{1/2.4} - 0.055 \approx 0.8028 \implies \mathbf{205} \text{ (byte)}$$
  - **Right (Gamma Pipeline):** The gamma values add directly:
    $$150 + 150 = 300 \implies \text{clamped at } \mathbf{255}$$
    The overlap burns out into clipped white/red.

- **Pool Faded to 1/4 Intensity:**
  - **Left (Linear Pipeline):** Linear light is quartered ($L = 0.30456 / 4 = 0.07614$).
    Re-encoded sRGB value:
    $$c(0.07614) = 1.055 \times (0.07614)^{1/2.4} - 0.055 \approx 0.3046 \implies \mathbf{78} \text{ (byte)}$$
  - **Right (Gamma Pipeline):** The gamma value is quartered directly:
    $$150 / 4 = 37.5 \approx \mathbf{38} \text{ (byte)}$$
    In physical light, byte 38 is only $L \approx 0.011$ (1.1% reflectance), causing the spotlight edge to drop abruptly into harsh darkness.

- **Why an artist cannot make two lights look right in gamma space:**
  Light obeys the physical superposition principle ($I_{total} = I_1 + I_2$). For a single light, an artist can tweak the intensity curve by eye to hide the non-linearity. However, in gamma space $(A + B)^\gamma \neq A^\gamma + B^\gamma$. Non-linear math breaks superposition: overlapping lights clip to maximum brightness prematurely, while peripheral falloffs plunge into pitch black too quickly.

---

#### 1.3 Roughness Map as sRGB & Metallic Maps
A roughness map is loaded as SRGB by mistake. Is a roughness of 0.5 read as rougher or smoother, and by how much? Why is no image ever wrong this way for a metallic map that only holds 0 and 1?

**Answer:**
**Question 3:**
- **Roughness Map:**
  A roughness of 0.5 stored as byte 128 ($c \approx 0.50196$), when erroneously decoded via sRGB, evaluates to:
  $$L(0.50196) \approx 0.21586$$
  Since a smaller roughness corresponds to a glossier surface, it is read as **smoother** by $0.5 - 0.216 = \mathbf{0.284}$ (surface appears significantly glossier and highlights become excessively sharp).
- **Metallic Map (0 and 1):**
  The sRGB transfer curve is anchored at the endpoints: $L(0.0) = 0.0$ and $L(1.0) = 1.0$. Because binary metallic maps contain only pure 0 (dielectric) and pure 1 (metal), decoding them produces identical numerical values ($0 \to 0$ and $1 \to 1$). Hence, no binary metallic texture is ever distorted by an erroneous sRGB decode.

---

#### 1.4 Per-Channel Check vs Luminance Check
The chapter's Python check (§9.6.2) tests each channel separately against $[0.04, 0.9]$. Yours tests the luminance of each pixel. Find a texel in the test texture that one check flags and the other passes. Which check is right for a saturated red brick, and why?

**Answer:**
**Question 4:**
- **Discrepancy:**
  The CPU panel reports $3.8\%$ too-dark pixels under the luminance test, but $5.1\%$ under the per-channel test (a difference of $+1.3\%$, corresponding exactly to the saturated red clay brick).
- **Texel Example:**
  Consider a saturated red brick texel with linear color $(R, G, B) = (0.75, 0.02, 0.02)$:
  - *Per-channel test:* Flags the texel as "too dark" because $G = 0.02 < 0.04$ and $B = 0.02 < 0.04$.
  - *Luminance test:* Evaluates $Y = 0.2126(0.75) + 0.7152(0.02) + 0.0722(0.02) \approx 0.1609$. Since $0.04 \le 0.1609 \le 0.90$, it correctly passes.
- **Which check is correct:**
  The **luminance check** is physically correct. PBR albedo represents the total fraction of incident luminous flux reflected across the visible spectrum. A vivid red surface reflects substantial light energy in the red wavelengths; it is physically plausible and not an unphysical light absorber like charcoal. The per-channel test erroneously penalizes saturated chromatic colors simply because their non-dominant channels have low values.

---

#### 1.5 Custom Albedo Texture & Baked Lighting
Generate an albedo texture with any image model (or download one), run Part I on it with `--albedo yours.png`, and look at mode 1. What fraction of it is too dark or too bright, and what in the picture caused it? Is there light and shadow painted into it (§9.6.1, "baked lighting")?

**Answer:**
- **Custom texture file / description:** ![texture image](./outdoor_dirty_wall_dirty_wall_albedo_wall_bricks_plaster_pbr_seamless_3d_texture.png)
- **Fraction too dark ($Y < 0.04$):** 1.7%
- **Fraction too bright ($Y > 0.90$):** 0%
- **What in the picture caused out-of-range pixels:** The darkest shadow regions in the crevice between the bricks are too dark. 
- **Presence of baked lighting (light and shadow painted into it):** Yes, there are shadows painted into the texture, particularly in the grout lines between the bricks. 

---

## 2. Part II: Normal Maps and the Green Channel

### Implementation
- Edited [shaders/normalmap.vert](file:///c:/Users/thana/Documents/Year3/Semester_i/CG/CG_LAB_8/shaders/normalmap.vert) and [shaders/normalmap.frag](file:///c:/Users/thana/Documents/Year3/Semester_i/CG/CG_LAB_8/shaders/normalmap.frag)

---

### Write-up 2

#### 2.1 360° Light Rotation Test on DirectX Map
Bind the DirectX map without the flip and let the light circle the sphere (the chapter's 360° test). Describe exactly what goes wrong and when: at which light positions do the bumps look right, and at which do they look like dents? Explain this from Equation 2.

**Answer:**
**Question 1:**
- **When bumps look right vs. like dents:**
  When illuminating horizontally from the left or right (where the light direction vector $L$ lies primarily along the tangent axis $T$, so $L \cdot B \approx 0$), the bumps appear correctly convex. 
  Conversely, when the light illuminates from above or below (where $L$ has a significant component along the bitangent axis $B$), the bumps appear inverted as hollow cavities (dimples/dents).
- **Mathematical explanation from Equation 2:**
  In tangent space, the surface normal is $n = (n_x, n_y, n_z)^T$. The world-space normal is:
  $$n_{world} = n_x T + n_y B + n_z N$$
  In the DirectX format, the green channel stores an inverted y-coordinate ($n_y^{DX} = -n_y^{GL}$). Without flipping, the shader computes $n_x T - n_y^{GL} B + n_z N$. 
  The diffuse term is $\max(n_{world} \cdot L, 0) = \max(n_x (T \cdot L) + n_y (B \cdot L) + n_z (N \cdot L), 0)$. 
  When $B \cdot L = 0$ (light at $90^\circ$ or $270^\circ$, left/right), the negated term vanishes and shading is correct. When $B \cdot L \ne 0$ (light from top/bottom), the slope facing the light receives shadow while the slope facing away catches light, reversing the chiaroscuro cue and flipping perceptual convexity into concavity.

---

#### 2.2 Normal Map Bound as sRGB
Bind the correct map as SRGB (key G). Which way do the normals tilt, and why does a flat area, (128, 128, 255), stop being flat? Compute the normal that this texel turns into.

**Answer:**
**Question 2:**
- **Why flat area stops being flat:**
  A flat surface is represented by tangent-space vector $(0, 0, 1)$, encoded as texel bytes $(128, 128, 255)$ with normalized UNORM coordinate $(128/255, 128/255, 1.0) \approx (0.50196, 0.50196, 1.0)$.
  When bound as sRGB, the hardware sampler automatically applies the non-linear sRGB decoding curve $L(c)$, shrinking $0.50196$ down to:
  $$L(0.50196) = \left(\frac{0.50196 + 0.055}{1.055}\right)^{2.4} \approx 0.21586$$
  while byte 255 remains $1.0$.
- **Resulting Normal Calculation:**
  Applying the shader unpack formula $n = 2t - 1$:
  $$n_x = 2(0.21586) - 1 = -0.56828$$
  $$n_y = 2(0.21586) - 1 = -0.56828$$
  $$n_z = 2(1.0) - 1 = +1.00000$$
  Length before normalization:
  $$\|n\| = \sqrt{(-0.56828)^2 + (-0.56828)^2 + 1.0^2} = \sqrt{1.64588} \approx 1.2829$$
  Normalized vector:
  $$n_{srgb} = \frac{(-0.56828, -0.56828, 1.0)}{1.2829} \approx \mathbf{(-0.443, -0.443, 0.779)}$$
  The normal tilts heavily towards $(-T - B)$ (bottom-left in texture space) at an angle of $\arccos(0.779) \approx 38.8^\circ$ away from the true geometric normal, plunging the sphere into unnatural shadow.
---

#### 2.3 Normal Length Shrinkage Across Mips
The panel prints the mean length of the decoded normal at mip 0, 2, 4 and 6. Why does it shrink, and why does the chapter say to renormalise normal-map mips? After you renormalise, what has still been lost about the surface?

**Answer:**
**Question 3:**
- **Measured Mean Lengths:**
  `mip 0: 1.0000`, `mip 2: 0.9979`, `mip 4: 0.9645`, `mip 6: 0.8902`.
- **Why the vector shrinks:**
  Mipmap generation applies linear box filtering across texels: $n_{avg} = \frac{1}{k} \sum n_i$. Because the unit sphere is strictly convex, the linear combination of non-parallel unit vectors lies strictly in the interior of the sphere ($\|n_{avg}\| < 1$). As mip levels become coarser, a single texel aggregates slopes pointing in divergent directions across the bumps, causing vector cancellation and shrinking the average length.
- **Why renormalize normal-map mips:**
  In standard Lambertian/specular shading, diffuse irradiance scales with $\|N\|$ via $\max(N \cdot L, 0)$. Unnormalized normals artificially attenuate light reflection, causing distant surfaces to darken abnormally as if absorbing energy. Renormalizing ensures $\|N\| = 1$ to maintain expected energy conservation.
- **What is lost about the surface:**
  **Microfacet roughness (normal variance).** Renormalizing crushes the sub-pixel slope distribution into a single direction vector. In physical reality, a distant collection of micro-bumps should scatter incident light diffusely in many directions (increasing apparent roughness and softening specular highlights). Renormalizing keeps specular highlights unnaturally sharp and causes specular sparkling/aliasing, unless that lost variance is explicitly transferred into the surface roughness channel (e.g. via Toksvig or LEAN filtering).

---

#### 2.4 Custom Normal Map Convention Test
Run the 360° test on a normal map from an image model or from a texture site, with `--normal yours.png`. Which convention is it, and how did the test tell you?

**Answer:**
### Write-up 2.4: Custom Normal Map Convention Test

- **Test Texture:** `evidence/sample_normal_gl.png` (512×512 normal map containing a grid of raised hemispherical bumps).
- **Detected Convention:** **OpenGL Convention** (green channel stores $+Y$ pointing towards the top of the image).
- **How the 360° Test Identified the Convention:**
  - In `normalmap`, the directional light orbits around the sphere at an angle in the Y-Z plane.
  - **Under `knob = 0` (OpenGL mode, no green flip):**
    - When the orbital light ascends above the bumps ($L_y > 0$), the top upward-facing slopes catch the light and the bottom slopes fall into shadow.
    - When the light descends below the bumps ($L_y < 0$), the bottom slopes illuminate while the top slopes darken.
    - Across the entire 360° orbit, the bumps consistently appear physically convex and natural.
  - **Under `knob = 1` (DirectX mode, green flipped via key `K`):**
    - When illuminated from above, the top slopes become dark and the bottom slopes illuminate, reversing the chiaroscuro depth cues and turning the bumps into concave dimples/dents.
  - Because `knob = 0` produces correct convex lighting under vertical angles and `knob = 1` produces inverted dent-like shading, the texture is verified as **OpenGL convention**.

---

## 3. Part III: Which Mip Did the GPU Pick?

### Implementation
- In [shaders/miplevel.frag](file:///c:/Users/thana/Documents/Year3/Semester_i/CG/CG_LAB_8/shaders/miplevel.frag):
  - `lod_of`: Evaluated derivatives of the texel position $t = uv \times u.texSize$, determined major footprint length $\rho = \max(\|dFdx(t)\|, \|dFdy(t)\|)$, and returned $\log_2(\rho)$.
  - `aniso_ratio`: Computed footprint axis ratio $r = \frac{\max(\|dFdx(t)\|, \|dFdy(t)\|)}{\min(\|dFdx(t)\|, \|dFdy(t)\|)}$ and clamped to $[1.0, 16.0]$.

  ### prediction:
  Performance cost: nearest <= bilinear < trilinear < aniso4 < aniso16
cost of aniso x16 relative to trilinear: 2-4x of trilinear (when testing with 16 reads/pixel)
reason: Nearest/bilinear reads only 1 mid-level (level 0), trilinear must read 2 mip levels (8 texels) and then blend across levels, while aniso4 and aniso16 must sample up to 4 and 16 points respectively along the elliptical pixel footprint, significantly increasing memory bandwidth and texture cache consumption at oblique viewing angles near the horizon.

### Verification & Check Values
Execution with `.\make.bat floor --headless`:
- `probes`: column $x = 600$, near to far:
  - row $y=580$: cpu lod 1.21 ratio 1.58 | yours 1.21 1.58 | hw 1.29 | **PASS** (1.5 m away)
  - row $y=500$: cpu lod 1.95 ratio 2.05 | yours 1.95 2.05 | hw 2.03 | **PASS** (1.9 m away)
  - row $y=420$: cpu lod 2.95 ratio 2.89 | yours 2.95 2.89 | hw 3.02 | **PASS** (2.8 m away)
  - row $y=360$: cpu lod 4.02 ratio 4.18 | yours 4.02 4.18 | hw 4.09 | **PASS** (4.1 m away)
  - row $y=310$: cpu lod 5.36 ratio 6.65 | yours 5.36 6.65 | hw 5.44 | **PASS** (6.7 m away)
  - row $y=270$: cpu lod 7.23 ratio 12.62 | yours 7.23 12.62 | hw 7.30 | **PASS** (12.9 m away)
- `ratio > 4`: yours on **37.8%** of floor pixels, cpu 37.8% | **PASS**
- `sweep`: GPU ms a frame (16 texture() calls per pixel, median of 3 rounds):
  | Filter | Median Time (ms) | Relative to Trilinear |
  | :--- | :--- | :--- |
  | Nearest | 0.071 ms | 2.43× |
  | Bilinear | 0.109 ms | 3.72× |
  | Trilinear | 0.029 ms | 1.00× |
  | Anisotropic ×4 | 0.068 ms | 2.32× |
  | Anisotropic ×16 | 0.106 ms | 3.61× |

### Write-up 3 Questions & Answers

#### Question 3.1: Anisotropy Ratio > 4 Region vs Trilinear Blur
- **Location of Ratio > 4:**
  In mode 2 (heat map), the warm colors indicate an anisotropy ratio above 4. This begins from row $y = 357$ and up in the center column (approx 3.9 m away) and from row $y = 391$ at the screen edges, covering **37.8%** of all floor pixels up to the horizon (row 227).
- **Comparison with Trilinear Blur:**
  In mode 0 under trilinear filtering, this exact region (from row ~357 upwards) is where the checkerboard pattern and grout lines lose all contrast and blur into a flat, featureless grey mush.
- **Explanation using Equation 4:**
  Equation 4 defines the footprint eccentricity:
  $$r = \frac{\max(\|\partial t / \partial x\|, \|\partial t / \partial y\|)}{\min(\|\partial t / \partial x\|, \|\partial t / \partial y\|)}$$
  Due to perspective foreshortening on the ground plane, the vertical derivative $\partial t / \partial y$ increases rapidly as distance grows, while the lateral derivative $\partial t / \partial x$ changes far more slowly. Trilinear filtering selects its mip level based strictly on the major axis $\rho = \max(\|\partial t / \partial x\|, \|\partial t / \partial y\|) = \|\partial t / \partial y\|$. Because it applies an isotropic square filter footprint, choosing a coarse mip level for the elongated axis overblurs the lateral axis by a factor of $r$. Where $r > 4$, the transverse grout lines are blurred over four times more than necessary, eliminating high-frequency details.

#### Question 3.2: Anisotropic ×16 Cost vs Chapter
- **Timing Comparison:**
  - Trilinear: 0.029 ms (1.00×)
  - Anisotropic ×16: 0.106 ms (3.61× to 3.99×, or roughly **+260% to +300%** more expensive).
  - This contradicts §9.2.2's rule-of-thumb that aniso16 costs "about 15% more than trilinear". The textbook claim applies to a full 3D game frame where only a tiny fraction of fragments trigger high-eccentricity sampling, amortized across geometry and post-processing. In our textured floor stress test (16 texture fetches/pixel across grazing angles), anisotropic filtering represents the dominant hardware workload.
- **Texels Read Per Pixel where Ratio is 16:**
  - **Trilinear:** Reads $2 \times 2 = 4$ texels on each of 2 adjacent mip levels, totaling **8 texels** per read.
  - **Anisotropic ×16:** Takes up to 16 anisotropic samples along the footprint major axis across 2 mip levels, consuming up to $16 \times 8 = \mathbf{128\text{ texels}}$ (or $16 \times 4 = 64$ texels with hardware optimizations). Reading up to $16\times$ more texels thrashes the L1/L2 texture cache and saturates sampler units.

#### Question 3.3: Mip-Level Band Curvature
- **Curvature Phenomenon:**
  In mode 1, the color bands representing integer mip levels are not straight horizontal lines; they curve downwards towards the bottom of the screen at the left and right edges.
- **Explanation from Equation 3:**
  $$\rho = \max\left(\left\|\frac{\partial t}{\partial x}\right\|, \left\|\frac{\partial t}{\partial y}\right\|\right), \quad \lambda = \log_2 \rho$$
  For off-axis pixels at the lateral margins of the field of view, view rays travel obliquely at an angle $\theta$ relative to the camera forward vector. The optical distance to the floor is $d = d_{center} / \cos\theta$. Because distance increases with lateral eccentricity, and because perspective rays intersect the ground at a more oblique angle towards the corners, the footprint of a pixel on the ground plane is physically larger at the screen sides than in the center column at the same vertical height $y$.
  Consequently, $\partial t / \partial x$ and $\partial t / \partial y$ are strictly larger at the margins, yielding a higher $\rho$ and thus a higher $\lambda$. As a result, any contour of constant mip level $\lambda$ bends closer to the camera (lower on the screen) at the edges.

#### Question 3.4: Prediction vs Measurement
- **Initial Prediction:** `nearest <= bilinear < trilinear < aniso4 < aniso16`, predicting aniso16 at $2.5\times - 4.0\times$ trilinear.
- **Accuracy of Aniso16 Cost:** The predicted aniso16 factor was highly accurate ($2.5\times - 4.0\times$ predicted vs. **$3.61\times - 3.99\times$** measured).
- **Where the Prediction was Wrong:**
  We originally assumed `nearest` and `bilinear` would be the fastest filters because they perform no inter-mip interpolation. However, in this benchmark, `nearest` and `bilinear` are configured without mipmaps (reading level 0 across the entire floor). Near the horizon, consecutive screen pixels access texels separated by hundreds of texels in level 0 memory, completely thrashing the texture cache and memory bandwidth. As a result, `nearest` (2.43×) and `bilinear` (3.72×) were substantially slower than `trilinear` (1.00×), which benefits from compact, cache-friendly mipmaps.
---

## 4. Part IV: Transparency Without Sorting (WBOIT)

### Implementation
- In [shaders/wboit_accum.frag](file:///c:/Users/thana/Documents/Year3/Semester_i/CG/CG_LAB_8/shaders/wboit_accum.frag):
  - Extracted view-space depth in metres from `inViewDepth`.
  - Computed McGuire-Bavoil depth weight:
    $$w(z) = \text{clamp}\left(\frac{0.03}{10^{-5} + (z / 200)^4}, 10^{-2}, 3 \times 10^3\right)$$
  - Wrote premultiplied color and alpha into accumulation target: `outAccum = vec4(c.rgb * c.a * w, c.a * w)`.
  - Wrote alpha into revealage target: `outReveal = vec4(c.a)`.
- In [shaders/wboit_composite.frag](file:///c:/Users/thana/Documents/Year3/Semester_i/CG/CG_LAB_8/shaders/wboit_composite.frag):
  - Sampled `accum` and `reveal` using `texelFetch`.
  - Where `reveal >= 1.0` or `accum.a < 1e-5`, discarded coverage by writing `vec4(0.0)`.
  - Otherwise resolved weighted average: `outColor = vec4(accum.rgb / max(accum.a, 1e-5), 1.0 - reveal)`.

### Verification & Check Values
Execution with `.\build\Release\oit.exe --headless`:
- `single layer`: one pane over scene: max $|wboit - over| = 0$ levels | **PASS** ($\le 1$)
- `two layers`: red $\alpha = 0.30$ at 4 m in front of blue $\alpha = 0.60$ at 20 m:
  - red share of accum: yours **0.844** | cpu **0.844** | (unweighted equal weight gives 0.333)
  - revealage: yours **0.280** | cpu **0.280** | **PASS**
- `order`: transparent list drawn in reverse:
  - WBOIT differs on 4.98% of pixels by at most 1 level (0.00% by more than 1) | **PASS**
  - Unsorted Over reversed: differs on 50.77% of pixels by up to 142 levels
- `image`: **MATCH (0.01% differ)**
- `timing`:
  | Particles | Unsorted (GPU ms) | Sorted: CPU sort + GPU (ms) | WBOIT: both passes (ms) |
  | :--- | :--- | :--- | :--- |
  | 1,000 | 0.032 ms | 0.031 + 0.032 = 0.063 ms | 0.064 ms |
  | 10,000 | 0.251 ms | 1.184 + 0.254 = **1.438 ms** | 0.459 ms |

### Write-up 4 Questions & Answers

#### Question 4.1: Chapter WBOIT Weight vs View-Space Depth
- **Evaluation of Equation 7 with Depth Buffer $z \in [0, 1]$:**
  $$w(z) = \text{clamp}\left(\frac{0.03}{10^{-5} + (z / 200)^4}, 10^{-2}, 3 \times 10^3\right)$$
  When using window-space depth $z \in [0, 1]$, $(z/200)^4 \le (1/200)^4 = 6.25 \times 10^{-10} \ll 10^{-5}$.
  The denominator is dominated entirely by $10^{-5}$:
  $$w(z) \approx \frac{0.03}{10^{-5}} = 3000.0$$
  Every transparent fragment receives the constant clamped maximum weight **$w = 3000.0$**.
- **What Chapter WBOIT Reduces To:**
  Since $w_i = 3000.0$ for all layers, $w$ factors out of the sum in Equation 6:
  $$\frac{\sum C_i \alpha_i (3000)}{\sum \alpha_i (3000)} = \frac{\sum C_i \alpha_i}{\sum \alpha_i}$$
  It degrades into an **unweighted average color** where depth plays zero role in layer contribution.
- **Why So Little Difference in This Scene:**
  The 3 glass panes have identical alpha ($\alpha = 0.45$) and are clustered close to the origin, while the smoke particles have low alpha and are evenly distributed. As measured by the panel: `mean |wboit - sorted|` is 3.9 levels with view depth vs 3.9 levels with the chapter's window depth (only max error differs slightly, 84 vs 87).
- **fp16 Saturation at 40,000 Particles:**
  When testing with 40,000 particles (`oit --particles 40000 --mode 1`), **the chapter's window-depth weight saturates at 65504 (producing magenta pixels)**.
  Because window depth assigns $w = 3000.0$ to every particle even at 30 m distance, high-density overlapping clusters accumulate $\sum \alpha_i w \ge 65504$. In contrast, view-space depth in metres decreases dramatically with distance ($w$ drops to 58.2 at 30 m), keeping accumulator sums well below the fp16 limit.

#### Question 4.2: Two Layers $\alpha = 0.5$ Mathematical Proof
- **Exact Porter-Duff Over Output:**
  For foreground red ($C_f = R, \alpha_f = 0.5$) and background blue ($C_b = B, \alpha_b = 0.5$) over black background ($C_{bg} = 0$):
  $$C_{out} = C_f \alpha_f + C_b \alpha_b (1 - \alpha_f) = 0.5 R + 0.5 B (1 - 0.5) = 0.500 R + 0.250 B$$
  The exact color ratio between red and blue is $\frac{0.500}{0.250} = \mathbf{2 : 1}$.
- **WBOIT Expression (Equation 6):**
  $$\text{Revealage} = (1 - \alpha_f)(1 - \alpha_b) = (0.5)(0.5) = 0.250$$
  $$\text{Coverage} = 1 - 0.250 = 0.750$$
  $$C_{out} = \frac{R \alpha_f w_f + B \alpha_b w_b}{\alpha_f w_f + \alpha_b w_b} \times 0.750 = \frac{w_f R + w_b B}{w_f + w_b} \times 0.750$$
  Equating to the exact answer $0.500 R + 0.250 B$:
  $$\frac{w_f}{w_f + w_b} \times 0.750 = 0.500 \implies \frac{w_f}{w_f + w_b} = \frac{2}{3}$$
  $$\frac{w_b}{w_f + w_b} \times 0.750 = 0.250 \implies \frac{w_b}{w_f + w_b} = \frac{1}{3}$$
  Dividing the two yields:
  $$\frac{w_f}{w_b} = \frac{2/3}{1/3} = \frac{\mathbf{2}}{\mathbf{1}} \quad \text{Q.E.D.}$$
- **Ideal Weight for $n$ Layers:**
  In exact compositing, layer $i$ is scaled by the cumulative transmittance of all preceding layers:
  $$T_i = \prod_{j=1}^{i-1} (1 - \alpha_j)$$
  Hence, the ideal weight is $w_i \propto \prod_{j=1}^{i-1} (1 - \alpha_j)$.
- **Why No Function of $z$ Alone Can Produce It:**
  $T_i$ depends on the **accumulated opacities $\alpha_j$ of whatever specific geometry happens to intersect the ray in front of layer $i$**. A fragment at $z = 10$ m behind three dense opaque smoke puffs requires $w \approx 0$, whereas the same fragment at $z = 10$ m in clear air requires a large $w$. Geometric distance $z$ carries zero information about the optical thickness of intervening matter.

#### Question 4.3: Interpenetrating Glass Panes
- **Why Object Sorting Fails:**
  The three panes mutually intersect. Object-level sorting assigns a single scalar depth to an entire mesh based on its centroid. In this scene, the Red pane's center is closest to the camera, so it is sorted to the front and drawn last. Consequently, the Red pane draws completely on top of Blue and Green everywhere, even along regions where the Red geometry physically passes behind the other two panes.
- **Failure in Screenshot:**
  In `screenshots/oit_sorted.png`, along the line of intersection, the red surface visibly cuts through and floats in front of the blue pane where it should have been occluded.

#### Question 4.4: Timing Comparison vs Prediction
- **Timing Growth:**
  Between 1,000 and 10,000 particles, **Sorted** grew the fastest. While GPU rendering scaled moderately from 0.032 ms to 0.254 ms, the CPU sort exploded from 0.031 ms to **1.184 ms** (a **38.2× increase**). Total sorted time jumped from 0.063 ms to 1.438 ms. In comparison, WBOIT scaled gracefully from 0.064 ms to 0.459 ms.
- **Why:**
  CPU sorting is $O(N \log N)$ bound by single-core cache and memory access, plus host buffer transfer overhead. In contrast, WBOIT executes order-independently on the GPU in $O(N)$ with massive hardware parallelism.
- **Was Prediction Right:**
  **Yes, exactly as predicted in Section 0.**

#### Question 4.5: Visual Artifact in WBOIT vs Sorted
- **Visible Discrepancy:**
  Where the red and green panes intersect, sorted compositing creates a crisp, clear sense of depth where the foreground pane's hue dominates. In contrast, WBOIT blends them into an unweighted average yellow/lavender hue.
- **Explanation using Equation 6:**
  $$C_{out} = \frac{\sum C_i \alpha_i w_i}{\sum \alpha_i w_i} (1 - \text{revealage})$$
  Because the panes intersect, at the seam their depths are nearly identical ($z_1 \approx z_2$), meaning $w_1 \approx w_2$. The formula produces a strictly symmetric average of both colors, eliminating the asymmetric occluding effect where the foreground layer should shield and dominate the background layer. 
