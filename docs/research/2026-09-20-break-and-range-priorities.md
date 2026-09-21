# Which class-break and colour-range method to implement next, judged by academic use

**Date:** 2026-09-20
**Status:** Research only — no code was written, no `src/` change, no commit.
**Scope:** What tools that scientific papers are actually made with offer and default to
(xarray, matplotlib, seaborn, ggplot2/scales, astropy, GMT, plus the GIS stacks R `classInt`,
PySAL `mapclassify`, ArcGIS Pro); what the colour-in-science literature says; licensing
constraints on the candidate algorithms; and the cost of each candidate inside the existing
ColorScales architecture.

**Builds on** [`2026-08-27-color-utilities-ecosystem.md`](2026-08-27-color-utilities-ecosystem.md),
which covered QGIS's classification internals, the `PlotUtils`/Makie/Plots substrate and the
Julia prior art. QGIS facts are *cited, not re-derived* here; everything else below is new
primary-source work.

Provenance of the new sources: repositories were cloned or files fetched on 2026-09-20.
Pinned revisions — `pysal/mapclassify` @ `f906871`, `r-spatial/classInt` @ `7607776`
(version 0.4-11), `pydata/xarray` @ `8de862c`, `matplotlib/matplotlib` tags `v3.10.1`,
`v3.1.0`, `v3.0.3`, `tidyverse/ggplot2` @ `4e88664`, `r-lib/scales` @ `35b2a77`,
`astropy/astropy` @ `5d68e4f`, `mwaskom/seaborn` @ `f04b6cd`,
`GenericMappingTools/gmt` @ `e09bb42`, `geopandas/geopandas` @ `c0e3867`,
`SunnySuite/Sunny.jl` @ `2a5c6d5`, `technocrat/Breakers.jl` @ `d7623a0`,
`JuliaRegistries/General` @ default-branch head. All DOIs below were resolved against the
Crossref API on 2026-09-20.

---

## 1. Executive summary

**The single largest gap in ColorScales for academic use is not a break method at all — it is a
colour range.** Four independent, first-party scientific tools implement *the same formula* for
diverging data, and ColorScales cannot express it:

| Tool | Code | Formula |
|---|---|---|
| xarray | `plot/utils.py:260-267` | `vlim = max(abs(vmin-center), abs(vmax-center)); vmin, vmax = center-vlim, center+vlim` |
| matplotlib `CenteredNorm` | `colors.py:2500-2504` | `halfrange = max(vcenter-A.min(), A.max()-vcenter)` |
| R `scales::rescale_mid` (what every `ggplot2` `*_gradient2`/`*_steps2` uses) | `R/bounds.R:119` | `extent <- 2 * max(abs(from - mid))` |
| astropy `SymmetricInterval` | `visualization/interval.py:256-264` | `radius = max(max(values)-midpoint, midpoint-min(values))` |

plus GMT `grd2cpt -S`, "Force the color table to be symmetric about zero"
(`doc/rst/source/grd2cpt.rst:190-194`), and seaborn, which reaches the same visual result by the
complementary route of truncating the colormap (`seaborn/matrix.py:238-241`). xarray applies the
rule **by default** whenever `vmin < 0 < vmax` (`plot/utils.py:250-263`); ggplot2 defaults
`midpoint = 0` (`R/scale-gradient.R:120`). astropy added its version as recently as 7.2.0
(2025-11-25), evidence that the need is live, not legacy.

So the answer to the two questions asked:

- **Break method to do first: `ManualBreaks(edges)`** — explicit edges are the *only* classing
  input that every surveyed tool accepts, GIS and scientific alike, they are what a
  same-edges-across-panels figure needs, and they cost ~15 lines here.
- **Colour-range method to do first: `Centered(inner; center = 0)`** (name `Symmetric` is taken
  by `LinearAlgebra`, verified) — the diverging-data case above, which is presently
  inexpressible and is the most common scientific raster after a plain sequential field.

Of the two, `Centered` is the more valuable *capability*; `ManualBreaks` is the more valuable
*break method*. If only one thing ships, ship `Centered`.

The framing in the brief survives contact with the evidence, with one correction: manual edges
are cheap and universal but **not transformative**, because `FixedRange(lo, hi) + EqualInterval(n)`
already reproduces uniformly spaced fixed edges today, and `ClassBreaks(edges)` +
`classgradient` + `ColorSpec(...)` can already be assembled by hand (§7.2). The gap it closes is
non-uniform edges plus one-call ergonomics, not a missing capability.

Deliberately **not** to implement: Jenks/natural breaks in core (ArcGIS's own documentation says
it is "not useful for comparing multiple maps"), standard-deviation breaks (already expressible
as `MeanStd` + `EqualInterval`), symmetric-mode break generation (falls out of `Centered` +
`EqualInterval`), head/tails, geometric interval, and logarithmic *breaks* (log belongs in the
gradient's scale, not in the edges).

---

## 2. What the tools people publish with actually offer

### 2.1 The scientific plotting stacks

These are the tools behind most journal figures outside cartography. **None of them ships
Jenks, quantile-free clustering, or any other choropleth classifier.** Their entire classing
vocabulary is "a count of nice levels" or "the exact edges I give you"; their sophistication
goes into *ranges and norms* instead.

**xarray** (`8de862c`) — the closest thing in the ecosystem to ColorScales' job, and a direct
model for it:

- `ROBUST_PERCENTILE = 2.0` (`xarray/plot/utils.py:54`); `robust=True` documented as "the
  colormap range is computed with 2nd and 98th percentiles instead of the extreme values"
  (`xarray/plot/dataarray_plot.py:1357-1359`), implemented at `plot/utils.py:234-246`. This is
  exactly ColorScales' `Percentile(2, 98)`.
- Divergence is inferred and then enforced symmetrically:
  `divergent = (vmin < zero < vmax) or not center_is_none or levels_are_divergent`
  (`plot/utils.py:250-255`), then `vmin, vmax = -vlim, vlim` around the centre
  (`:260-267`). The colormap switches to `RdBu_r` versus `viridis` on the same flag
  (`:290-294`, defaults in `xarray/core/options.py:85-86`).
- `center : float or False` — "The value at which to center the colormap. Passing this value
  implies use of a diverging colormap. Setting it to `False` prevents use of a diverging
  colormap." (`dataarray_plot.py:1353-1356`).
- Discrete classes come in exactly two flavours: `levels` as an integer → `MaxNLocator(levels-1)`
  nice levels, or `levels` as an array → those edges verbatim
  (`plot/utils.py:301-307`; docstring `dataarray_plot.py:822-827`). Note `vmin, vmax = levels[0],
  levels[-1]` at `:307` — the nice levels *become* the colour range, which is precisely what
  ColorScales' `Pretty` already does.
- Multi-panel figures share one scale by construction: `FacetGrid.map_dataarray` computes
  `cmap_params` once from `self.data.to_numpy()` and pushes it into every panel
  (`xarray/plot/facetgrid.py:383-395`).

**matplotlib** (`v3.10.1`) — the norms tell the story of what was worth adding:

- `TwoSlopeNorm(vcenter, vmin, vmax)`, "Useful when mapping data with an unequal rates of change
  around a conceptual center, e.g., data that range from -2 to 4, with 0 as the midpoint"
  (`lib/matplotlib/colors.py:2350-2381`). It entered as `DivergingNorm` in 3.1.0 (present at
  `v3.1.0:lib/matplotlib/colors.py:962`, absent in `v3.0.3`) and was renamed in 3.2.0 because
  "'diverging' does not describe or evoke the norm's mapping function"
  (`doc/api/prev_api_changes/api_changes_3.2.0/deprecations.rst:268-276`).
- `CenteredNorm(vcenter=0, halfrange=None)`, "Normalize symmetrical data around a center (0 by
  default). Unlike `TwoSlopeNorm`, `CenteredNorm` applies an equal rate of change around the
  center." (`colors.py:2445-2492`); `autoscale` sets `halfrange = max(vcenter-A.min(),
  A.max()-vcenter)` (`:2500-2504`). Added in 3.4.0 under the heading "New `CenteredNorm` for
  symmetrical data around a center": "In cases where data is symmetrical around a center, for
  example, positive and negative anomalies around a center zero … a new norm that automatically
  creates a symmetrical mapping around the center."
  (`doc/users/prev_whats_new/whats_new_3.4.0.rst:553-586`).
- `BoundaryNorm(boundaries, ncolors, …)`: "Monotonically increasing sequence of at least 2 bin
  edges: data falling in the n-th bin will be mapped to the n-th color" (`colors.py:2930-2950`).
  That is the whole of matplotlib's discrete classing — user-supplied edges.
- `LogNorm = make_norm_from_scale(partial(scale.LogScale, nonpositive="mask"))(Normalize)`
  (`colors.py:2766-2769`): the non-positive policy is *mask*, and log is a **scale**, not a set
  of breaks.

**seaborn** (`f04b6cd`) — same two knobs, different mechanism: `robust` → `np.nanpercentile(…, 2)`
/ `98` (`seaborn/matrix.py:198-207`), and `center` → recentre the *colormap* rather than the
limits, using the identical half-range formula
`vrange = max(vmax - center, center - vmin)` and then slicing the colormap so the neutral colour
lands on `center` (`matrix.py:223-247`). Useful counterpoint: centring can be done by widening
limits (xarray/matplotlib/astropy/ggplot2) or by truncating the colormap (seaborn). The former
wastes dynamic range; the latter needs to touch the gradient. §7.1 revisits this.

**ggplot2 / scales** (`4e88664` / `35b2a77`):

- `scale_colour_gradient2(..., midpoint = 0, ...)` and `scale_fill_gradient2` build on
  `mid_rescaler(mid = midpoint)` (`R/scale-gradient.R:113-142`); documented as "The midpoint (in
  data value) of the diverging scale. Defaults to 0."
- The binned (classed) equivalents `scale_*_steps2` carry the same `midpoint = 0`
  (`R/scale-steps.R:62-116`); `scale_*_fermenter` binds a binned scale to a Brewer palette
  (`R/scale-brewer.R:153-189`).
- The rescaler is symmetric, not two-slope: `extent <- 2 * max(abs(from - mid))`
  (`scales:R/bounds.R:102-121`).
- Binned scales default to `nice.breaks = TRUE` and the transform's break function
  (`ggplot2:R/scale-.R:1492+`, `get_breaks`), and every transform defaults to
  `breaks = extended_breaks()` (`scales:R/transform.R:31-41`), i.e. Talbot–Lin–Hanrahan extended
  Wilkinson (`scales:R/breaks.R:105-120`, referencing the paper directly). **ColorScales' `Pretty`
  already occupies this slot**; `scales::breaks_log` (`R/breaks-log.R:52-…`) is the only other
  numeric break generator shipped.

**astropy** (`5d68e4f`) — the closest existing design to ColorScales' `ColorRangeMethod`
hierarchy, and worth mirroring in spirit. `astropy/visualization/interval.py:16-24`:

```
AsymmetricPercentileInterval, BaseInterval, ManualInterval, MinMaxInterval,
PercentileInterval, SymmetricInterval, ZScaleInterval
```

Mapping onto ColorScales: `ManualInterval` ≙ `FixedRange`, `MinMaxInterval` ≙ `Extrema`,
`PercentileInterval`/`AsymmetricPercentileInterval` ≙ `Percentile`, `ZScaleInterval` ≙
`PlotUtils.zscale`, and `SymmetricInterval` is the one with no counterpart:

> "Interval based on a symmetric radius away from a midpoint. … radius : float or None — The
> amount the interval extends to either side of the midpoint … If None, the radius is
> automatically determined such that the resulting interval contains both the image minimum and
> maximum (ignoring NaNs). midpoint : float, optional — … Defaults to zero."
> (`interval.py:237-265`)

Added in astropy **7.2.0** (2025-11-25): "Added an image interval option (`SymmetricInterval`)
for specifying a symmetric extent about a midpoint, and the extent that contains both the image
minimum and maximum can be automatically determined. [#18602]" (`CHANGES.rst`, §7.2.0). Note the
absence of any Jenks/quantile-classing machinery in astropy's visualization module: ranges only.

**GMT** (`e09bb42`) — the one publication-grade tool with a *richer* range vocabulary than
ColorScales. `makecpt -S<mode>` (`doc/rst/source/makecpt.rst:164-176`):

| GMT | Meaning | ColorScales |
|---|---|---|
| `-Sr` | data min/max | `Extrema()` |
| `-S<inc>[+d]` | min/max rounded to a multiple of `inc` | ≈ `Pretty` (widening behaviour) |
| `-Sa<scl>` | symmetric range around the **mean** ± `scl`·σ | `MeanStd(scl)` |
| `-Sm<scl>` | symmetric range around the **median** ± `scl`·L1 scale | *missing* (§6.2) |
| `-Sp<scl>` | symmetric range around the **mode** (LMS) ± `scl`·LMS scale | *missing, niche* |
| `-Sq<low>/<high>` | low to high quartile (percentages) | `Percentile(low, high)` |

"L1 scale" is defined in `doc/rst/source/grdinfo.rst:133-139` as `1.4826 * Median Absolute
Deviation (MAD)` — so `-Sm` is exactly the robust `median ± n·MAD` candidate, shipped in a
first-party scientific mapping tool. `grd2cpt -S h|l|m|u` is the centring one: "Force the color
table to be symmetric about zero (from -R to +R)" with the radius chosen from
`|zmin|`, `|zmax|`, their min or their max (`grd2cpt.rst:188-195`). `grd2cpt` also defaults to
histogram equalisation over the CDF (`grd2cpt.rst:41-55`) — a quantile-style *continuous*
mapping, which ColorScales' `Quantile` breaks approximate discretely. `makecpt -Q` is a
logarithmic *interpolation scheme* and `-T…+l` a log-spaced array (`makecpt.rst:157-163,178-188`):
again, log as a scale.

**Julia practice** — with no package-level support, users hand-roll centring. A GitHub code search
for symmetric colour ranges in Julia returns, among others, `NumericalEarth/BjerknesWorkshop`
(`# symmetric colorrange around zero, fixed for all frames`), `eschnett/HexVTKHDF.jl`
(`"Symmetric colorrange about zero (max |finite value|)."`), `CliMA/Oceananigans.jl` validation
scripts, and `SunnySuite/Sunny.jl`, which exposes it as a documented plotting option:
"`allpositive`: … If false, the default colors will be symmetric about zero intensity.
`saturation`: If `colorrange` is not explicitly set, this dimensionless parameter defines the
upper saturated intensity value as a quantile of maximum intensities"
(`ext/PlottingExt/PlotIntensities.jl:319-326`, @ `2a5c6d5`). That is `Centered(Percentile(...))`
re-implemented per package.

### 2.2 The GIS / choropleth stacks

R **`classInt` 0.4-11** (`7607776`) — the reference implementation of cartographic classing;
GPL (≥2), see §8. `classIntervals(var, n, style = "quantile", …)`, styles: `"fixed", "sd",
"equal", "pretty", "quantile", "kmeans", "hclust", "bclust", "fisher", "jenks", "dpih",
"headtails", "maximum", "box"` (`man/classIntervals.Rd`, usage + `\item{style}`). Points that
matter here:

- Default `style = "quantile"`; default `n` is `nclass.Sturges` (`R/classInt.R:110-114`).
- `"fixed"` "permits a `classIntervals` object to be specified with given breaks, set in the
  `fixedBreaks` argument … this style can be used to insert rounded break values"
  (`Rd`, Details; `R/classInt.R:148-171`).
- `"sd"` "chooses breaks based on `pretty` of the centred and scaled variables, and may have a
  number of classes different from n" — `sbrks <- pretty(scale(var), n)` then rescaled
  (`R/classInt.R:173-187`). Same design as QGIS's StdDev (prior note §3.2), and it supports an
  explicit multiples vector `sd_m = c(-Inf,-2,-1,0,1,2,Inf)`.
- `"fisher"` versus `"jenks"`: "The 'fisher' style uses the algorithm proposed by W. D. Fisher
  (1958) … **This style should always be preferred to 'jenks' as it uses the original Fortran
  code and runs nested for-loops much faster**"; `"jenks"` "has been ported from Jenks' code …
  Note that the sense of interval closure is reversed from the other styles, and in this
  implementation has to be right-closed" (`Rd`, Details; `R/classInt.R:254-266`).
- Both subsample above `largeN = 3000L` with `samp_prop = 0.1`, explicitly described in the Rd as
  "the QGIS sampling threshold" / "QGIS 10% sampling proportion" — the same trap flagged in the
  prior note §3.4.1.
- `"headtails"` implements Jiang (2013) with `thr = 0.4` (`R/classInt.R:336-359`); `"box"`
  produces a fixed 7 breaks / 6 classes from the quartiles and 1.5·IQR fences
  (`R/classInt.R:380+`); `"maximum"` takes the `k-1` largest gaps (`R/classInt.R:360-379`).

PySAL **`mapclassify`** (`f906871`, BSD-3-Clause per `LICENSE.txt`) — `CLASSIFIERS = (BoxPlot,
EqualInterval, FisherJenks, FisherJenksSampled, HeadTailBreaks, JenksCaspall,
JenksCaspallForced, JenksCaspallSampled, MaxP, MaximumBreaks, NaturalBreaks, Quantiles,
Percentiles, PrettyBreaks, StdMean, UserDefined)` (`mapclassify/classifiers.py:41-58`). Notes:

- Default `k = 5` (`classifiers.py:60`); its printed intervals are right-closed with an inclusive
  first class, `[ 0.13, 822.39] / ( 822.39, 1644.66]` (`README.md`) — the same convention
  ColorScales chose.
- `natural_breaks` docstring: "**Jenks natural breaks is k-means in one dimension**", implemented
  as 10 restarts of k-means from random centroids (`classifiers.py:551-586`) — i.e. the
  heuristic, non-deterministic route, separate from the exact `FisherJenks` DP
  (`classifiers.py:587-627`, an `(n+1)×(k+1)` two-matrix DP, provenance credited to a blog post
  "based on a JAVA and Fortran code").
- `StdMean(y, multiples = [-2,-1,1,2], anchor = False)` (`classifiers.py:1770-1830`) —
  standard-deviation breaks as an explicit multiples vector, optionally anchored so "one of the
  intervals will have its closed upper bound equal to the mean of y".
- `Percentiles(y, pct = [1, 10, 50, 90, 99, 100])` (`classifiers.py:1459-1470`),
  `BoxPlot(y, hinge = 1.5)` (`classifiers.py:1579-1606`).
- **`Pooled(Y, classifier = "Quantiles")`, "Applying global binning across columns"**
  (`mapclassify/pooling.py:28-80`): a dedicated class whose entire purpose is one shared set of
  edges across several columns/panels, with per-column classifiers that reuse the global bins.
  Direct external support for the multi-panel/reproducibility framing.
- geopandas, the usual consumer, exposes all of them through `scheme=` but uses
  `scheme='quantiles'` in every example in its mapping guide
  (`doc/source/docs/user_guide/mapping.rst:123-163`, @ `c0e3867`).

**ArcGIS Pro** (docs fetched 2026-09-20, "Data classification methods"): Natural breaks (Jenks),
Quantile, Equal interval, Defined interval, Manual interval, Geometrical interval, Standard
deviation. Two sentences are decisive for this question:

> "Natural breaks are data-specific classifications and **not useful for comparing multiple maps
> built from different underlying information**."

> "Use **manual interval** to define your own classes, to manually add class breaks, and to set
> class ranges that are appropriate for the data. Start with one of the standard classifications,
> then switch to manual interval classification to make refinements as needed."

The geometrical-interval description is prose only — "The geometric coefficient in this
classifier can change once (to its inverse) to optimize the class ranges. The algorithm creates
geometric intervals by minimizing the sum of squares of the number of elements in each class" —
with no published specification, which by itself rules it out as a faithfully reimplementable
method (§8, §11).

**QGIS** — see the prior note §3 (seven methods, `SymmetricModeAvailable` flag,
`setSymmetricMode(enabled, symmetryPoint, astride)`, pretty-breaks-on-the-z-scale StdDev,
logarithmic with a three-way non-positive parameter, Jenks sampling at 3000). Not re-derived.

### 2.3 Evidence table: who ships what

Legend: ✓ present, — absent, ≈ present in a different guise.

| Method | QGIS¹ | ArcGIS Pro | classInt | mapclassify | matplotlib | xarray | ggplot2 | GMT | astropy | **ColorScales** |
|---|---|---|---|---|---|---|---|---|---|---|
| Equal interval | ✓ | ✓ | ✓ | ✓ | ≈ `BoundaryNorm`+linspace | ≈ `levels=N` w/ vmin,vmax | ≈ | ✓ `-T min/max/inc` | — | **✓ done** |
| Quantile | ✓ | ✓ | ✓ (default) | ✓ | — | — | — | ≈ `grd2cpt` CDF | — | **✓ done** |
| Pretty / nice / extended | ✓ | — | ✓ | ✓ | ≈ `MaxNLocator` | ✓ `levels=N` | ✓ (default) | ✓ `-S<inc>` | — | **✓ done** |
| **Manual / explicit edges** | ✓ custom | ✓ | ✓ `fixed` | ✓ `UserDefined` | ✓ `BoundaryNorm` | ✓ `levels=[…]` | ✓ `breaks=` | ✓ `-T <list\|file>` | — | **missing** |
| Natural breaks (Fisher/Jenks) | ✓ | ✓ | ✓ ×2 | ✓ ×5 | — | — | — | — | — | missing |
| Standard deviation | ✓ | ✓ | ✓ `sd` | ✓ `StdMean` | — | — | — | ≈ `-Sa` (range) | — | ≈ `MeanStd`+`EqualInterval` |
| Logarithmic | ✓ | — | — | — | ✓ `LogNorm` (scale) | ≈ via norm | ✓ `breaks_log` | ✓ `-Q`, `-T+l` | ✓ log stretch | missing (scale, not breaks) |
| Head/tails (Jiang 2013) | — | — | ✓ | ✓ | — | — | — | — | — | missing |
| Box/quartile breaks | — | — | ✓ `box` | ✓ `BoxPlot` | — | — | — | — | — | missing |
| Geometric interval | — | ✓ | — | — | — | — | — | — | — | missing |
| Maximum breaks | — | — | ✓ | ✓ | — | — | — | — | — | missing |
| **Range: extrema** | ✓ | ✓ | n/a | n/a | ✓ | ✓ | ✓ | ✓ `-Sr` | ✓ `MinMaxInterval` | **✓ done** |
| **Range: percentile clip** | ✓ 2–98 | — | n/a | n/a | — | ✓ `robust` 2/98 | — | ✓ `-Sq` | ✓ `PercentileInterval` | **✓ done** |
| **Range: mean ± n·σ** | ✓ | — | n/a | n/a | — | — | — | ✓ `-Sa` | — | **✓ done** |
| **Range: user-supplied** | ✓ | ✓ | n/a | n/a | ✓ `vmin/vmax` | ✓ | ✓ `limits=` | ✓ `-T` | ✓ `ManualInterval` | **✓ done** |
| **Range: centred/symmetric** | ✓ symmetric mode | — | — | ≈ `StdMean` multiples | ✓ `CenteredNorm` | ✓ **by default** | ✓ `midpoint=0` | ✓ `grd2cpt -S` | ✓ `SymmetricInterval` | **missing** |
| Range: median ± n·MAD | — | — | — | — | — | — | — | ✓ `-Sm` | — | missing |
| Range: zscale (IRAF) | — | — | — | — | — | — | — | — | ✓ | ≈ `PlotUtils.zscale` |

¹ QGIS column from the prior note, §3.2.

Read down the "scientific stacks" columns (matplotlib → astropy): the only classing they offer is
nice-levels-or-explicit-edges, and the only thing they compete on is the range. Read across the
"centred/symmetric" row: everyone has it except ColorScales.

---

## 3. What the literature says

All DOIs resolved via Crossref on 2026-09-20.

- **Crameri, Shephard & Heron (2020), "The misuse of colour in science communication",
  *Nature Communications* 11:5444, DOI [10.1038/s41467-020-19160-7](https://doi.org/10.1038/s41467-020-19160-7).**
  Main text: "If the data is divergent about a central value (e.g., centred about zero), a
  divergent or a multi-sequential colour map should be chosen that clearly and intuitively
  distinguishes either side of the axis". Also the core perceptual-uniformity argument: "a colour
  axis (commonly termed colour bar) needs to have equidistant colour gradients … a certain data
  variation (e.g., a 5 °C temperature drop) should appear the same no matter whether it occurs at
  low temperatures (–10 °C) or high temperatures (30 °C)". The paper argues about *colour map
  choice*; it does not itself specify limit arithmetic (see §11).
- **Thyng, Greene, Hetland, Zimmerle & DiMarco (2016), "True Colors of Oceanography: Guidelines
  for Effective and Accurate Colormap Selection", *Oceanography* 29(3):9-13, DOI
  [10.5670/oceanog.2016.66](https://doi.org/10.5670/oceanog.2016.66).** The explicit statement of
  the symmetric-limits requirement: "Data can also be plotted relative to a critical value; for
  example, anomalies or changes over time may be presented as deviations about some nominal
  value. … The balance colormap in Figure 1 is diverging where **positive and negative data of
  the same absolute value are given equal weight**." Equal weight for ±x is only true when the
  limits are symmetric about the centre. Also notes the deliberate exception (`oxy`, "Although
  its inflection point is not centered"), i.e. the centre is a parameter, not always zero.
- **Moreland (2009), "Diverging Color Maps for Scientific Visualization", ISVC, LNCS, DOI
  [10.1007/978-3-642-10520-3_9](https://doi.org/10.1007/978-3-642-10520-3_9)** (read from the
  author's own expanded PDF, `kennethmoreland.com/color-maps/ColorMapsExpanded.pdf`): "Diverging
  color maps are typically used to represent a scalar with a significant value at or near the
  median … the diverging color map visually divides scalar values into three logical regions:
  low, midrange, and high values." The neutral midpoint is a *visual boundary*, which is exactly
  why it must be placed on the meaningful value rather than on the arithmetic middle of the data.
- **IPCC WGI TSU (2018), *IPCC Visual Style Guide for Authors*, December 2018** (Gomis & Pidcock;
  `ipcc.ch/site/assets/uploads/2019/04/IPCC-visual-style-guide.pdf`), p. 7: "To represent
  diverging data, such as temperature change, it is best to use two contrasting hues, **where
  white is the central value** and an increase in colour darkness indicates a more
  positive/negative value. … sequences do not exceed 11 colours since further divisions within
  the scheme lead to a set of adjacent colours that are hard to distinguish from each other."
  A publication-facing instruction to pin the central value, plus an upper bound on sensible
  class counts.
- **Stauffer, Mayr, Dabernig & Zeileis (2015), "Somewhere Over the Rainbow: How to Make Effective
  Use of Colors in Meteorological Visualizations", *BAMS* 96(2):203-216, DOI
  [10.1175/BAMS-D-13-00155.1](https://doi.org/10.1175/BAMS-D-13-00155.1)**; and the HCL toolbox
  papers **Zeileis, Hornik & Murrell (2009), *CSDA* 53(9):3259-3270, DOI
  [10.1016/j.csda.2008.11.033](https://doi.org/10.1016/j.csda.2008.11.033)** and **Zeileis,
  Fisher, Hornik, Ihaka et al. (2020), "colorspace: A Toolbox for Manipulating and Assessing
  Colors and Palettes", *JSS* 96(1), DOI
  [10.18637/jss.v096.i01](https://doi.org/10.18637/jss.v096.i01)**. These are palette-construction
  sources (diverging palettes are built as two balanced sequential arms); they constrain the
  *colormap*, not the breaks, so they bear on ColorScales only through the centring requirement.
- **Fisher (1958), "On Grouping for Maximum Homogeneity", *JASA* 53(284):789-798, DOI
  [10.1080/01621459.1958.10501479](https://doi.org/10.1080/01621459.1958.10501479).** The exact
  dynamic program. Published method → freely reimplementable (§8). classInt's Rd points at the
  original Fortran, `lib.stat.cmu.edu/cmlib/src/cluster/fish.f`.
- **Jenks & Caspall (1971), "Error on Choroplethic Maps: Definition, Measurement, Reduction",
  *Annals AAG* 61(2):217-244, DOI
  [10.1111/j.1467-8306.1971.tb00779.x](https://doi.org/10.1111/j.1467-8306.1971.tb00779.x).** The
  cartographic error framing; the "Jenks" implementations in the wild are iterative heuristics
  ported from Jenks' own code, distinct from Fisher's exact DP (classInt Rd, Details;
  mapclassify's separate `JenksCaspall*` classes).
- **Wang & Song (2011), "Ckmeans.1d.dp: Optimal k-means Clustering in One Dimension by Dynamic
  Programming", *The R Journal* 3(2):29-33, DOI
  [10.32614/RJ-2011-015](https://doi.org/10.32614/RJ-2011-015).** "The heuristic k-means
  algorithm, widely used for cluster analysis, does not guarantee optimality"; "The result of
  heuristic k-means clustering, heavily dependent on the initial cluster centers, is neither
  always optimal nor **repeatable**"; "We present an exact dynamic programming solution with a
  runtime of O(n²k) to the 1-D k-means problem." Combined with mapclassify's "Jenks natural
  breaks is k-means in one dimension", this establishes: *natural breaks done properly = exact
  1-D k-means = Fisher's DP*, and any heuristic variant is irreproducible — disqualifying for a
  figure that must be regenerable.
- **Rey, Stephens & Laura (2016), "An evaluation of sampling and full enumeration strategies for
  Fisher Jenks classification in big data settings", *Transactions in GIS* 21(4):796-810, DOI
  [10.1111/tgis.12236](https://doi.org/10.1111/tgis.12236)** — the study behind mapclassify's
  sampled variants; the reason every implementation subsamples above a few thousand points, and
  therefore another reproducibility hazard (an RNG in the break computation).
- **Jiang (2013), "Head/Tail Breaks: A New Classification Scheme for Data with a Heavy-Tailed
  Distribution", *The Professional Geographer* 65(3):482-494, DOI
  [10.1080/00330124.2012.700499](https://doi.org/10.1080/00330124.2012.700499)**, preprint
  `arXiv:1209.2801v1`: "partitions all of the data values around the mean into two parts and
  continues the process iteratively for the values (above the mean) in the head until the head
  part values are no longer heavy-tailed distributed. Thus, the number of classes and the class
  intervals are both naturally determined." Scope is explicitly heavy-tailed/scaling data
  (city sizes, street networks) — a real but narrow academic niche, and the class count is not
  user-controllable, which fits badly with ColorScales' `count`-parameterised API.
- **Talbot, Lin & Hanrahan (2010), "An Extension of Wilkinson's Algorithm for Positioning Tick
  Labels on Axes", *IEEE TVCG* 16(6):1036-1043, DOI
  [10.1109/TVCG.2010.130](https://doi.org/10.1109/TVCG.2010.130)** — the algorithm behind
  `scales::breaks_extended` and `PlotUtils.optimize_ticks`; relevant only as confirmation that
  ColorScales' `Pretty` covers the niche that ggplot2 defaults to.

---

## 4. Testing the brief's framing against the evidence

| Claim in the brief | Verdict | Evidence |
|---|---|---|
| "Scientific figures are often continuous fields where the range matters more than discrete classes." | **Supported, strongly.** | matplotlib, xarray, seaborn, astropy and GMT invest in norms/intervals and ship *no* choropleth classifier; astropy's visualization module is a range hierarchy with no classing at all. |
| "Reproducibility argues for manual/fixed edges and fixed ranges over data-derived ones." | **Supported.** | ArcGIS: natural breaks "not useful for comparing multiple maps built from different underlying information"; mapclassify ships `Pooled` purely for shared global bins; xarray's `FacetGrid` computes one `cmap_params` for all panels; Wang & Song on repeatability of heuristic clustering. |
| "Diverging data is extremely common in the sciences and is currently unserved." | **Supported, strongly.** | Six independent implementations of centring (§1), xarray applying it *by default*, astropy adding it in 2025, Julia users hand-rolling it, IPCC style guide requiring the central value to be pinned. |
| "`ManualBreaks` is trivially cheap and possibly the highest practical value." | **Half right.** Cheap: yes (~15 lines, §7.2). Highest value: no — `FixedRange + EqualInterval` already gives uniform fixed edges, and `ClassBreaks` + `classgradient` + `ColorSpec` can already be assembled by hand. It adds *non-uniform* fixed edges and one-call ergonomics, which is worth doing first among break methods but is not the biggest gap. | `src/rangebreaks.jl`, `src/classes.jl:20-40`, `src/spec.jl:36-70`. |
| "Academic use is not the same as choropleth cartography." | **Supported.** | Standard-deviation and natural breaks are in all four GIS tools and in none of the five scientific stacks; conversely `robust`/percentile clipping and centring are in the scientific stacks and largely absent from the GIS classifiers (QGIS's raster side excepted). |

One further asymmetry worth recording: every GIS tool classifies **before** thinking about the
range, while every scientific tool sets the **range** first and treats classing as optional
banding. ColorScales' existing split (range method ⟂ break method, `CONTEXT.md`) matches the
scientific model, which is the right side to be on — and it makes a centred range compose with
every existing break method for free (§7.1).

---

## 5. Break methods, weighed

### 5.1 `ManualBreaks(edges)` — recommended first

Universality (§2.3 row 4) is the whole argument: it is the only classing input accepted by every
tool surveyed, GIS and scientific. It is also what the reproducibility requirement actually
needs — a figure whose panels/years/scenarios share hard-coded edges taken from a paper's
caption, e.g. IPCC-style anomaly bands `[-4, -2, -1, -0.5, 0.5, 1, 2, 4]`, which no generative
method will reproduce. ArcGIS's own advice is to start from a computed classification and then
"switch to manual interval … to make refinements".

Cost: none of substance. `datarequirement(::ManualBreaks) = REQUIRE_NONE`, `breakedges` returns
the stored vector, `ClassBreaks` already validates finiteness/strict monotonicity
(`src/classes.jl:25-33`), and both plotting extensions dispatch on the abstract
`ColorScales.BreakMethod` (`ext/ColorScalesMakieExt.jl:75-80`,
`ext/ColorScalesPlotsExt.jl:89`), so `heatmap(z, ManualBreaks(edges))` works the day the struct
exists.

One genuine design decision, flagged for the implementer: `classgradient` requires the edges to
span the colour range **exactly** (`src/spec.jl:60-66`). `Pretty` already resolves this by
letting its edges *become* the range (`src/spec.jl:106-110`). `ManualBreaks` should do the same —
edges are authoritative, the spec's range becomes `(first, last)`, and an explicitly supplied
`colorrange` that disagrees should either be ignored-with-documentation or rejected. Ignoring is
inconsistent with "your own keywords stay in charge" (README); rejecting is safer and matches the
`classgradient` error already in place. Recommend: reject a conflicting explicit `colorrange`,
accept and override the default `Extrema()`.

### 5.2 Natural breaks / Fisher–Jenks — defer, and if ever done, do it exactly

- The distinction is real and matters: **Fisher (1958)** is an exact O(k·n²) DP; **Jenks'**
  published-code lineage is an iterative heuristic; mapclassify's `NaturalBreaks` is k-means with
  10 random restarts; classInt says "fisher … should always be preferred to 'jenks'". Exact 1-D
  k-means (Wang & Song) *is* the same optimisation problem — "Jenks natural breaks is k-means in
  one dimension" (mapclassify `classifiers.py:553`).
- Against implementing it in core, for this package's audience: ArcGIS's warning that it cannot
  be compared across maps; every implementation subsampling above ~3000 points (classInt
  `largeN`/`samp_prop`, QGIS `mMaximumSize`, mapclassify's `*Sampled` classes, Rey et al. 2016),
  which injects an RNG into a figure's appearance; and its total absence from every scientific
  plotting stack surveyed.
- If demand appears, the correct shape is: exact DP over **unique values with counts** (which
  collapses rasters with few distinct values dramatically), no sampling, no RNG, a documented
  `maxunique` ceiling that errors rather than silently subsampling, and O(k·n) memory by keeping
  only the backtrack row. Complexity budget in prior note §5.4 still stands. This is a ~150-line
  addition with real numerical care (running-sum variance, catastrophic cancellation) — an order
  of magnitude more work than everything else on this list, and a candidate for a later minor
  release or a `…ClusteringExt`-style optional path rather than core v0.1.

### 5.3 Standard-deviation breaks — do not implement; already expressible

`MeanStd(3)` as the colour range plus `EqualInterval(6)` places edges at
mean − 3σ, −2σ, −1σ, mean, +1σ, +2σ, +3σ — i.e. exactly σ-multiple classes, deterministic and
without QGIS's z-scale prettification (prior note §3.2) or classInt's "may have a number of
classes different from n" (`man/classIntervals.Rd`). mapclassify's `StdMean(multiples = […])`
adds only the ability to use *uneven* multiples such as `[-3, -1.5, 1.5, 3]` — which
`ManualBreaks` covers once §5.1 lands. Adding a dedicated method would be a third way to say the
same thing.

### 5.4 Symmetric / diverging-aware break generation — do not implement; falls out of the range

QGIS models this as a flag on the classification method (`setSymmetricMode(enabled,
symmetryPoint, astride)`, prior note §3.1). In ColorScales' orthogonal design it is a property of
the *range*: `Centered(...; center = c)` + `EqualInterval(2m)` yields edges symmetric about `c`
with a break exactly on `c`; `EqualInterval(2m+1)` yields QGIS's `astride = true` case (the
centre sits inside a class instead of on a boundary). Two caveats to document rather than code
around: `Pretty` may widen the range and break the symmetry, and `Quantile` is data-driven so its
interior edges are not symmetric even when the range is.

### 5.5 Logarithmic breaks — do not implement as breaks

Every scientific tool treats log as a **scale**: matplotlib `LogNorm` (with
`nonpositive="mask"`), GMT `-Q`/`-T…+l`, xarray via a norm. Only QGIS models it as a
classification mode with a three-way non-positive policy. Meanwhile `PlotUtils.cgrad` already
accepts `scale = :log10` (or an arbitrary function) and remaps the stop positions (prior note
§2.1), and Makie has `colorscale` as a first-class attribute (prior note §2.2). The right
ColorScales feature is therefore a gradient/scale option, not a `BreakMethod`; and if it is ever
added, the non-positive policy must be explicit (QGIS's three-way parameter is the best
precedent, matplotlib's `mask` the simplest default).

### 5.6 Head/tails, box/quartile, geometric interval, maximum breaks — do not implement

- **Head/tails** (Jiang 2013): scope is explicitly heavy-tailed/scaling data; the class count is
  determined by the data, which does not fit the `count`-parameterised API; present only in the
  two GIS libraries. Legitimate but niche; revisit only on request.
- **Box/quartile** (classInt `box`, mapclassify `BoxPlot`): a fixed 6-class scheme built from
  quartiles and 1.5·IQR fences. Genuinely statistical, and the closest thing on this list to a
  "statistics" rather than "cartography" method — but `Quantile(4)` plus a robust range already
  covers the informative part, and the fence classes exist to *show outliers*, which ColorScales
  deliberately handles by saturation at the range instead (README, "Outlier saturation").
- **Geometric interval**: ArcGIS-only, and its public description is not a specification (§2.2).
  Unverifiable ⇒ unimplementable faithfully.
- **Maximum breaks**: `k-1` largest gaps; trivially cheap but extremely unstable under
  resampling, and absent from every scientific tool.

---

## 6. Colour-range methods, weighed

### 6.1 `Centered(inner; center = 0)` — recommended first

The evidence is in §1, §2.1 and §3 and is as strong as this kind of evidence gets: six
independent first-party implementations, one of them (xarray) applying it by default, one of them
(astropy) added ten months ago; a Nature Communications paper and the IPCC author guide both
saying diverging data must be shown about its central value; an oceanography guideline paper
stating the consequence in limit terms ("positive and negative data of the same absolute value
are given equal weight"); and Julia scientific packages re-implementing it by hand today.

Anomaly, difference, trend, correlation and residual fields are the bread and butter of
geoscience, remote sensing and statistics figures, and ColorScales currently cannot express any
of them: `Extrema`, `Percentile` and `MeanStd` all produce asymmetric spans (`MeanStd` is
symmetric about the *mean*, not about a chosen value), and `FixedRange` requires the user to do
the arithmetic by hand *and* recompute it per dataset, which defeats the purpose.

Composition is the design win: wrapping an inner range method means
`Centered(Percentile(2, 98))` = robust-clipped *and* centred (Sunny.jl's hand-rolled combination),
`Centered(MeanStd(3))` = σ-scaled and centred, `Centered(Extrema())` = the xarray/ggplot2/astropy
default. GMT's `grd2cpt -S h|l|m|u` shows the one other degree of freedom worth considering —
radius from `max(|zmin|,|zmax|)` (the universal choice), `min(...)`, or one side only. Recommend
implementing only `max`, which is what every other tool does, and leaving the others to
`FixedRange`.

### 6.2 `MedianMAD(n; scaled = true)` — second, but optional

`median ± n · 1.4826 · MAD` is shipped by GMT as `makecpt -Sm<scl>` (`makecpt.rst:172-173`, with
"L1 scale = 1.4826 * Median Absolute Deviation" defined at `grdinfo.rst:133-139`). It is the
robust sibling of the existing `MeanStd`, useful for heavy-tailed or spike-contaminated rasters
where the mean and σ are both dragged. Cost is small: `REQUIRE_VALUES` (already used by
`Percentile`) and two `partialsort`-based medians.

Honest caveat: **`Percentile` already covers the common case.** xarray's `robust`, seaborn's
`robust` and GMT's `-Sq` are all percentile clipping, and the prior note records
`PlotUtils.zscale` as an available astronomy-style robust range if that community ever asks.
`MedianMAD` earns its place mainly as the robust counterpart of `MeanStd` for symmetric,
approximately-Gaussian-plus-outliers data, and because `Centered(MedianMAD(3))` is a genuinely
good default for anomaly fields with spikes.

### 6.3 Redundant or not worth adding

- **Percentile variants** (astropy's `PercentileInterval(p)` "keep a fraction of pixels",
  xarray/seaborn `robust`, GMT `-Sq`): all expressible as `Percentile(low, high)` today. A
  one-argument convenience (`Percentile(96)` ⇒ 2/98) would collide confusingly with the existing
  two-argument constructor. **Redundant — say so and move on.**
- **IQR / Tukey fences as a range** (`Q1 − 1.5·IQR`, `Q3 + 1.5·IQR`): numerically just another
  robust clip, and for typical data it lands close to a 1–99 percentile clip. Redundant with
  `Percentile`; the interesting part of the boxplot idea is the *classes*, covered in §5.6.
- **Log-safe range** (positive minimum): only meaningful once a log gradient scale exists (§5.5);
  until then it has nothing to feed. Defer with the scale.
- **Two-slope / asymmetric centring** (matplotlib `TwoSlopeNorm`, seaborn's colormap truncation):
  this is *not* a range — it is a nonlinear mapping. It is nonetheless expressible in this
  architecture, because `PlotUtils.cgrad(colormap, stops)` accepts arbitrary stop positions:
  placing the neutral stop at `(center - low)/(high - low)` gives exactly seaborn's result
  without widening the limits. Worth a follow-up design note as a *gradient* feature (it wastes
  no dynamic range, which matters for asymmetric anomaly fields), but it is second to
  `Centered`, which is what the majority of tools do and what fits the existing type hierarchy.

---

## 7. Proposed API (no code written)

Consistent with the existing style in `src/ranges.jl` and `src/rangebreaks.jl`: callable structs,
validating inner constructors, `datarequirement` declarations, `ArgumentError` on bad input.

### 7.1 The range method

```julia
"""
    Centered(inner = Extrema(); center = 0)

Color range symmetric about `center`, widened to whichever side of `inner`'s range reaches
further. Use it for diverging data — anomalies, differences, trends, correlations — so the
colormap's neutral color lands on `center`.

`Centered(Percentile(2, 98))` clips outliers first and then centers the clipped span.
"""
struct Centered{M <: ColorRangeMethod} <: ColorRangeMethod
    inner::M
    center::Float64
    function Centered(inner::M = Extrema(); center::Real = 0) where {M <: ColorRangeMethod}
        c = Float64(center)
        isfinite(c) || throw(ArgumentError("center must be finite, got $center"))
        return new{M}(inner, c)
    end
end

datarequirement(m::Centered) = datarequirement(m.inner)

function rangefrom(obs, m::Centered)
    low, high = rangefrom(obs, m.inner)
    radius = max(high - m.center, m.center - low)   # ≥ (high - low)/2 ≥ 0
    return (m.center - radius, m.center + radius)
end
```

Notes for the implementer:

- **Name.** `Symmetric` is exported by `LinearAlgebra` (verified: `:Symmetric in
  names(LinearAlgebra)` is `true`, and `Base` does not define it), so `using ColorScales,
  LinearAlgebra` would collide — a real risk in scientific scripts. `Centered` collides with
  nothing in Makie (which exports only `center!`), Plots, PlotUtils, Statistics or StatsBase.
  matplotlib's precedent is `CenteredNorm`; astropy's is `SymmetricInterval`.
- `radius` is non-negative by construction even when `center` lies outside the inner range, so
  the result always contains the inner range. Constant data equal to `center` still produces a
  zero-width `(c, c)`, which `displayrange` already handles (`src/spec.jl:117-127`).
- Wrapping rather than parameterising (`Centered(Percentile(2, 98))`, not
  `Percentile(2, 98; center = 0)`) keeps every existing method reusable and adds no field to any
  of them; it also matches how `Centered` composes with break methods for free (§5.4).
- Documentation should state the deliberate cost: centring widens one side, so up to half the
  colormap may be unused on strongly one-sided data. That is the accepted trade-off in xarray,
  ggplot2 and astropy; seaborn's colormap-truncation alternative (§6.3) is the escape hatch to
  document as future work.

### 7.2 The break method

```julia
"""
    ManualBreaks(edges)

Class edges supplied by the caller. The data is never inspected, and like `Pretty` the edges
are authoritative: the resulting color range is `(first(edges), last(edges))`.
"""
struct ManualBreaks <: BreakMethod
    edges::Vector{Float64}
    function ManualBreaks(edges)
        e = collect(Float64, edges)
        isempty(e) && throw(ArgumentError("ManualBreaks needs at least one edge"))
        all(isfinite, e) || throw(ArgumentError("class edges must be finite, got $e"))
        issorted(e) && allunique(e) ||
            throw(ArgumentError("class edges must be sorted and unique, got $e"))
        return new(e)
    end
end

datarequirement(::ManualBreaks) = REQUIRE_NONE
breakedges(::Any, m::ManualBreaks, ::Tuple{Float64, Float64}) = copy(m.edges)
```

Notes: validation duplicates `ClassBreaks`' invariants (`src/classes.jl:25-33`) deliberately, so
the error names the constructor the user called. `breakedges` ignoring the incoming colour range
is the `Pretty` precedent (`src/spec.jl:106-110`); see §5.1 for the recommendation to *reject* an
explicitly supplied, conflicting `colorrange` rather than silently discard it. Both plotting
extensions need no change (`ext/ColorScalesMakieExt.jl:75-91`,
`ext/ColorScalesPlotsExt.jl:89-100`).

### 7.3 The later ones, for the record

```julia
struct MedianMAD <: ColorRangeMethod   # GMT makecpt -Sm
    n::Float64
    scaled::Bool                       # 1.4826 consistency factor ("L1 scale")
end
MedianMAD(n::Real = 2; scaled::Bool = true)
datarequirement(::MedianMAD) = REQUIRE_VALUES

struct NaturalBreaks <: BreakMethod    # exact Fisher (1958) DP, unique values with weights
    count::Int
    maxunique::Int                     # error, never silently subsample
end
datarequirement(::NaturalBreaks) = REQUIRE_VALUES
```

---

## 8. Licensing

| Source | License | Usable how |
|---|---|---|
| QGIS | GPLv2+ (prior note §7) | **Design only.** No code. |
| R `classInt` 0.4-11 | `GPL (>= 2)` (`DESCRIPTION`) | **Read for behaviour, never copy.** Its `"fisher"` calls the original CMLIB Fortran `fish.f`; `"jenks"` is "ported from Jenks' code". |
| `Ckmeans.1d.dp` | `LGPL (>= 3)` (CRAN package index) | **Do not copy.** The *paper* (DOI 10.32614/RJ-2011-015) is freely reimplementable. |
| PySAL `mapclassify` | BSD-3-Clause (`LICENSE.txt`) | MIT-compatible in direction, but BSD-3 carries attribution and a no-endorsement clause; copying still creates an obligation. Treat as reference, reimplement. |
| matplotlib | PSF-style/BSD-compatible | Reference for semantics; formulas here are one-liners not worth copying anyway. |
| xarray, seaborn, astropy, geopandas | Apache-2.0 / BSD-3 | Same: reference, don't copy. Apache-2.0's patent grant/NOTICE terms are an unnecessary complication for an MIT package. |
| ggplot2 / scales | MIT | Genuinely compatible, and the relevant logic is a single line (`extent <- 2 * max(abs(from - mid))`). Even so, a formula this small is better restated than copied. |
| GMT | LGPL-3+ (docs consulted only) | Documentation-level reference only. |
| Julia deps (`PlotUtils`, `Colors`, `ColorSchemes`, `Clustering`, `Discretizers`) | MIT | Fine. Verified for `Clustering.jl` (`LICENSE.md`: "licensed under the MIT License"). |

**The methods recommended here are all licence-clean by construction.** `Centered` and
`ManualBreaks` are not algorithms in any meaningful sense — there is nothing to infringe.
`MedianMAD` is textbook robust statistics. Only `NaturalBreaks` touches copyleft-adjacent
territory, and the escape is well-trodden: implement from **Fisher (1958)** (a published paper,
not code) and from the **Wang & Song (2011)** recurrence, with a written provenance note, as the
prior note §7 already recommends. Do **not** transliterate `fish.f`, QGIS's
`qgsclassificationjenks.cpp`, or mapclassify's `_fisher_jenks_means` (itself of murky provenance:
its docstring credits a 2010 blog post "based on a JAVA and Fortran code",
`classifiers.py:587-601`).

**One dependency caution carried forward:** `Breakers.jl` (@ `d7623a0`) is MIT and advertises
classInt compatibility, but (a) it is still the single registered version 0.1.0
(`General:B/Breakers/Versions.toml`), (b) it still ships `CSV`, `DataFrames`, `Documenter`,
`BenchmarkTools` and `Test` in `[deps]` (`Project.toml:7-19`), making it unusable as a light
dependency, and (c) its Fisher implementation uses the `work`/`iwork` matrix naming of the GPL
Fortran `fish.f` (`src/fisher_clustering.jl:13-49`) with no stated provenance. Not a claim of
infringement — a reason not to depend on it.

**No registered Julia package supplies what would be needed anyway.** A scan of
`JuliaRegistries/General`'s `Registry.toml` finds no `Ckmeans`, no `Jenks`, no 1-D exact k-means
package; `Clustering.jl` (MIT) offers only Lloyd-style `kmeans`, which is the non-repeatable
variant Wang & Song warn about.

---

## 9. Cost/benefit summary

| Candidate | Lines¹ | Time | Space | Numerical pitfalls | New deps | Extension changes |
|---|---|---|---|---|---|---|
| `Centered` | ~20 | O(1) over inner | O(1) | none (`radius ≥ 0` by construction); zero-width case already handled | none | **none** (dispatch is on `ColorRangeMethod`) |
| `ManualBreaks` | ~15 | O(k) | O(k) | edge/range span rule (§5.1) | none | **none** (dispatch is on `BreakMethod`) |
| `MedianMAD` | ~25 | O(n) expected (two `partialsort`s) | O(n) | even-length median convention; MAD = 0 for >50 % ties ⇒ zero-width range | none | none |
| Std-dev breaks | — | — | — | — | — | *unnecessary*: `MeanStd` + `EqualInterval` |
| Symmetric-mode breaks | — | — | — | — | — | *unnecessary*: `Centered` + `EqualInterval` |
| Log breaks | ~40 | O(1) | O(1) | non-positive policy; belongs to the gradient scale instead | none | gradient plumbing |
| Box/quartile breaks | ~30 | O(n) | O(n) | fixed 6 classes conflicts with `count` API | none | none |
| Head/tails | ~30 | O(n log n) | O(n) | class count not user-controlled; iteration cap | none | none |
| `NaturalBreaks` (exact Fisher) | ~150 + tests | O(k·u²), `u` = unique values | O(k·u) (backtrack row only) | cancellation in running variance; must compress to unique values with weights; no RNG, no sampling | none (reimplement) | none |

¹ Rough, excluding docstrings/tests/docs pages. Note the docs convention: the site has one page
per range method and one per break method (README, "Documentation"), so each addition also costs
a page and a rendered figure.

The two recommendations together are ~35 lines of source plus docs and tests, touch no
extension, add no dependency, and remove no invariant.

---

## 10. What I could not verify

- **Fisher (1958) and Jenks & Caspall (1971) full texts** — both paywalled; cited from Crossref
  metadata and from the implementations/docstrings that reference them (classInt Rd, mapclassify,
  QGIS). The exact-DP-versus-heuristic distinction here rests on classInt's and mapclassify's own
  descriptions plus Wang & Song, not on reading Fisher's 1958 derivation.
- **Crameri, Shephard & Heron (2020) supplementary notes** — the main text was read in full
  (nature.com HTML); Supplementary Notes 1-3 and the Fig. 6 decision guide were not fetched. The
  main text supports "diverging data ⇒ diverging map centred on the critical value" but does not
  state the symmetric-limit arithmetic; that claim rests on Thyng et al. (2016) and on the six
  implementations.
- **Moreland (2009)** — read from the author's own expanded PDF, not the published LNCS version;
  content should match but pagination differs from the DOI record.
- **matplotlib `DivergingNorm`'s introducing release note** — no mention in
  `whats_new_3.1.0.rst`. The 3.1.0 origin was established by source presence
  (`v3.1.0:lib/matplotlib/colors.py:962`) versus absence in `v3.0.3`, and the 3.2.0 rename by the
  deprecation note.
- **GMT `-Sm`'s exact scale factor in code** — the `1.4826 · MAD` definition was verified in
  `grdinfo.rst` (the tool that reports "L1 scale"), not in `makecpt`'s C source.
- **ncview and Panoply** — not examined (Panoply is closed-source; neither was reachable as a
  primary specification in the time available). Their absence does not affect the ranking.
- **cartopy** — not separately examined: it delegates colour handling to matplotlib
  (`pcolormesh`/`contourf` kwargs), so the matplotlib findings carry over; no cartopy-specific
  range or classing API was found in the docs index.
- **PyGMT's exposure of `-S`** — `pygmt/src/grd2cpt.py` aliases `A,D,F,E,H,I,L,T,W,Ww` plus
  `C,G,M,N,Q,R,V,Z`; **`-S` is not aliased**, so PyGMT users cannot reach GMT's symmetric mode
  directly. I did not check whether it is reachable via `**kwargs` passthrough.
- **`Breakers.jl`'s Fisher provenance** — the naming similarity to `fish.f` is an observation from
  reading `src/fisher_clustering.jl`; I could not determine whether it is a clean-room
  implementation, and make no claim either way.
- **ArcGIS Pro's geometric-interval algorithm** — public documentation is prose, not a
  specification; no source is available. This is why §5.6 rules it out.
- **Zotero** — the local library returned zero results for every query and Semantic Scholar was
  rate-limited, so all bibliographic data here comes from the Crossref REST API and from
  publisher/arXiv pages directly.

---

## 11. Source index

**New primary sources (this note).** Repository files were read at the pinned revisions below on
2026-09-20.

- **xarray** @ `8de862c` — `xarray/plot/utils.py:54,161-307,909-934`;
  `xarray/plot/dataarray_plot.py:788-830,1342-1365`; `xarray/plot/facetgrid.py:383-395,499-522`;
  `xarray/core/options.py:17-18,85-86`.
- **matplotlib** — `v3.10.1:lib/matplotlib/colors.py:2119,2350-2400,2445-2530,2766-2769,2930-2975`;
  `v3.10.1:doc/users/prev_whats_new/whats_new_3.4.0.rst:553-587`;
  `v3.10.1:doc/api/prev_api_changes/api_changes_3.2.0/deprecations.rst:268-277`;
  `v3.1.0:lib/matplotlib/colors.py:962`; `v3.0.3:lib/matplotlib/colors.py` (no `DivergingNorm`).
- **seaborn** @ `f04b6cd` — `seaborn/matrix.py:192-247`.
- **ggplot2** @ `4e88664` — `R/scale-gradient.R:113-142`; `R/scale-steps.R:62-116`;
  `R/scale-brewer.R:153-189`; `R/scale-.R:1492+` (`ScaleBinned$get_breaks`).
- **scales** @ `35b2a77` — `R/bounds.R:87-121` (`rescale_mid`); `R/breaks.R:85-160`
  (`breaks_extended`, `breaks_pretty`); `R/breaks-log.R:52-124`; `R/transform.R:31-41`;
  `R/transform-numeric.R:275-283`.
- **astropy** @ `5d68e4f` — `astropy/visualization/interval.py:16-24,130-170,172-235,237-265,267-310`;
  `CHANGES.rst` §"Version 7.2.0 (2025-11-25)", astropy.visualization, PR #18602.
- **GMT** @ `e09bb42` — `doc/rst/source/makecpt.rst:10-30,100-110,157-188`;
  `doc/rst/source/grd2cpt.rst:10-60,188-204`; `doc/rst/source/grdinfo.rst:39-47,132-143`.
- **R `classInt` 0.4-11** @ `7607776` — `DESCRIPTION` (License: `GPL (>= 2)`);
  `man/classIntervals.Rd` (usage, `\item{style}`, `\item{largeN}`, `\item{samp_prop}`, Details,
  References); `R/classInt.R:100-205,254-266,336-405`.
- **PySAL `mapclassify`** @ `f906871` — `LICENSE.txt` (BSD-3-Clause);
  `mapclassify/classifiers.py:17-58,551-601,1459-1470,1579-1606,1770-1830`;
  `mapclassify/_classify_API.py:43-88`; `mapclassify/pooling.py:1-80`;
  `docs/_static/references.bib`; `README.md`.
- **geopandas** @ `c0e3867` — `doc/source/docs/user_guide/mapping.rst:123-163`.
- **ArcGIS Pro** — "Data classification methods",
  <https://pro.arcgis.com/en/pro-app/latest/help/mapping/layer-properties/data-classification-methods.htm>
  (fetched 2026-09-20).
- **Sunny.jl** @ `2a5c6d5` — `ext/PlottingExt/PlotIntensities.jl:311-335`.
- **Breakers.jl** @ `d7623a0` — `Project.toml:1-40`; `src/fisher_clustering.jl:13-49`;
  `src/Breakers.jl:14-47`; registry entry `General:B/Breakers/Versions.toml` (0.1.0 only).
- **Clustering.jl** — `LICENSE.md:1-6` (MIT); `src/Clustering.jl:31-32,82`.
- **JuliaRegistries/General** — `Registry.toml` (no `Ckmeans`, `Jenks`, or 1-D exact k-means
  package registered as of 2026-09-20).
- **Julia** — `:Symmetric in names(LinearAlgebra) == true`, `isdefined(Base, :Symmetric) == false`
  (verified locally).
- **CRAN** — `Ckmeans.1d.dp` package index page, License: `LGPL (>= 3)`.
- **ColorScales itself** — `src/ranges.jl`, `src/rangebreaks.jl`, `src/databreaks.jl`,
  `src/classes.jl`, `src/spec.jl:36-127`, `src/input.jl:25-27,120-190`,
  `ext/ColorScalesMakieExt.jl:64-95`, `ext/ColorScalesPlotsExt.jl:85-105`, `README.md`,
  `CONTEXT.md`.

**Literature (DOIs resolved via Crossref, 2026-09-20).**

- Crameri, Shephard & Heron 2020, *Nat. Commun.* 11:5444 — [10.1038/s41467-020-19160-7](https://doi.org/10.1038/s41467-020-19160-7)
- Thyng, Greene, Hetland, Zimmerle & DiMarco 2016, *Oceanography* 29(3):9-13 — [10.5670/oceanog.2016.66](https://doi.org/10.5670/oceanog.2016.66)
- Moreland 2009, ISVC, *LNCS* 5876:92-103 — [10.1007/978-3-642-10520-3_9](https://doi.org/10.1007/978-3-642-10520-3_9)
- Stauffer, Mayr, Dabernig & Zeileis 2015, *BAMS* 96(2):203-216 — [10.1175/BAMS-D-13-00155.1](https://doi.org/10.1175/BAMS-D-13-00155.1)
- Zeileis, Hornik & Murrell 2009, *CSDA* 53(9):3259-3270 — [10.1016/j.csda.2008.11.033](https://doi.org/10.1016/j.csda.2008.11.033)
- Zeileis, Fisher, Hornik, Ihaka et al. 2020, *JSS* 96(1) — [10.18637/jss.v096.i01](https://doi.org/10.18637/jss.v096.i01)
- Fisher 1958, *JASA* 53(284):789-798 — [10.1080/01621459.1958.10501479](https://doi.org/10.1080/01621459.1958.10501479)
- Jenks & Caspall 1971, *Annals AAG* 61(2):217-244 — [10.1111/j.1467-8306.1971.tb00779.x](https://doi.org/10.1111/j.1467-8306.1971.tb00779.x)
- Wang & Song 2011, *The R Journal* 3(2):29-33 — [10.32614/RJ-2011-015](https://doi.org/10.32614/RJ-2011-015)
- Rey, Stephens & Laura 2016, *Transactions in GIS* 21(4):796-810 — [10.1111/tgis.12236](https://doi.org/10.1111/tgis.12236)
- Jiang 2013, *The Professional Geographer* 65(3):482-494 — [10.1080/00330124.2012.700499](https://doi.org/10.1080/00330124.2012.700499); preprint [arXiv:1209.2801v1](https://arxiv.org/abs/1209.2801v1)
- Talbot, Lin & Hanrahan 2010, *IEEE TVCG* 16(6):1036-1043 — [10.1109/TVCG.2010.130](https://doi.org/10.1109/TVCG.2010.130)
- IPCC WGI TSU (Gomis & Pidcock) 2018, *IPCC Visual Style Guide for Authors*, December 2018, p. 7 — <https://www.ipcc.ch/site/assets/uploads/2019/04/IPCC-visual-style-guide.pdf>

**Carried over:** [`2026-08-27-color-utilities-ecosystem.md`](2026-08-27-color-utilities-ecosystem.md)
— QGIS @ `2e3de3b` (classification methods, symmetric mode, pretty breaks, Jenks sampling,
logarithmic non-positive policy), Makie/Plots/PlotUtils integration points, Julia prior art.

---

## 12. Ranked recommendation

**Do first — one of each, in this order:**

1. **Range: `Centered(inner = Extrema(); center = 0)`.** Diverging data is the commonest
   scientific field type ColorScales cannot currently serve, and six first-party tools implement
   the identical `radius = max(high − center, center − low)` rule — xarray *by default*
   (`plot/utils.py:250-267`), matplotlib `CenteredNorm` (added 3.4.0 for "positive and negative
   anomalies around a center zero"), ggplot2 via `scales::rescale_mid` (`midpoint = 0`), astropy
   `SymmetricInterval` (7.2.0, 2025-11-25), GMT `grd2cpt -S`, seaborn by colormap truncation.
   *Name it `Centered`, not `Symmetric`: `LinearAlgebra` exports `Symmetric` (verified).*
2. **Break: `ManualBreaks(edges)`.** The only classing input accepted by every tool surveyed
   (ArcGIS "manual interval", classInt `fixed`, mapclassify `UserDefined`, matplotlib
   `BoundaryNorm`, xarray `levels=[…]`, ggplot2 `breaks=`, GMT `-T <list|file>`), and the one
   that makes a figure's edges reproducible across panels — the need mapclassify built `Pooled`
   for and that ArcGIS warns natural breaks cannot meet.

**Then, in order:**

3. **`MedianMAD(n; scaled = true)`** — the robust sibling of the existing `MeanStd`, shipped by
   GMT as `makecpt -Sm<scl>` with "L1 scale = 1.4826 · MAD" (`grdinfo.rst:133-139`); most valuable
   composed as `Centered(MedianMAD(3))` for spiky anomaly fields. Optional: `Percentile` already
   covers the ordinary robust-clipping case that xarray and seaborn call `robust`.
4. **A log *scale* for the gradient (not log breaks)** — every scientific tool models log as a
   scale (matplotlib `LogNorm` with `nonpositive="mask"`; GMT `-Q`/`-T…+l`), and
   `PlotUtils.cgrad(...; scale = :log10)` already supports it; requires an explicit non-positive
   policy, for which QGIS's three-way parameter is the best precedent.
5. **A centred *gradient* (seaborn/`TwoSlopeNorm` style)** — place the neutral stop at
   `(center − low)/(high − low)` instead of widening the limits (`seaborn/matrix.py:238-241`);
   wastes no dynamic range, but touches the gradient rather than the range, so it is a separate
   design note.
6. **`NaturalBreaks` (exact Fisher 1958 DP, unique-value compressed, no sampling, no RNG)** —
   only if GIS-parity demand actually appears; it is the one item here with real algorithmic cost
   (O(k·u²)) and the only one with a licensing trap.

**Deliberately do not implement:**

- **Standard-deviation breaks** — already expressible: `MeanStd(3)` + `EqualInterval(6)` gives
  exact σ-multiple edges, without QGIS's z-scale prettification or classInt's variable class
  count (`man/classIntervals.Rd`, "may have a number of classes different from n").
- **Symmetric-mode break generation** — falls out of `Centered` + `EqualInterval` (even count =
  break on the centre, odd count = QGIS's `astride`); no flag needed on any break method.
- **Jenks heuristic / k-means natural breaks** — non-repeatable ("neither always optimal nor
  repeatable", Wang & Song 2011) and, per ArcGIS's own documentation, "not useful for comparing
  multiple maps built from different underlying information".
- **Head/tails (Jiang 2013)** — scope is explicitly heavy-tailed geographic data and the class
  count is data-determined, which does not fit a `count`-parameterised API.
- **Geometric interval** — ArcGIS-only, and its public description ("the geometric coefficient
  can change once to its inverse") is prose, not a reimplementable specification.
- **Box/quartile breaks, maximum breaks** — a fixed 6-class scheme and a largest-gap rule
  respectively; both absent from every scientific stack, and the outlier emphasis they exist for
  is already handled by range clipping plus saturation.
- **IQR/Tukey-fence and extra percentile ranges** — redundant with the existing
  `Percentile(low, high)`, which is bit-for-bit what xarray's and seaborn's `robust` and GMT's
  `-Sq` compute.
