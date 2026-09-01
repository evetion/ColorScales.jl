# Design space for a generic scientific colour-utility package for Makie and Plots

**Date:** 2026-08-27
**Status:** Research only — no code was scaffolded.
**Scope:** QGIS graduated/classified symbology as a feature template; the Julia colour, plotting
and statistics ecosystem as the implementation substrate; what a new package should and should
not do.

Workspace note: `/Users/evetion/projects/makiecolors` was empty at the time of writing, so no
pre-existing research-note convention could be followed. This file establishes
`docs/research/YYYY-MM-DD-topic.md`.

All QGIS source citations are pinned to commit
[`2e3de3b`](https://github.com/qgis/QGIS/tree/2e3de3b961a0670b666461be7eff1870e24aec70).
All Julia registry facts are from a clone of
[JuliaRegistries/General](https://github.com/JuliaRegistries/General) at HEAD `e501d6ae`
(2026-08-27).

---

## 1. Executive summary

QGIS's classification machinery is small, well-factored and directly portable in *design* (not in
code — it is GPLv2+): a `ClassificationMethod` abstraction that turns a value vector plus a class
count into a list of `(lowerBound, upperBound, label)` ranges, with seven concrete methods, an
optional symmetry mode, and a label-formatting layer
(`qgis/QGIS:src/core/classification/qgsclassificationmethod.h:53-85,115-133,243-283`).

On the Julia side, the raw numerics already exist and are MIT-licensed: `Statistics.quantile`
implements exactly the interpolation rule QGIS uses for its quantile mode;
`PlotUtils.optimize_ticks` is a Wilkinson-extended tick finder that overlaps (but is not identical
with) R's `pretty`; `StatsBase` gives histograms, percentiles and `histrange`. What is *missing*
is (a) a single, backend-neutral "class breaks" abstraction, (b) `pretty`/natural-breaks/standard-
deviation break algorithms, (c) robust colour-range clipping (QGIS's "cumulative count cut" and
"mean ± n·σ"), and (d) glue that emits `colorrange`/`colormap`/tick objects that *both* Makie and
Plots accept.

The single most useful architectural finding is that **`PlotUtils.cgrad` is a shared currency**:
Makie explicitly converts `PlotUtils.ColorGradient` (`MakieOrg/Makie.jl:Makie/src/conversions.jl:1659`)
and maps `PlotUtils.CategoricalColorGradient` to its `banded` colour-mapping mode
(`:Makie/src/conversions.jl:1675`), while Plots takes the same object as `seriescolor`. A new
package can therefore depend only on `PlotUtils` + `Colors`/`ColorSchemes` and remain
backend-neutral, with Makie/Plots-specific niceties in package extensions.

Second most useful finding: **Makie's tick protocol is an open, macro-free extension point**
(`Makie.get_tickvalues(ticks, scale, vmin, vmax)` / `Makie.get_ticklabels`, documented at
`:Makie/src/makielayout/lineaxis.jl:583-605`), and **Plots' `clims` accepts a function**
`series data -> (min, max)` (`JuliaPlots/Plots.jl:src/arg_desc.jl:129`). Both allow injecting
computed classification without a single macro.

Recommended initial scope: breaks + clipping + a `ClassBreaks` value type + NamedTuple emitters,
with Makie/Plots/CategoricalArrays/Distributions support behind `[weakdeps]`.

---

## 2. Sourced ecosystem overview

### 2.1 The colour layer

| Package | Latest registered | License | Role |
|---|---|---|---|
| `Colors.jl` | 0.13.1 | MIT | Colorant types, colour spaces, `distinguishable_colors` |
| `ColorSchemes.jl` | 3.31.0 (repo at 3.32.0) | MIT | `ColorScheme`, `get`, `getinverse`, `resample`, named scheme registry |
| `PlotUtils.jl` | 1.4.4 | MIT | `cgrad`, `ColorGradient`, `palette`, `optimize_ticks`, `zscale`, `adapted_grid` |
| `Colorfy.jl` | 2.2.2 | MIT | `colorfy(values; alpha, colorscheme, colorrange)` — values → `Colorant`s |
| `ColorSchemeTools.jl` | 1.6.0 | MIT | scheme construction/manipulation |
| `PerceptualColourMaps.jl` | 0.3.6 | — | Kovesi perceptually-uniform maps |

Licenses verified from `LICENSE.md` at each repo root (GitHub's licence API reports
`NOASSERTION` for several of these only because the file is `LICENSE.md` with a prose preamble;
the text itself is the MIT "Expat" licence — e.g. ColorSchemes
`JuliaGraphics/ColorSchemes.jl:LICENSE.md:1-5`, PlotUtils `JuliaPlots/PlotUtils.jl:LICENSE.md:1-4`,
StatsBase `JuliaStats/StatsBase.jl:LICENSE.md:1-4`, CategoricalArrays
`JuliaData/CategoricalArrays.jl:LICENSE.md:1-4`, Discretizers `sisl/Discretizers.jl:LICENSE.md:1-4`).
Makie is MIT (`MakieOrg/Makie.jl:LICENSE.md`).

`ColorSchemes.jl` exports `ColorScheme, get, getinverse, colorschemes, loadcolorscheme,
findcolorscheme, ColorSchemeCategory, resample` (`JuliaGraphics/ColorSchemes.jl:ColorSchemes/src/ColorSchemes.jl:18-31`)
and depends only on `ColorTypes`, `ColorVectorSpace`, `Colors`, `FixedPointNumbers`,
`PrecompileTools`, `Random` (`:ColorSchemes/Project.toml:7-13`) — a cheap dependency.

`PlotUtils.cgrad` is the pivotal API:

```julia
cgrad(colors, [values]; categorical = nothing, scale = nothing, rev = false, alpha = nothing)
```

(`JuliaPlots/PlotUtils.jl:src/colorschemes.jl:175,190-227`). Passing `categorical = true` returns a
`CategoricalColorGradient`; otherwise a `ContinuousColorGradient`
(`:src/colorschemes.jl:222-227`, types at `:src/colorschemes.jl:23,38,126`). `scale` accepts
`:log/:log10/:log2/:ln/:exp/:exp10` or an arbitrary function, remapping the stop positions
(`:src/colorschemes.jl:194-211`). The explicit `values` vector is exactly a normalised break
vector — i.e. **class breaks map onto `cgrad` stops with no impedance mismatch**.

### 2.2 Makie

Registered latest: **0.24.13** (`General:M/Makie/Versions.toml`). Note a trap: the GitHub repo
carries a `v1.0.0` tag pointing at commit `53cd1cc` dated 2025-06-03, which predates the monorepo
restructure and is *not* a released version — do not treat it as "Makie 1.0".

Colour attributes (verified in `MakieOrg/Makie.jl:Makie/src/basic_plots.jl:118-130,155-178` at
tag `v0.24.13`):

- `colormap` — `Symbol`, `Vector{<:Colorant}`, `PlotUtils.cgrad(...)`, `Makie.Reverse(...)`; default `:viridis`
- `colorscale::Function = identity` — "only works well together with `Colorbar` for `identity`, `log`, `log2`, `log10`, `sqrt`, `logit`, `Makie.pseudolog10`, `Makie.Symlog10`, `Makie.AsinhScale`, `Makie.SinhScale`, `Makie.LogScale`, `Makie.LuptonAsinhScale`, `Makie.PowerScale`"
- `colorrange` — `(lo, hi)` or `Makie.automatic` (data extrema)
- `lowclip` / `highclip` — colour for values below/above `colorrange`; default `automatic` (= first/last colormap colour)
- `nan_color` — default `:transparent`
- `alpha`

Runtime semantics are in `numbers_to_colors`
(`:Makie/src/colorsampler.jl:185-205`): the scale is applied to `(cmin, cmax)` and to each value,
then `NaN → nan_color`, `< scaled_cmin → lowclip`, `> scaled_cmax → highclip`. This is a direct
analogue of QGIS's out-of-range handling, and means **QGIS "clip to min/max" behaviour is
expressible in Makie today** by setting `lowclip`/`highclip` to `:transparent`.

Discrete/banded rendering: `Makie.Categorical(colormaplike)` (`:Makie/src/colorsampler.jl:253-276`)
maps to `categorical`; `PlotUtils.CategoricalColorGradient` maps to `banded`
(`:Makie/src/colorsampler.jl:283-284`, `:Makie/src/conversions.jl:1674-1675`).
`Makie.categorical_colors(cmap, n)` and `resample_cmap(cmap, n)` are the supported
resampling entry points (`:Makie/src/conversions.jl:1570,1578-1589`).

`Colorbar` block attributes relevant here (`:Makie/src/makielayout/types.jl:809-925`):
`label`, `ticks = Makie.automatic` (:839), `tickformat` (:841), `vertical` (:879),
`colormap` (:894), `limits` (:896), `colorrange` (:898), `highclip` (:900), `lowclip` (:902),
`scale = identity` (:904), `minorticks = IntervalsBetween(5)` (:923). `limits` and `colorrange`
are aliases and setting both is an error (`:Makie/src/makielayout/blocks/colorbar.jl:166-170`).

Tick protocol (macro-free extension point):

```julia
get_ticks(ticks, scale, formatter, vmin, vmax) =
    (get_tickvalues(ticks, scale, vmin, vmax), get_ticklabels(formatter, tickvalues))
```

`:Makie/src/makielayout/lineaxis.jl:583-596`; a plain vector is accepted via the fallback
`get_tickvalues(tickvalues, vmin, vmax) = convert(Vector{Float64}, tickvalues)` (`:797`), and
`(values, labels)` tuples via `get_ticks(::Tuple{Any,Any}, ...)` (`:607-`). Built-in locators:
`LinearTicks`, `WilkinsonTicks`, `MultiplesTicks`, `LogTicks`, `AngularTicks`
(`:Makie/src/makielayout/types.jl:55-104`, `:lineaxis.jl:789,805,836`).

Contour banding: `contourf` `levels` accepts an `Int` (n bands) or an
`AbstractVector{<:Real}` of "n consecutive edges from low to high, which result in n-1 levels",
plus `mode = :normal | :relative` and `extendlow`/`extendhigh`
(`:Makie/src/basic_recipes/contourf.jl:14-41`). This is the closest built-in to a QGIS graduated
raster renderer.

Theming: `set_theme!`, `with_theme`, `theme`, `update_theme!`
(`:Makie/src/theming.jl:209,235,251,285`); `Attributes` supports `keys`, `iterate`, `merge`
(`:Makie/src/attributes.jl:39,41,76,83`), so an `Attributes` bundle can be splatted as kwargs.

### 2.3 Plots / PlotsBase

Registered latest: **Plots 1.41.7**; the registry entry now carries `subdir = "Plots"`
(`General:P/Plots/Package.toml`). `PlotsBase` (the v2 split visible on `master`, where
`Plots/Project.toml` declares `version = "2.0.0"`) is **not registered in General** — treat
Plots 2.x as unreleased and target 1.41.x.

Attributes verified at tag `v1.41.4` (`JuliaPlots/Plots.jl:src/arg_desc.jl`):

- `:clims` — `Union{NTuple{2,Real}, Symbol, Function}`, "Fixes the limits of the colorbar: values, `:auto`, or **a function taking series data in and returning a `NTuple{2,Real}`**" (`:129`)
- `:colorbar_ticks` — "Tick values, `(tickvalues, ticklabels)`, `:auto`/`true`, or `:none`/`false`/`nothing`" (`:131`)
- `:levels` — `Union{AVec, Integer}`, contour levels (`:41`)
- `:seriescolor` — "Also describes the colormap for surfaces" (`:9`)
- `:color_palette` (`:107`)

`clims` is resolved through `process_clims` / `update_clims` / `get_clims`
(`JuliaPlots/Plots.jl:src/colorbars.jl:1-14,16-60`), and colourbar ticks through
`get_colorbar_ticks(sp; update, formatter)` (`:src/colorbars.jl:114-120`).

### 2.4 Statistics substrate

- `Statistics.quantile(v, p; sorted=false, alpha=1.0, beta=alpha)` — default `alpha = beta = 1` is
  linear interpolation, i.e. R type 7 (`JuliaStats/Statistics.jl:src/Statistics.jl:926-939,989-1023`).
- `StatsBase` exports `quantile`, `percentile`, `nquantile`, `quantilerank`, `percentilerank`,
  `Histogram`, `AbstractHistogram` (`JuliaStats/StatsBase.jl:src/StatsBase.jl:45-46,86-89,168-169`);
  `fit(Histogram, v; closed=:left, nbins=sturges(length(v)))` and `histrange(v, n, closed)`
  (`:src/hist.jl:27-42,190-218,303-309`).
- Package extensions (`[weakdeps]` + `[extensions]`) require Julia ≥ 1.9 and are the official
  replacement for Requires.jl (`JuliaLang/Pkg.jl:docs/src/creating-packages.md:446-503,615-625`).

---

## 3. QGIS feature inventory

### 3.1 The abstraction

`QgsClassificationRange` is `(label, lowerBound, upperBound)`
(`qgis/QGIS:src/core/classification/qgsclassificationmethod.h:53-85`).
`QgsClassificationMethod` is the abstract base
(`:src/core/classification/qgsclassificationmethod.h:94-330`), with:

- `MethodProperty` flags: `NoFlag`, `ValuesNotRequired` (deprecated), `SymmetricModeAvailable`,
  `IgnoresClassCount` (`:117-123`)
- `ClassPosition` = `LowerBound | Inner | UpperBound` — drives open-ended first/last labels (`:127-133`)
- constructor `(properties = NoFlag, codeComplexity = 1)`, where `codeComplexity` is documented as
  "the exponent in the big O notation" (`:135-140`, defined at `:src/core/classification/qgsclassificationmethod.cpp:45-49`)
- `valuesRequired()` — methods that only need `(min, max)` can classify without scanning data (`:185-189`)
- symmetry mode: `setSymmetricMode(enabled, symmetryPoint, astride)`; `astride = true` "will remove
  the symmetry point break so that the 2 classes form only one" (`:203-226`)
- label formatting: `labelFormat` (default `"%1 - %2"`, set at `:qgsclassificationmethod.cpp:48`),
  `labelPrecision` (clamped, negative precision scales by powers of ten and appends `"0"`s —
  `:qgsclassificationmethod.cpp:146-159`), `labelTrimTrailingZeroes` (`:228-240`)
- three `classes(...)` entry points: from a layer+expression, from a value list, or from bare
  `(minimum, maximum, nclasses)` (`:269-283`); `rangesToBreaks` converts ranges → breaks (`:243`)
- XML round-tripping and a parameter system reusing `QgsProcessingParameterDefinition`
  (`:285-297`, `:qgsclassificationmethod.cpp:185-203`)

Registry order (also the UI order):
`EqualInterval, Quantile, Jenks, StandardDeviation, PrettyBreaks, Logarithmic, FixedInterval`
(`:src/core/classification/qgsclassificationmethodregistry.cpp:30-39`); unknown ids fall back to
`QgsClassificationCustom` (`:55-61`).

### 3.2 The seven methods

| QGIS name | id | Flags / complexity | Algorithm |
|---|---|---|---|
| Equal Interval | `EqualInterval` | `SymmetricModeAvailable`, complexity 0 | `step = (max-min)/n`; last break forced to `maximum` for float safety. Symmetric mode forces even (or odd, if astride) class count and steps `2·min(distBelow, distAbove)/n` from the symmetry point (`qgsclassificationequalinterval.cpp:27-29,41-93`) |
| Equal Count (Quantile) | `Quantile` | default, complexity 1 | sorts, then for `i in 1:n-1`: `q = i/n`, `a = q*(n-1)`, `aa = floor(a)`, `r = a-aa`, `Xq = (1-r)*v[aa] + r*v[aa+1]`; appends `v[end]` (`qgsclassificationquantile.cpp:52-97`) |
| Natural Breaks (Jenks) | `Jenks` | default, complexity 1 | Fisher–Jenks DP over two `(n+1)×(k+1)` matrices; **samples** when `length(values) > 3000` (`qgsclassificationjenks.cpp:54-192`; `mMaximumSize = 3000` at `qgsclassificationjenks.h:40`) |
| Standard Deviation | `StdDev` | `SymmetricModeAvailable`, complexity 1 | population σ (divides by `n`), centres on mean (or the symmetry point), runs `prettyBreaks` on the z-scored range, forces symmetry about 0, rescales back. May return a different class count than requested (`qgsclassificationstandarddeviation.cpp:57-99`) |
| Pretty Breaks | `Pretty` | `SymmetricModeAvailable` | delegates to `QgsSymbolLayerUtils::prettyBreaks` (`qgsclassificationprettybreaks.cpp:40-57`) |
| Logarithmic Scale | `Logarithmic` | `NoFlag`, complexity 0 | `prettyBreaks(floor(log10(posmin)), ceil(log10(max)), n)` then `10^b`; parameter `ZERO_NEG_VALUES_HANDLE ∈ {no handling (faster), discard (slower), prepend range (slower)}` (`qgsclassificationlogarithmic.cpp:27-38,63-130`); labels rendered as `10^x` (`:132-146`) |
| Fixed Interval | `Fixed` | `IgnoresClassCount`, complexity 0 | parameter `INTERVAL` (double, min `1e-12`); walks `minimum` upward by `interval` (`qgsclassificationfixedinterval.cpp:26-32,55-75`) |

`prettyBreaks` itself (`qgis/QGIS:src/core/symbology/qgssymbollayerutils.cpp:4984-5085`) is
documented in-source as "C++ implementation of R's pretty algorithm … ported from R
implementation from 'labeling' R package", with `shrink = 0.75`, `highBias = 1.5`,
`adjustBias = 0.5 + 1.5*highBias`, `minimumCount = classes/3`, unit chosen from
`{1, 2, 5, 10} × 10^floor(log10(cell))`.

The user-manual descriptions of these modes are at
<https://docs.qgis.org/3.44/en/docs/user_manual/working_with_vector/vector_properties.html>
(§12.1.3.1 "Graduated Renderer"), which additionally documents:

- a **Histogram tab** showing "an interactive histogram of the values from the assigned field or
  expression. Class breaks can be moved or added using the histogram widget"
- graduation by **colour or size** ("The method to use to change the symbol: color or size"),
  with a size domain and unit
- "The legend format and the precision"
- Pretty Breaks defined as "a sequence of about n+1 equally spaced nice values … 1, 2 or 5 times a
  power of 10 (based on `pretty` from the R statistical environment)"
- Standard Deviation: "classes are built depending on the standard deviation of the values"

### 3.3 Raster side: clipping, outliers, colour-ramp shading

From <https://docs.qgis.org/3.44/en/docs/user_manual/working_with_raster/raster_properties.html>
(§13.1.3.1):

**Min/Max value settings** (four modes):
- *User defined* — override
- *Cumulative count cut* — "Removes outliers. The standard range of values is `2%` to `98%`, but it can be adapted manually."
- *Min / max* — full range
- *Mean +/- standard deviation × n* — "Creates a color table that only considers values within the standard deviation or within multiple standard deviations."

with orthogonal *Statistics extent* (Whole raster / Current canvas / Updated canvas — "dynamic
stretching") and *Accuracy* (Estimate vs Actual).

**Contrast enhancement** for gray/multiband: "No enhancement", "Stretch to MinMax",
"Stretch and clip to MinMax", "Clip to min max".

**Colour ramp shader** — the interpolation modes are:
- *Discrete* (`<=`): "The color is taken from the closest color map entry with equal or higher value"
- *Linear*: "linearly interpolated from the color map entries above and below the pixel value"
- *Exact* (`=`): "Only pixels with value equal to a color map entry are applied a color; others are not rendered"

and the classification modes: *Equal interval*, *Continuous* ("Classes number and color are fetched
from the color ramp stops"), *Quantile*. Plus `Label unit suffix`, `Label precision`, and
**Clip out of range values** — "By default, the linear method assigns the first class (respectively
the last class) color to values … lower than the set Min (respectively greater than the set Max).
Check this setting if you do not want to render those values." (This is precisely Makie's
`lowclip`/`highclip` = `automatic` vs `:transparent`.)

**Legend**: `Use continuous legend` toggle (continuous ramp vs separated class swatches), plus
prefix/suffix, min/max shown, number format, orientation (Vertical/Horizontal) and direction
(Maximum on top / Minimum on top; Maximum on right / Minimum on right).

### 3.4 Notable QGIS observations worth *not* copying

1. **Jenks sampling grows with `n`.** The sample size is
   `max(mMaximumSize, values.size()/10)` (`qgsclassificationjenks.cpp:90`), so a 1 000 000-value
   layer is sampled to 100 000 — and the DP is O(k·n²) with two `(n+1)×(k+1)` matrices
   (`:126-133`). That is ~10¹⁰ inner iterations and ~5.6 GB of matrices for k=7. A Julia
   implementation should cap the sample at a constant, or use unique-value compression with
   weights.
2. **`codeComplexity` looks miswired.** Jenks, Quantile and StdDev all use the base-class default
   of `1` (`qgsclassificationjenks.cpp:27-29`, `qgsclassificationquantile.cpp:25-27`,
   `qgsclassificationstandarddeviation.cpp:29-31`), while the UI warns only when
   `codeComplexity() > 1` (`src/gui/symbology/qgsgraduatedsymbolrendererwidget.cpp:1089-1098`), so
   at this commit the "Jenks is O(n²)" warning appears unreachable. Verified at `2e3de3b` only;
   treat as an observation, not a filed bug.
3. **Standard deviation uses the population σ** (divides by `n`, not `n-1`)
   (`qgsclassificationstandarddeviation.cpp:81-87`). Julia's `Statistics.std` defaults to
   `corrected = true`; a compatibility flag is needed if QGIS parity matters.
4. **Quantile ignores `minimum`/`maximum`** and derives everything from the sorted values
   (`qgsclassificationquantile.cpp:52-56`).

---

## 4. Julia prior-art matrix

| Package | Registered | License | Methods / API | Fit for this problem |
|---|---|---|---|---|
| **Breakers.jl** `technocrat/Breakers.jl` | 0.1.0 only | MIT (`LICENSE:1-3`) | `equal`, `quantile`, `fisher` (+threaded), `kmeans`, `fixed`; `get_breaks`, `get_bins`, `get_bin_indices`, `get_breaks_raw` returning `Dict{String,Vector{...}}` (`src/Breakers.jl:14-23,45-47`; `src/get_breaks.jl:12-44`) | Closest existing match, but: single 0.1.0 release; `Project.toml` puts `CSV`, `DataFrames`, `Documenter`, `BenchmarkTools`, `Test` in `[deps]` rather than `[extras]`/docs env (`Project.toml:7-19`) — unusable as a lightweight dependency; `Dict{String,...}` return type is not type-stable; no `pretty`, no standard-deviation, no logarithmic, no clipping. README self-reports Fisher–Jenks as "154x slower than R" at n=10 000. **Also a licensing question to check before reuse: it advertises "full R classInt compatibility" while R's `classInt` is GPL (≥2).** |
| **Discretizers.jl** `sisl/Discretizers.jl` | 3.2.4 | MIT | `DiscretizeUniformWidth`, `DiscretizeUniformCount`, `DiscretizeQuantile`, `DiscretizeMODL_*`, `DiscretizeBayesianBlocks`; `binedges`, `encode`/`decode`, `LinearDiscretizer`, `CategoricalDiscretizer` (`src/Discretizers.jl:14-56`) | Solid, ML-oriented. Has no cartographic methods (no pretty/Jenks/σ). Its `binedges(alg, data)` interface is a good naming precedent. Depends on `SpecialFunctions`. |
| **StatsDiscretizations.jl** `nignatiadis/StatsDiscretizations.jl` | 0.2.0 | — | Interval-first design on `IntervalSets.jl`: a discretizer is a callable/broadcastable, idempotent map `ℝ ∪ ℐ → ℐ`; `RealLineDiscretizer{:open,:closed}(grid)` (README) | Excellent conceptual precedent for the *closure* problem (left- vs right-closed intervals) that QGIS handles ad hoc. Worth mirroring the `{:open,:closed}` type parameter idea. |
| **Jenks.jl** `milankl/Jenks.jl` | **unregistered** | — | Iterative maximum-entropy-seeded refinement minimising L1 or L2 in-class deviation (README) | Heuristic, not the exact Fisher DP; unregistered. Useful as a fast approximate fallback design. |
| **MultivariateDiscretization.jl** | 0.1.0 | — | multivariate; out of scope | — |
| **CategoricalArrays.jl** | 1.1.1 | MIT | `cut(x, breaks; labels, extend, allowempty)` | The idiomatic Julia "apply breaks and label" primitive. Should be an *optional* integration, not a hard dep. |
| **StatsBase.jl** | 0.34.13 | MIT | `percentile`, `nquantile`, `quantilerank`, `fit(Histogram, ...)`, `histrange`, `sturges` (`src/StatsBase.jl:45-46,86-89,168-169`; `src/hist.jl:27-42,303-309`) | Supplies the histogram workflow and rule-of-thumb bin counts. |
| **Statistics** (stdlib) | — | MIT | `quantile(v, p; alpha=1.0, beta=alpha)` = R type 7 (`src/Statistics.jl:926-939`) | **Already bit-compatible with QGIS's quantile formula.** |
| **PlotUtils.jl** | 1.4.4 | MIT | `optimize_ticks(x_min, x_max; Q, k_min, k_max, k_ideal, granularity_weight, simplicity_weight, coverage_weight, niceness_weight, strict_span, span_buffer, scale)` (`src/ticks.jl:141-165`), `cgrad`, `zscale` | `optimize_ticks` is the Wilkinson "extended" algorithm — related to, but **not** R's `pretty`. QGIS pretty breaks are `{1,2,5}×10^k`; `optimize_ticks`'s default `Q` is `[(1,1),(5,.9),(2,.7),(2.5,.5),(3,.2)]`, which admits 2.5 and 3. A separate `pretty` is still needed for QGIS parity. `zscale` is an astronomy-style robust range — overlaps the "clipping" feature. |
| **Colorfy.jl** | 2.2.2 | MIT | `colorfy(values; alpha, colorscheme, colorrange)`; `colorrange` may be `:extrema` or a tuple (`src/Colorfy.jl:28-49`) | **Direct overlap on the "values → colours" step**, and an exemplary extension layout: `[weakdeps] CategoricalArrays, CoDa, Distributions, Unitful` with four extensions (`Project.toml:12-22`). Prefer integrating over duplicating. |
| **Makie.jl** | 0.24.13 | MIT | `LinearTicks`, `WilkinsonTicks`, `MultiplesTicks`; `get_tickvalues`/`get_ticklabels` protocol | Tick locators exist; a `ClassBreaks` locator is a ~10-line overload. |
| **MakieExtra.jl** | 0.2.8 | — | assorted Makie helpers | Precedent for a "Makie convenience" package; check for collisions before naming exports. |
| **GeoMakie.jl** / **Rasters.jl** / **GeoStats.jl** | 0.7.16 / 0.15.0 / 0.89.4 | — | geospatial plotting stacks | Likely *consumers*; GeoStats already pulls `Colorfy`. Worth coordinating rather than competing. |

**Gap summary.** No registered Julia package provides: R-style `pretty` breaks, QGIS-style standard
deviation breaks, logarithmic pretty breaks, symmetric/diverging break generation, cumulative-count-
cut clipping, or a break→(`colorrange`, `colormap`, ticks, labels) emitter for Makie/Plots.

---

## 5. Recommended core vs optional extensions

### 5.1 Core (no plotting dependencies)

Dependencies: `Statistics` (stdlib), `Colors`, `ColorSchemes`, `PlotUtils`. Optionally
`StatsBase` — but `quantile` comes from `Statistics`, so `StatsBase` may be demotable to a weakdep.

**Types**

- `abstract type BreakMethod end` and callable/functor concrete types — no macros needed:
  ```julia
  struct Quantile   <: BreakMethod; n::Int end
  struct EqualInterval <: BreakMethod; n::Int; symmetric::Union{Nothing,Float64} end
  struct Pretty     <: BreakMethod; n::Int end
  struct StdDev     <: BreakMethod; n::Int; corrected::Bool end
  struct Logarithmic<: BreakMethod; n::Int; nonpositive::Symbol end   # :keep/:discard/:prepend
  struct FixedInterval <: BreakMethod; interval::Float64 end
  struct NaturalBreaks <: BreakMethod; n::Int; maxsample::Int end     # Fisher–Jenks
  ```
- `breaks(method, x) -> Vector{Float64}` — the single verb. Mirrors `Discretizers.binedges`.
- `struct ClassBreaks{T, C}` holding `edges::Vector{T}`, closure (`:left`/`:right`, following
  `StatsDiscretizations`' `{:open,:closed}` idea and `StatsBase`'s `closed=` convention at
  `JuliaStats/StatsBase.jl:src/hist.jl:304`), labels, and optional `lowclip`/`highclip` flags.
- `ClipRange` / limits calculators: `MinMax()`, `Percentile(2, 98)` (QGIS "cumulative count cut"),
  `MeanStd(2)` (QGIS "mean ± n·σ"), `UserRange(lo, hi)`. Return `(lo, hi)`.

**Label formatting** — mirror `labelFormat` / `labelPrecision` / `labelTrimTrailingZeroes` and the
`LowerBound | Inner | UpperBound` position enum (`qgsclassificationmethod.h:127-133,228-240`), so
the first/last classes can render as `< x` / `≥ y` as StdDev does
(`qgsclassificationstandarddeviation.cpp:101-120`).

**Emitters** (the whole value proposition):

```julia
colorspec(cb::ClassBreaks; colormap = :viridis, categorical = true) ->
    NamedTuple  # (; colormap = PlotUtils.cgrad(...), colorrange = (lo, hi), highclip, lowclip)
```

Because `PlotUtils.cgrad` objects are consumed by Makie (`conversions.jl:1659`) *and* Plots, one
emitter serves both backends.

### 5.2 Extensions (`[weakdeps]` + `[extensions]`, Julia ≥ 1.9)

Following the `Colorfy.jl` layout (`JuliaGraphics/Colorfy.jl:Project.toml:12-22`) and the official
guidance (`JuliaLang/Pkg.jl:docs/src/creating-packages.md:458-503`):

| Extension | Trigger | Contents |
|---|---|---|
| `…MakieExt` | `Makie` | `Makie.get_tickvalues(::ClassBreaks, vmin, vmax)`, `Makie.get_ticklabels`; `Colorbar` convenience returning attribute NamedTuples; optional `Makie.Categorical` bridging |
| `…PlotsExt` | `Plots` (or `RecipesBase`) | `clims`-compatible closure factory, `colorbar_ticks` tuple builder |
| `…CategoricalArraysExt` | `CategoricalArrays` | `classify(x, cb) -> CategoricalArray` via `cut` |
| `…DistributionsExt` | `Distributions` | breaks from a fitted distribution's quantile function (`quantile(d, p)`), e.g. theoretical-quantile classing |
| `…UnitfulExt` | `Unitful` | unit-aware breaks and labels |
| `…ColorfyExt` | `Colorfy` | feed `colorrange`/`colorscheme` straight into `colorfy` |

Rationale for extensions rather than deps: Makie 0.24.x is on a fast breaking cadence and Plots is
mid-v2-split (PlotsBase unregistered), so hard dependencies would pin the package to a moving
target.

### 5.3 Deliberately out of scope for v0.1

- Symbol **size** graduation (QGIS's size method and "size assistant" with exponential/Flannery
  scaling) — different problem, different consumers.
- Categorical/unique-value renderers — `CategoricalArrays` + `ColorSchemes` already cover this.
- k-means / h-clust / b-clust / dpih / head-tails styles (R `classInt` has them:
  `r-spatial/classInt:man/classIntervals.Rd:27`) — these pull in `Clustering`/`KernSmooth`
  equivalents. Defer to a `…ClusteringExt`.
- Interactive histogram break editing (QGIS's Histogram tab) — needs `Observable`s and belongs in a
  Makie-side companion.

### 5.4 Algorithm complexity budget

| Method | Time | Space | Note |
|---|---|---|---|
| Equal / Fixed interval | O(n) for extrema, O(k) for breaks | O(k) | trivial |
| Pretty | O(k) given extrema | O(k) | port from the published R `pretty`/`labeling` description, **not** from QGIS's GPL C++ |
| Quantile | O(n) expected via `partialsort!` (what `Statistics.quantile!` does, `Statistics.jl:1026-1030`) | O(n) if copying | exact QGIS parity available |
| Standard deviation | O(n) + pretty | O(1) | population vs sample σ flag |
| Logarithmic | O(n) + pretty | O(1) | needs an explicit non-positive policy |
| Natural breaks (Fisher–Jenks, exact DP) | O(k·n²) | O(k·n) if only the backtrack row is kept | must compress to unique values with weights; cap sample at a **constant** (QGIS's growing sample is a trap, §3.4.1) |
| Head/tails, k-means 1-D | O(n log n) / O(k·n log n) with SMAWK | O(n) | extension territory |

---

## 6. Idiomatic, macro-free ways to inject `colorrange` / `colormap` / ticks

Ranked by how much they earn their keep. None requires a macro.

**1. NamedTuple splatting (the workhorse).** A function returns a `NamedTuple` of plot attributes;
callers splat it. Works identically in Makie and Plots because both take keyword arguments.

```julia
cs = colorspec(x, Quantile(5); colormap = :roma)   # (; colormap, colorrange, highclip, lowclip)
heatmap(x; cs...)                                  # Makie
heatmap(x; color = cs.colormap, clims = cs.colorrange)  # Plots
```

**2. `Base.merge` for user overrides.** `heatmap(x; merge(cs, (; colormap = :magma))...)` — since
kwargs are resolved left-to-right this gives predictable precedence without any DSL.

**3. Emit a `PlotUtils.cgrad` and let both backends consume it.** Makie converts
`PlotUtils.ColorGradient` (`MakieOrg/Makie.jl:Makie/src/conversions.jl:1659`) and treats
`CategoricalColorGradient` as `banded` (`:1675`); Plots takes it as `seriescolor`/`color`. Build it
from normalised breaks:
`cgrad(scheme, (edges .- lo) ./ (hi - lo); categorical = true)`
(signature at `JuliaPlots/PlotUtils.jl:src/colorschemes.jl:175,190-197`).

**4. A `ClassBreaks` tick locator via method overload (Makie).** The protocol is explicitly
documented as overloadable — "For custom ticks / formatter combinations, this method can be
overloaded directly, or both `get_tickvalues` and `get_ticklabels` separately"
(`MakieOrg/Makie.jl:Makie/src/makielayout/lineaxis.jl:583-596`):

```julia
Makie.get_tickvalues(cb::ClassBreaks, vmin, vmax) = collect(cb.edges)
Makie.get_ticklabels(::Makie.Automatic, cb::ClassBreaks) = cb.labels
```

Cheapest fallback if you do not want to define a type at all: pass the raw vector
(`get_tickvalues(tickvalues, vmin, vmax) = convert(Vector{Float64}, tickvalues)`, `:797`) or a
`(values, labels)` tuple (`:607-`).

**5. Plots' `clims`-as-a-function hook.** `:clims` is typed `Union{NTuple{2,Real}, Symbol, Function}`
and documented as "a function taking series data in and returning a `NTuple{2,Real}`"
(`JuliaPlots/Plots.jl:src/arg_desc.jl:129`, dispatched at `src/colorbars.jl:6`). So:

```julia
heatmap(z; clims = data -> limits(data, Percentile(2, 98)),
           colorbar_ticks = (edges, labels))
```

This defers the range computation to Plots' own pipeline — no recipe, no macro.

**6. Callable structs (functors) instead of a config DSL.** `(m::Quantile)(x) = breaks(m, x)` makes
methods composable with `map`, `|>` and broadcasting, and keeps everything inferable.

**7. Makie `Attributes` as a splattable bundle.** `Attributes` implements `keys`, `iterate` and
`merge` (`MakieOrg/Makie.jl:Makie/src/attributes.jl:39,41,76,83`), so an `Attributes` object can be
returned and splatted like a NamedTuple, and merged with a user's theme.

**8. Scoped defaults via themes, not globals.** `with_theme(f, theme)` /
`update_theme!` / `set_theme!` (`:Makie/src/theming.jl:209,235,285`) for Makie; `Plots.default(...)`
for Plots. Good for "make every plot in this script use 2–98% clipping".

**9. Discrete class rendering without custom drawing.**
Makie: `contourf(x, y, z; levels = edges, extendlow = :auto, extendhigh = :auto)` — `levels` as a
vector means "n consecutive edges from low to high, which result in n-1 levels or bands"
(`:Makie/src/basic_recipes/contourf.jl:14-41`).
Plots: `contourf(...; levels = edges)` (`JuliaPlots/Plots.jl:src/arg_desc.jl:41`).

**10. Colorbar from the plot object (Makie).** `Colorbar(fig[1, 2], plt; ticks = edges)` reuses
`extract_colormap` (`:Makie/src/makielayout/blocks/colorbar.jl:36-53,122-143`); remember `limits`
and `colorrange` are aliases and setting both errors (`:166-170`).

**Where a macro *might* be justified — and probably is not.** A `RecipesBase.@recipe` series recipe
(`classified_heatmap`) would let Plots users write `classified_heatmap(z, Quantile(5))`. But
`RecipesBase` is a real (if tiny) dependency, the recipe would need to live in an extension anyway,
and options 1/3/5 already deliver ~95% of the ergonomics. **Recommendation: ship no macros in
v0.1.** Revisit only if user feedback shows the splat form is a genuine friction point.

---

## 7. Risks and open design questions

### Licensing

- **QGIS is GPLv2-or-later** (`qgis/QGIS:COPYING:1-5`) and every classification file carries the
  GPL header. **Do not port the C++.** Reimplement from the algorithm descriptions and the
  underlying literature (Fisher 1958; Wilkinson/Talbot for ticks; R's documented `pretty`
  behaviour). Keep a written provenance note per algorithm.
- **R's `classInt` is `GPL (>= 2)`** (`r-spatial/classInt:DESCRIPTION`), and its own docs state the
  `"fisher"` style "uses the original Fortran code" (`man/classIntervals.Rd:64`) and `"jenks"` is
  "ported from Jenks' code" (`:66`). Any Julia package advertising "full classInt compatibility"
  under MIT deserves scrutiny before being used as a dependency or as a reference implementation —
  this specifically applies to `Breakers.jl`.
- Everything you would actually depend on (Colors, ColorSchemes, PlotUtils, Makie, StatsBase,
  CategoricalArrays, Colorfy, Discretizers) is MIT — no copyleft in the dependency cone.

### Ecosystem instability

- Makie is at **0.24.13** with a stale, misleading `v1.0.0` git tag; breaking minor releases are
  frequent. Plots is mid-split: registered at **1.41.7**, with `PlotsBase` (v2) **unregistered**.
  → Both must be `[weakdeps]`; compat bounds should be generous but explicit.
- `Colorfy.jl` overlaps the "values → colours" step. Decide early: integrate (extension) or
  duplicate. Duplicating risks fragmenting the JuliaGraphics/JuliaEarth stack.

### Semantics that need a decision

1. **Interval closure.** QGIS graduated ranges are `(lowerBound, upperBound]`-ish with special
   first/last handling; R `classInt` is left-closed *except* `"jenks"`, which "has to be
   right-closed" (`man/classIntervals.Rd:10,66`). `StatsBase.fit(Histogram, ...)` defaults to
   `closed = :left` (`src/hist.jl:304`). Pick one, encode it in the type
   (`ClassBreaks{:left}` / `{:right}`), and document round-trip behaviour with `CategoricalArrays.cut`.
2. **Breaks vs edges.** QGIS's `calculateBreaks` returns only **upper** bounds (n values for n
   classes), with the lower bound of class 1 supplied separately
   (`qgsclassificationquantile.cpp:70-95`). Julia convention (`Histogram`, `cut`, `contourf`) is
   n+1 **edges**. Choose n+1 edges and convert at the QGIS-compat boundary; document loudly.
3. **σ convention.** QGIS uses population σ (`qgsclassificationstandarddeviation.cpp:87`); Julia's
   `std` is corrected. Expose `corrected::Bool`.
4. **Class-count non-determinism.** Pretty and StdDev "may have a number of classes different from
   `classes`" (`qgsclassificationstandarddeviation.cpp:64-65`). The return type must not promise
   `length(edges) == n + 1`.
5. **Missing/NaN policy.** `NaN`, `missing`, `Inf`, and non-positive values under log scaling all
   need explicit policies. QGIS's logarithmic method surfaces this as a three-way user parameter
   (`qgsclassificationlogarithmic.cpp:30-37`) — a good precedent.
6. **Reproducibility.** Any sampling (Jenks) or k-means path needs an explicit `rng` argument;
   QGIS uses `QRandomGenerator` implicitly (`qgsclassificationjenks.cpp:22`).
7. **Does the range come from data or from the classification?** QGIS separates *min/max settings*
   (clipping/outliers) from *classification mode*. Keep those two orthogonal in the API too:
   `limits(x, Percentile(2, 98))` then `breaks(Quantile(5), x; limits)`.

### Naming and positioning

The workspace is called `makiecolors`, but the stated goal is *generic* utilities for Makie **and**
Plots. A Makie-specific name will discourage Plots users and imply a hard Makie dependency that the
extension design deliberately avoids. Consider a backend-neutral name
(e.g. `ClassBreaks.jl`, `ColorClasses.jl`, `GraduatedColors.jl`) and check for export collisions
with `Discretizers` (`binedges`), `StatsBase` (`Histogram`, `percentile`), `Colorfy` (`colorfy`) and
`MakieExtra` before registering.

### Verified vs inferred

- **Verified from source/docs:** every QGIS algorithm and attribute above; Makie's colour
  attributes, clip semantics, tick protocol, `Colorbar` attributes, `contourf` levels; Plots'
  `clims`/`colorbar_ticks`/`levels`; `cgrad` signature and Makie's `PlotUtils` bridges;
  `Statistics.quantile` interpolation rule; registry versions and licences.
- **Inferred / not verified:** performance numbers in Breakers.jl's README (self-reported, not
  re-benchmarked); the exact reachability of the QGIS Jenks warning (read statically at one commit);
  GeoMakie/Rasters/GeoStats integration appetite (not investigated beyond registry metadata).
- **Not searched:** ArcGIS/mapclassify (Python PySAL) feature parity; D3/`d3-scale` quantize/threshold
  scales; `Makie` `Voxels`/`Mesh` colour paths; internal/private org repos (none were specified).

---

## 8. Source index

**QGIS** (commit `2e3de3b`, GPLv2+):
- `src/core/classification/qgsclassificationmethod.h:53-85,94-140,185-243,269-297`
- `src/core/classification/qgsclassificationmethod.cpp:40-63,139-159,185-203`
- `src/core/classification/qgsclassificationmethodregistry.cpp:30-61`
- `src/core/classification/qgsclassificationequalinterval.cpp:27-29,41-93`
- `src/core/classification/qgsclassificationquantile.cpp:25-27,52-97`
- `src/core/classification/qgsclassificationjenks.cpp:27-29,54-192`; `qgsclassificationjenks.h:28-40`
- `src/core/classification/qgsclassificationstandarddeviation.cpp:29-31,57-99,101-127`
- `src/core/classification/qgsclassificationprettybreaks.cpp:26-57`
- `src/core/classification/qgsclassificationlogarithmic.cpp:27-38,63-146`
- `src/core/classification/qgsclassificationfixedinterval.cpp:26-32,55-75`
- `src/core/symbology/qgssymbollayerutils.cpp:4984-5085` (`prettyBreaks`)
- `src/gui/symbology/qgsgraduatedsymbolrendererwidget.cpp:1085-1101`
- Docs: <https://docs.qgis.org/3.44/en/docs/user_manual/working_with_vector/vector_properties.html> §12.1.3.1
- Docs: <https://docs.qgis.org/3.44/en/docs/user_manual/working_with_raster/raster_properties.html> §13.1.3.1

**Makie** (tag `v0.24.13`, MIT):
- `Makie/src/basic_plots.jl:118-130,155-178`
- `Makie/src/colorsampler.jl:156-205,236-238,253-284,314`
- `Makie/src/conversions.jl:1570-1589,1615-1677`
- `Makie/src/makielayout/types.jl:55-104,809-925`
- `Makie/src/makielayout/lineaxis.jl:583-620,784-836`
- `Makie/src/makielayout/blocks/colorbar.jl:10-53,122-176`
- `Makie/src/basic_recipes/contourf.jl:12-69,160-161`
- `Makie/src/attributes.jl:39-83`; `Makie/src/theming.jl:209-285`

**Plots** (tag `v1.41.4`, MIT):
- `src/arg_desc.jl:9,41,107,129,131`
- `src/colorbars.jl:1-14,16-60,114-120`

**PlotUtils** (v1.4.4, MIT): `src/PlotUtils.jl:1-38`; `src/colorschemes.jl:23,38,126,175,190-244`;
`src/ticks.jl:141-205`

**ColorSchemes** (repo 3.32.0, MIT): `ColorSchemes/src/ColorSchemes.jl:18-31`; `ColorSchemes/Project.toml:1-21`

**Colorfy** (2.2.2, MIT): `src/Colorfy.jl:26-49`; `Project.toml:12-22`

**Statistics / StatsBase**: `JuliaStats/Statistics.jl:src/Statistics.jl:926-1030`;
`JuliaStats/StatsBase.jl:src/StatsBase.jl:45-46,86-89,168-169`; `src/hist.jl:27-42,190-218,303-309`

**Breakers** (0.1.0, MIT): `src/Breakers.jl:1-47`; `src/get_breaks.jl:12-44`; `Project.toml:7-19`;
`README.md` (performance/complexity claims)

**Discretizers** (3.2.4, MIT): `src/Discretizers.jl:1-56`

**StatsDiscretizations** (0.2.0): `README.md`

**classInt** (GPL ≥2): `DESCRIPTION`; `man/classIntervals.Rd:10,13,26-36,42,48-68`

**Julia / Pkg**: `JuliaLang/Pkg.jl:docs/src/creating-packages.md:446-503,615-625`

**Registry**: `JuliaRegistries/General` @ `e501d6ae` — `M/Makie`, `P/Plots`, `P/PlotUtils`,
`C/Colors`, `C/ColorSchemes`, `S/StatsBase`, `B/Breakers`, `D/Discretizers`,
`S/StatsDiscretizations`, `C/Colorfy`, `C/CategoricalArrays` (`Package.toml`, `Versions.toml`,
`Deps.toml`)
