# ColorScales

Turn univariate numeric data into renderer-neutral color specifications: a
robust color range, interpretable graduated classes, readable class labels, and
one gradient that both [Makie](https://docs.makie.org) and
[Plots](https://docs.juliaplots.org) understand.

ColorScales computes colors. It never plots: you hand a specification to your
own plotting call as its last argument.

## Installation

ColorScales is not registered. Install it from a local checkout:

```julia
julia> using Pkg

julia> Pkg.develop(path = "/path/to/ColorScales")
```

`PlotUtils` is the only hard dependency. The Makie and Plots integrations live
in package extensions, so they load automatically once you load Makie or
Plots.

## Color ranges

A color range is the closed span `(low, high)` mapped onto a colormap. Every
method is callable, so `Percentile(2, 98)(z)` and `colorrange(z, Percentile(2, 98))`
agree.

| Method | Range |
| --- | --- |
| `Extrema()` | smallest to largest usable observation |
| `Percentile(low, high)` | two percentiles on the `0`–`100` scale, type-7 interpolation |
| `MeanStd(n = 2; corrected = true)` | `mean ± n * std`, not clamped to the data |
| `FixedRange(low, high)` | the caller's span; the data is never inspected |
| `Centered(inner = Extrema(); center = 0)` | `inner`'s range mirrored about `center` |

```julia
julia> using ColorScales

julia> colorrange(0:100, Percentile(2, 98))
(2.0, 98.0)
```

`Centered` wraps any of the others. Diverging data — an anomaly, a difference,
a trend, a correlation — only lines its neutral color up with zero if the range
is symmetric about it, so centering takes whichever side reaches further and
mirrors it:

```julia
julia> colorrange([-1.8, 9.0], Centered())
(-9.0, 9.0)

julia> colorrange([-1.8, 9.0], Centered(; center = 1))
(-7.0, 9.0)
```

That widens the shorter side, which spends part of the colormap on values the
data never reaches; clipping first with `Centered(Percentile(2, 98))` is the
usual way to pay less for it.

## Graduated classes

`breaks` divides a color range into right-closed classes and labels them.

| Method | Classes |
| --- | --- |
| `EqualInterval(count)` | equal width over the color range |
| `Quantile(count)` | equal share of the in-range observations |
| `Pretty(count = 7)` | interior edges on readable multiples of `{1, 2, 5} * 10ⁿ` |
| `FixedBreaks(edges)` | the caller's edges; the data is never inspected |

```julia
julia> classes = breaks(0:100, Quantile(4); colorrange = Percentile(2, 98));

julia> classes.edges
5-element Vector{Float64}:
  2.0
 26.0
 50.0
 74.0
 98.0

julia> classes.labels
4-element Vector{String}:
 "[2, 26]"
 "(26, 50]"
 "(50, 74]"
 "(74, 98]"
```

`colorspec` does both steps in one pass over the data and adds the gradient:

```julia
julia> spec = colorspec(0:100, Quantile(4); colorrange = Percentile(2, 98), colormap = :viridis);

julia> colorrange(spec), nclasses(spec)
((2.0, 98.0), 4)
```

Leave the break method out for a continuous specification: `colorspec(z)` carries
no classes and a continuous gradient.

## Makie

A specification goes last, after the values it colors. `Colorbar` takes it on
its own, and ticks each class center with its interval.

```julia
using ColorScales, Makie, GLMakie

spec = colorspec(elevation, Quantile(5); colorrange = Percentile(2, 98))

figure = Figure()
axis = Axis(figure[1, 1])
heatmap!(axis, elevation, spec)
Colorbar(figure[1, 2], spec; label = "metre")
```

The same rule colors points: `xs` and `ys` position them, `values` is what gets
colored, and the specification goes last. Makie's own classification of the
plot type decides whether the colored argument stays positional or becomes the
`color` attribute, so nothing about the call changes.

```julia
scatter!(axis, xs, ys, values, spec; markersize = 16)
```

A runnable version is [`examples/makie.jl`](examples/makie.jl), whose
`makie_example()` is executed by the test suite.

## Plots

The same rule, with no separate colorbar call: the class ticks ride along on
the series. Plots' default GR backend draws its own numeric colorbar ticks and
ignores custom labels; the `pythonplot` and `pgfplotsx` backends render the
class intervals.

```julia
using ColorScales, Plots

spec = colorspec(elevation, Pretty(5); colorrange = Percentile(2, 98))
heatmap(elevation, spec; colorbar_title = "metre")
scatter(xs, ys, values, spec)
```

Because the range methods are callable, Plots also accepts one directly as
`clims`:

```julia
heatmap(elevation; clims = Percentile(2, 98))
```

A runnable version is [`examples/plots.jl`](examples/plots.jl), whose
`plots_example()` is executed by the test suite.

## One scale across several panels

A specification never retains the observations it came from, so one of them can
color several plots on a shared scale:

```julia
spec = colorspec(elevation, Quantile(5); colorrange = Percentile(2, 98))

heatmap!(axis1, elevation, spec)
scatter!(axis2, xs, ys, values, spec)
Colorbar(figure[1, 3], spec; label = "metre")
```

When the panels come from separate datasets — years, scenarios, models — no
data-derived method can promise them the same classes. `FixedBreaks` can,
because it inspects nothing:

```julia
edges = FixedBreaks([0, 100, 250, 500, 1000, 2500])

heatmap!(axis1, elevation_1990, colorspec(elevation_1990, edges))
heatmap!(axis2, elevation_2020, colorspec(elevation_2020, edges))
```

The edges are authoritative: they become the specification's color range, and a
`colorrange` passed alongside them is discarded.

## Shorthand: no specification at all

For a one-off plot, put the break method in the specification's slot.
`colorrange` and `colormap` are read from the plotting call itself in Makie,
`clims` and `seriescolor` in Plots:

```julia
heatmap!(axis, elevation, Quantile(5); colorrange = Percentile(2, 98))   # Makie
heatmap(elevation, Quantile(5); clims = Percentile(2, 98))               # Plots
```

A color-range method in the same slot gives the continuous case,
`heatmap(elevation, Percentile(2, 98))`.

The shorthand leaves no specification behind, so a Makie colorbar built from
the plot labels class edges numerically instead of by interval, and Plots gets
no class ticks. Name a specification when you want the class intervals, or one
scale across panels.

## Your own keywords stay in charge

Everything a specification contributes is a default, so an explicit keyword on
the call wins:

```julia
heatmap!(axis, elevation, spec; colormap = :magma)   # Makie
heatmap(elevation, spec; clims = (0.0, 5000.0))      # Plots
```

No exported name collides with Makie or Plots, so `using ColorScales, Makie`
and `using ColorScales, Plots` need no qualification.

## Writing it out by hand

Everything above is convenience. A `ColorSpec` is three plain values, and
handing them to a plotting call yourself always works — no argument rule, no
recipe, no conversion, nothing of ColorScales in the call at all:

```julia
heatmap!(axis, elevation;                       # Makie
    colormap = colorgradient(spec), colorrange = colorrange(spec))

heatmap(elevation;                              # Plots
    seriescolor = colorgradient(spec), clims = colorrange(spec))
```

Reach for this when the argument rule cannot fit — a plot type it does not
reach, a recipe of your own, or an argument list it would collide with.
`classticks(spec)` carries the class intervals to a colorbar, as Makie's
`ticks` or Plots' `colorbar_ticks`, and is `nothing` for a continuous
specification.

## Constant data

A renderer cannot map a value through a zero-width span — a categorical
gradient has no position for it and throws. `colorrange(spec)` therefore widens
a constant range symmetrically around its value, which is what makes it safe to
hand to any plotting call. `display = false` gives the range the data actually
gave, which is the one the class edges span:

```julia
julia> spec = colorspec(fill(7.0, 4), Quantile(4));

julia> colorrange(spec)
(6.5, 7.5)

julia> colorrange(spec; display = false)
(7.0, 7.0)

julia> classbreaks(spec).edges
1-element Vector{Float64}:
 7.0
```

Widening is the identity for every range of nonzero width, so the keyword only
ever matters for constant data.

## Right-closed intervals

Classes are right-closed, `(a, b]`, and the first class includes the color
range's lower endpoint, `[a, b]`. This matches QGIS graduated ranges and
PlotUtils categorical gradients, so a value exactly on an interior edge belongs
to the lower class. `k` classes have `k + 1` edges, except that constant data
collapses to a single edge and a single class.

Edges that coincide at the floating-point resolution, and tied observations
under `Quantile`, drop duplicate edges. You then get fewer classes than
requested rather than an error, and the gradient always holds exactly
`nclasses(spec)` colors.

## Invalid values

`missing` and non-finite observations are skipped by default. Pass
`invalid = :error` to reject them instead:

```julia
julia> colorrange([1.0, missing, NaN, 9.0], Extrema())
(1.0, 9.0)

julia> colorrange([1.0, missing, 9.0], Extrema(); invalid = :error)
ERROR: ArgumentError: missing observation rejected by invalid=:error
```

Methods that need data raise an `ArgumentError` when no usable observation
remains; `FixedRange` works on empty input because it never looks at the data.

## Outlier saturation

A single extreme value drags `Extrema()` over the whole colormap. A percentile
range clips it, and the outlier saturates on the last class instead:

```julia
julia> z = collect(1.0:100.0); z[end] = 1.0e6;

julia> colorrange(z, Extrema())
(1.0, 1.0e6)

julia> colorrange(z, Percentile(2, 98))
(2.98, 98.02)
```

Class edges of data-based methods come only from observations inside the color
range, so a clipped outlier cannot move a class boundary either.

## Documentation

The [docs](docs) folder holds a visual [Documenter](https://documenter.juliadocs.org)
site: one page per color range method, one per graduated-class method, and one
each for the Makie and Plots workflows, all shown on the same synthetic raster
and scattered points. Build it locally with:

```julia
using Pkg
Pkg.activate("docs")
Pkg.develop(path = ".")
Pkg.instantiate()
include("docs/make.jl")
```

Open `docs/build/index.html` in a browser.

## Scope

This release is deliberately small: four color ranges, three graduated methods,
and two plotting extensions. The broader QGIS method inventory — fixed and geometric
intervals, standard-deviation and natural breaks, automatic class counts,
symmetric ranges — is intentionally deferred, and the research behind that
inventory is written up in
[`docs/research/2026-08-27-color-utilities-ecosystem.md`](docs/research/2026-08-27-color-utilities-ecosystem.md).
