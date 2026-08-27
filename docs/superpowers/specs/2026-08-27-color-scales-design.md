# ColorScales.jl Design

**Date:** 2026-08-27
**Status:** Approved design; implementation planning pending

## Purpose

ColorScales.jl will turn univariate numeric data into scientifically useful,
renderer-neutral color specifications. It will make robust color ranges,
interpretable graduated classes, and readable class breaks easy to use from
both Makie and Plots.

The package will not define plot types. It will compute numerical results and
translate them into plotting attributes.

## Goals

1. Separate color-range selection from class-break selection.
2. Cover the useful, feasible parts of QGIS graduated symbology.
3. Provide robust scientific alternatives to extrema without changing a
   plotting library's defaults.
4. Use one PlotUtils gradient representation for Makie and Plots.
5. Keep plotting integrations thin, optional, and free of statistical logic.
6. Accept finite, general iterable numeric data, collecting observations only
   for methods that need order statistics.
7. Prefer ordinary Julia functions, callable objects, and keyword splatting
   over macros or a plotting DSL.

## Non-goals

The first release will not provide categorical or unique-value symbology,
bivariate maps, rule-based rendering, symbol-size graduation, interactive
histogram editing, distribution fitting, transformed-axis ownership, new plot
recipes, or plotting macros.

Unitful values and clustering-based classifiers beyond Fisher-Jenks are
deferred until the core numerical interface is stable.

## Ecosystem findings

The detailed, sourced ecosystem review is in
[`docs/research/2026-08-27-color-utilities-ecosystem.md`](../../research/2026-08-27-color-utilities-ecosystem.md).

The design rests on four findings:

1. QGIS separates raster minimum/maximum selection from graduated
   classification. ColorScales will preserve that separation.
2. QGIS supplies equal-interval, quantile, natural-break, standard-deviation,
   pretty, logarithmic, and fixed-interval methods. These are feasible to
   reimplement from permissive sources or published algorithm descriptions.
3. PlotUtils owns `cgrad` and its continuous and categorical gradient types.
   Makie 0.24.13 and Plots 1.41.4 both depend directly on PlotUtils and consume
   these gradients.
4. Makie and Plots do not share attribute names or colorbar interfaces.
   Sharing the gradient does not remove the need for thin plotting adapters.

No registered Julia package currently combines QGIS-style robust color ranges,
pretty and standard-deviation breaks, natural breaks, and Makie/Plots
attribute emitters. Discretizers.jl, StatsDiscretizations.jl, Breakers.jl, and
Colorfy.jl provide useful prior art but do not fill this interface.

## Architecture

### Core module

The core is a deep module with one data-to-color-specification interface. It
depends directly on:

- `Statistics` for means, standard deviations, medians, and quantiles;
- `Random` for explicit natural-break sampling; and
- `PlotUtils` for shared continuous and categorical gradients.

The core does not import Makie, Plots, Distributions, or CategoricalArrays.
Julia 1.10 is the minimum supported version, matching current Makie and Plots
releases.

### Extension seam

Package extensions add adapters without changing core results:

| Extension | Weak dependency | Responsibility |
|---|---|---|
| `ColorScalesMakieExt` | Makie | Makie plot and Colorbar attribute bundles |
| `ColorScalesPlotsExt` | Plots | Plots plot and colorbar attribute bundles |
| `ColorScalesDistributionsExt` | Distributions | Ranges and breaks from a supplied distribution |
| `ColorScalesCategoricalArraysExt` | CategoricalArrays | Assign observations to graduated classes |

Each plotting adapter translates an existing `ColorSpec`. It cannot inspect
the original data or recompute statistics.

## Domain model

The canonical terms are defined in the repository's
[`CONTEXT.md`](../../../CONTEXT.md).

### Color range

A color range is the closed numeric span `(low, high)` mapped to a palette. A
range method computes it independently of any classification method.

The public range methods are callable subtypes of `Function`:

- `Extrema()`
- `Percentile(low, high)`
- `MeanStd(n; corrected=true)`
- `FixedRange(low, high)`
- `Symmetric(method; center=0)`

Calling a method directly is shorthand:

```julia
Percentile(2, 98)(z)
```

`Percentile` arguments use the inclusive `0` to `100` scale. `MeanStd`
returns the mathematical `mean +/- n * std` interval; it does not clamp that
interval to the observed extrema.

`MeanStd` follows Julia's corrected sample standard deviation by default.
`corrected=false` reproduces QGIS's population-standard-deviation convention.

### Class breaks

`ClassBreaks` stores ordered class edges, labels, and right-closed interval
semantics. Except for constant data, `k` classes have `k + 1` edges. The first
class includes the lower endpoint; subsequent classes have the form `(a, b]`.
This matches QGIS graduated ranges and PlotUtils categorical gradients.

The first release provides:

- `EqualInterval(k)`
- `Quantile(k)`
- `Pretty(k=7)`
- `StdDev(k=7; corrected=true)`
- `FixedInterval(width)`
- `NaturalBreaks(k)`
- `Geometric(k)`

`Geometric` requires `0 < low < high` and returns logarithmically spaced edges
in original data units. It neither discards nonpositive values nor sets a
plotting library's continuous color transform.

Class counts can be integers or automatic count strategies. The first release
provides `Sturges()` and `FreedmanDiaconis()`. `Pretty` and `StdDev` treat the
count as a target and may return a nearby count. Tied observations can reduce
the actual count for any data-dependent method.

### Color specification

`ColorSpec` contains:

- a numeric color range;
- optional `ClassBreaks`;
- a PlotUtils gradient.

It never retains source observations. A continuous specification has no class
edges. A graduated specification uses a categorical PlotUtils gradient with
class edges normalized to the selected color range. Graduated labels belong to
the contained `ClassBreaks`.

## Public interface

The explicit interface exposes three verbs:

```julia
range = colorrange(z, Percentile(2, 98))
classes = breaks(z, Quantile(7); colorrange=range)
gradient = classgradient(:batlow, classes; colorrange=range)
```

The normal shortcut composes the same operations:

```julia
spec = colorspec(
    z,
    Quantile(7);
    colorrange=Percentile(2, 98),
    colormap=:batlow,
)
```

Continuous specifications omit the break method:

```julia
spec = colorspec(
    z;
    colorrange=MeanStd(2),
    colormap=:viridis,
)
```

Plotting adapters return nested NamedTuples so plot and colorbar attributes
cannot be mixed accidentally:

```julia
m = makie(spec)
plot = Makie.heatmap(z; m.plot...)
Makie.Colorbar(fig[1, 2], plot; m.colorbar...)

p = plots(spec)
Plots.heatmap(z; p.plot...)
```

For Makie, `plot` contains `colorrange` and `colormap`, while `colorbar`
contains edge ticks and labels. For Plots, `plot` contains `clims`, `color`,
and `colorbar_ticks`. Users override generated values with `merge`.

Because range methods subtype `Function`, Plots can also evaluate them through
its function-valued `clims` interface:

```julia
Plots.heatmap(z; clims=Percentile(2, 98))
```

No macro, recipe, or package-owned plotting method belongs in the first
release.

## Data flow

1. `colorspec` determines which statistics its range, break, and automatic
   count methods require.
2. Methods that need only a count, extrema, or moments consume the input once
   without collecting it. Methods that need order statistics collect usable
   observations once. This also supports non-restartable finite iterators.
3. Data-independent methods, such as a fixed color range followed by equal
   intervals, do not inspect the supplied iterable.
4. The range method computes the color range. The break method then receives
   the statistics or observations it needs from values inside that inclusive
   range and returns ordered edges and labels. Values outside the range do not
   influence class placement.
5. `classgradient` normalizes edges to `[0, 1]` and creates a PlotUtils
   categorical gradient. Continuous specifications use a continuous gradient.
6. `ColorSpec` stores only the completed numerical and color results.
7. A plotting adapter renames those results for its target plotting library.

This flow computes statistics once. Adapters cannot cause backend-dependent
classification.

## Input and interval semantics

Methods accept any finite iterable containing real values and optional
`missing` values. By default they skip `missing`, `NaN`, and infinite values.
Methods that require observations raise an error if no usable values remain.
Data-independent methods may accept a supplied iterable with no usable
observations. Infinite iterators are unsupported.

Range and break operations accept `invalid=:skip` or `invalid=:error`, so
callers can reject rather than skip invalid observations.

Edges are ordered and duplicate data-dependent edges are removed. A graduated
request for constant data collapses to one constant class instead of
inventing numeric width. Continuous constant data remains valid.

Out-of-range values saturate at the palette endpoints in the portable
interface. Makie users may override `lowclip` and `highclip` to make values
transparent. Plots has no equivalent generic attribute, so ColorScales will
not claim portable transparent clipping.

## Algorithms

### Quantiles

Quantile ranges and breaks use `Statistics.quantile` and its default linear,
R-type-7 interpolation. This matches QGIS's quantile formula.

### Pretty breaks

Pretty breaks choose approximately `k + 1` values from
`{1, 2, 5} * 10^n`. The implementation will follow published descriptions,
not GPL QGIS or R source. The selected color range remains authoritative:
outer edges equal its endpoints, while interior edges use the chosen nice
step.

### Standard-deviation breaks

Standard-deviation breaks center classes on the mean, compute breaks in
standard-deviation units for observations inside the selected color range,
clip the outer classes to that range, and convert the edges back to original
units. The `corrected` option controls sample or population standard
deviation.

### Natural breaks

Natural breaks use an independently implemented weighted Fisher-Jenks dynamic
program. Repeated observations are compressed into unique values and weights
before optimization.

Exact optimization has a documented maximum unique-value count. Above that
limit the method raises an error unless the caller explicitly supplies a
sampling policy and random-number generator. ColorScales never samples
silently and never introduces hidden nondeterminism.

### Automatic class counts

Sturges' rule depends on observation count. Freedman-Diaconis uses the
interquartile range and observation count to derive a width, then converts
that width to a class count over the selected color range. Counts are clamped
to documented positive limits to prevent accidental creation of impractical
gradients.

## Error handling

The package raises `ArgumentError` for:

- reversed or out-of-domain percentile bounds;
- nonpositive class counts or fixed intervals;
- fixed color ranges with `low > high`;
- inputs with no finite observations when the selected methods require data;
- geometric breaks whose selected range is not strictly positive;
- unsupported interval or invalid-value policies; and
- natural-break inputs above the exact limit without an explicit sampling
  policy.

Methods do not silently replace invalid configuration, invent bounds, or
switch algorithms.

## Testing

Tests exercise the public interface.

### Core ranges

Fixtures cover extrema, quantiles, corrected and population standard
deviations, symmetry, missing values, non-finite values, invalid-value policy,
empty input, and constant data.

### Break methods

Tests check edge ordering, endpoint coverage, exact-boundary closure, tied
values, requested versus actual class count, and affine invariance where the
method permits it. Quantile fixtures verify the interpolation rule. Pretty
fixtures verify allowed step sizes and sensible coverage.

### Natural breaks

Small hand-verifiable datasets test the class objective. Seeded sampling tests
reproducibility. Repeated-value fixtures verify weighted compression.

### Color integration

PlotUtils tests verify normalized gradient stops and right-closed categorical
edge behavior.

Makie and Plots extension tests verify exact NamedTuple keys and construct a
minimal headless plot. Distributions tests compare range and break results
with the supplied distribution's theoretical quantiles. CategoricalArrays
tests verify values exactly on class edges.

## Licensing and provenance

QGIS and R's classInt package are GPL. ColorScales may use their documented
behavior as a feature reference, but it will not copy or translate their
source. Each nontrivial algorithm will cite a permissive implementation or
published description in its docstring and tests.

PlotUtils, Makie, Plots, Statistics, Distributions, and CategoricalArrays use
licenses compatible with the intended MIT package.

## Success criteria

The first release is complete when:

1. Every listed range and break method satisfies the documented edge cases.
2. `colorspec` creates continuous and graduated PlotUtils gradients.
3. One numerical result can be rendered through both Makie and Plots adapters
   without recomputing statistics.
4. A supplied Distribution can drive percentile ranges and quantile breaks.
5. Public documentation explains interval closure, skipped observations,
   approximate class counts, collection behavior, and natural-break
   complexity.
