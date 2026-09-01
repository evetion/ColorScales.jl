# Color ranges

A color range is the closed span `(low, high)` mapped onto a colormap.
`colorrange(z, method)` computes it; `colorspec(z; colorrange = method)` uses it
directly for a continuous specification, with no class breaks; and
`makieattributes(spec)` returns the keywords for the plot and its colorbar.

Each figure below shows the same raster and the same scattered points, colored
only by the outlined method. Look for how much of the colormap the outlier at
the top eats up.

```@setup ranges
include(joinpath(@__DIR__, "assets", "data.jl"))
using ColorScales, CairoMakie

raster = sample_raster()
xs, ys, values = sample_points()
```

## `Extrema()`

Smallest to largest usable observation. The outlier stretches the whole
colormap, flattening everything else into a single shade.

```@example ranges
rasterspec = colorspec(raster; colorrange = Extrema(), colormap = :turbo)
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values; colorrange = Extrema(), colormap = :turbo)
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `Percentile(2, 98)`

Two percentiles on the `0`–`100` scale. The outlier saturates at the top of the
colormap instead of dominating it.

```@example ranges
rasterspec = colorspec(raster; colorrange = Percentile(2, 98), colormap = :turbo)
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values; colorrange = Percentile(2, 98), colormap = :turbo)
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `MeanStd(2)`

`mean ± 2 * std`, not clamped to the data. Wider or narrower than the
percentile range depending on how the data is distributed.

```@example ranges
rasterspec = colorspec(raster; colorrange = MeanStd(2), colormap = :turbo)
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values; colorrange = MeanStd(2), colormap = :turbo)
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `FixedRange(0, 5000)`

A caller-chosen span; the data is never inspected.

```@example ranges
rasterspec = colorspec(raster; colorrange = FixedRange(0, 5000), colormap = :turbo)
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values; colorrange = FixedRange(0, 5000), colormap = :turbo)
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points)
figure
```
