# Plots

`plotsattributes(spec)` returns `(; plot)` holding `clims`, `color`, and, for a
graduated specification, `colorbar_ticks`. Splat `plot` into your plotting
call.

Because the range methods are callable, Plots also accepts one directly as
`clims`, e.g. `heatmap(raster; clims = Percentile(2, 98))`, with no
`colorspec` at all.

```@setup plots
include(joinpath(@__DIR__, "assets", "data.jl"))
using ColorScales, Plots
gr()

raster = sample_raster()
xs, ys, values = sample_points()
```

## Continuous heatmap

```@example plots
spec = colorspec(raster; colorrange = Percentile(2, 98))
heatmap(raster; plotsattributes(spec).plot..., title = "elevation", aspect_ratio = :equal)
```

## Graduated heatmap with a class-labelled colorbar

```@example plots
spec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))
heatmap(raster; plotsattributes(spec).plot..., title = "elevation", aspect_ratio = :equal)
```

## Graduated scatter of point data

The same specification colors point data through `marker_z`, Plots' per-point
color channel.

```@example plots
spec = colorspec(values, Pretty(5); colorrange = Percentile(2, 98))
scatter(
    xs, ys; marker_z = values, plotsattributes(spec).plot...,
    title = "stations", aspect_ratio = :equal, markersize = 6, legend = false
)
```

## Constant data

A constant color range keeps its exact `(v, v)` on `spec.colorrange`, but
`plotsattributes` widens the *display* limits so the renderer has a nonzero
span to map through:

```@example plots
spec = colorspec(fill(7.0, 4), Quantile(4))
spec.colorrange, plotsattributes(spec).plot.clims
```
