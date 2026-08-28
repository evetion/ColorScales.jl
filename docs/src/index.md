# ColorScales.jl

ColorScales turns numeric data into renderer-neutral color specifications:
robust color ranges, interpretable graduated classes, and one gradient that
[Makie](https://docs.makie.org) and [Plots](https://docs.juliaplots.org) both
understand.

ColorScales computes colors. It never plots — the [Makie](@ref) and
[Plots](@ref) pages show how thin adapters turn a specification into keyword
arguments for your own plotting call.

## Data used throughout these docs

Every example below reuses the same two synthetic datasets: a `40×40` raster
holding one large outlier, and a scattered sample of `120` points drawn from
that same surface. Both stand in for the kind of noisy, outlier-prone data
this package is built for.

## Pages

  - [Color ranges](@ref): the four `colorrange` methods, each shown on the
    raster and on the points.
  - [Graduated classes](@ref): the three `breaks` methods, discretizing the
    same data into labelled classes.
  - [Makie](@ref) and [Plots](@ref): the full `colorspec` → adapter workflow
    for heatmaps and scatter plots in each renderer.

## Installation

ColorScales is not registered yet. Install it from a local checkout:

```julia
using Pkg
Pkg.develop(path = "/path/to/ColorScales")
```
