# Graduated classes

`breaks` divides a color range into right-closed classes and labels them.
`colorspec(z, method; colorrange)` computes both the range and the classes in
one pass, and the resulting gradient is categorical: one flat color per class.
Pass the specification as a plot's last argument to color it, and to
`Colorbar` to label each class center with its interval.

Every figure below fixes the color range to `Percentile(2, 98)` and varies only
the break method, so the difference is the classes, not the range.

```@setup breaks
include(joinpath(@__DIR__, "assets", "data.jl"))
using ColorScales, CairoMakie

raster = sample_raster()
xs, ys, values = sample_points()
```

## `EqualInterval(5)`

Five classes of equal width over the color range.

```@example breaks
rasterspec = colorspec(raster, EqualInterval(5); colorrange = Percentile(2, 98))
pointspec = colorspec(values, EqualInterval(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap!(axis1, raster, rasterspec)
Colorbar(figure[1, 2], rasterspec)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
scatter!(axis2, xs, ys, values, pointspec; markersize = 12)
Colorbar(figure[1, 4], pointspec)
figure
```

## `Quantile(5)`

Five classes, each holding an equal share of the in-range observations. Wider
classes where the data is sparse, narrower where it is dense.

```@example breaks
rasterspec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))
pointspec = colorspec(values, Quantile(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap!(axis1, raster, rasterspec)
Colorbar(figure[1, 2], rasterspec)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
scatter!(axis2, xs, ys, values, pointspec; markersize = 12)
Colorbar(figure[1, 4], pointspec)
figure
```

## `Pretty(5)`

Interior edges snapped to readable multiples of `{1, 2, 5} * 10ⁿ`, at the cost
of not holding exactly five classes.

```@example breaks
rasterspec = colorspec(raster, Pretty(5); colorrange = Percentile(2, 98))
pointspec = colorspec(values, Pretty(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap!(axis1, raster, rasterspec)
Colorbar(figure[1, 2], rasterspec)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
scatter!(axis2, xs, ys, values, pointspec; markersize = 12)
Colorbar(figure[1, 4], pointspec)
figure
```

## `FixedBreaks([0, 25, 100, 225, 400, 625])`

Edges chosen by the caller, in the data's own units. The observations are never
inspected and the edges become the color range, so the same call classifies
every panel, year or scenario identically — which is what a figure with more
than one map needs, and what no data-derived method can promise.

```@example breaks
edges = [0, 25, 100, 225, 400, 625]
rasterspec = colorspec(raster, FixedBreaks(edges))
pointspec = colorspec(values, FixedBreaks(edges))

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap!(axis1, raster, rasterspec)
Colorbar(figure[1, 2], rasterspec)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
scatter!(axis2, xs, ys, values, pointspec; markersize = 12)
Colorbar(figure[1, 4], pointspec)
figure
```

The two panels carry one legend because both were classified by the same edges,
and the classes are free to be unequally wide — here they are evenly spaced in
distance, not in distance squared. Values past the last edge saturate in the
top class.
