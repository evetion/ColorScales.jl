# ColorScales

Turn univariate numeric data into renderer-neutral color specifications: a
robust color range, interpretable graduated classes, readable class labels, and
one gradient that both [Makie](https://docs.makie.org) and
[Plots](https://docs.juliaplots.org) understand.

ColorScales computes colors. It never plots: adapters hand you plain keyword
arguments that you splat into your own plotting call.

## Installation

ColorScales is not registered. Install it from a local checkout:

```julia
julia> using Pkg

julia> Pkg.develop(path = "/path/to/ColorScales")
```

`PlotUtils` is the only hard dependency. The Makie and Plots adapters live in
package extensions, so they load automatically once you load Makie or Plots.

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

julia> spec.colorrange, nclasses(spec.breaks)
((2.0, 98.0), 4)
```

Leave the break method out for a continuous specification: `colorspec(z)` carries
no classes and a continuous gradient.

## Makie

`makieattributes(spec)` returns `(; plot, colorbar)`. Splat `plot` into your
plotting call and `colorbar` into `Colorbar`. Graduated specifications tick each
class center with its interval label; continuous ones leave the colorbar alone.

```julia
using ColorScales, Makie, GLMakie

spec = colorspec(elevation, Quantile(5); colorrange = Percentile(2, 98))
attributes = makieattributes(spec)

figure = Figure()
axis = Axis(figure[1, 1])
heatmap = heatmap!(axis, elevation; attributes.plot...)
Colorbar(figure[1, 2], heatmap; attributes.colorbar..., label = "metre")
```

A runnable version is [`examples/makie.jl`](examples/makie.jl), whose
`makie_example()` is executed by the test suite.

## Plots

`plotsattributes(spec)` returns `(; plot)` holding `clims`, `color`, and, for
graduated specifications, `colorbar_ticks`.

```julia
using ColorScales, Plots

spec = colorspec(elevation, Pretty(5); colorrange = Percentile(2, 98))
heatmap(elevation; plotsattributes(spec).plot...)
```

Because the range methods are callable, Plots also accepts one directly as
`clims`:

```julia
heatmap(elevation; clims = Percentile(2, 98))
```

A runnable version is [`examples/plots.jl`](examples/plots.jl), whose
`plots_example()` is executed by the test suite.

Your own keywords stay in charge — the adapters return plain named tuples:

```julia
merge(makieattributes(spec).plot, (; colormap = :magma))
```

No exported name collides with Makie or Plots, so `using ColorScales, Makie` and
`using ColorScales, Plots` need no qualification.

## Right-closed intervals

Classes are right-closed, `(a, b]`, and the first class includes the color
range's lower endpoint, `[a, b]`. This matches QGIS graduated ranges and
PlotUtils categorical gradients, so a value exactly on an interior edge belongs
to the lower class. `k` classes have `k + 1` edges, except that constant data
collapses to a single edge and a single class.

Edges that coincide at the floating-point resolution, and tied observations
under `Quantile`, drop duplicate edges. You then get fewer classes than
requested rather than an error, and the gradient always holds exactly
`nclasses(spec.breaks)` colors.

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

## Scope

This release is deliberately small: four color ranges, three graduated methods,
and two adapters. The broader QGIS method inventory — fixed and geometric
intervals, standard-deviation and natural breaks, automatic class counts,
symmetric ranges — is intentionally deferred, and the research behind that
inventory is written up in
[`docs/research/2026-08-27-color-utilities-ecosystem.md`](docs/research/2026-08-27-color-utilities-ecosystem.md).
