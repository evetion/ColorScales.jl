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

```julia
julia> using ColorScales

julia> colorrange(0:100, Percentile(2, 98))
(2.0, 98.0)
```

## Graduated classes

`breaks` divides a color range into right-closed classes and labels them.

| Method | Classes |
| --- | --- |
| `EqualInterval(count)` | equal width over the color range |
| `Quantile(count)` | equal share of the in-range observations |
| `Pretty(count = 7)` | interior edges on readable multiples of `{1, 2, 5} * 10ⁿ` |

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

## Constant data

A specification computed from constant data keeps its exact color range, but a
renderer cannot map a value through a zero-width span — a categorical gradient
has no position for it and throws. The plotting extensions therefore widen the
*display* limits symmetrically around the value, while `colorrange(spec)` stays
exact:

```julia
julia> spec = colorspec(fill(7.0, 4), Quantile(4));

julia> colorrange(spec)
(7.0, 7.0)

julia> heatmap(fill(7.0, 2, 2), spec)[1][:clims]   # Plots
(6.5, 7.5)
```

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
