# Graduated classes

`breaks` divides a color range into right-closed classes and labels them.
`colorspec(z, method; colorrange)` computes both the range and the classes in
one pass, and the resulting gradient is categorical: one flat color per class.
`makieattributes(spec).colorbar` holds a class-labelled tick at each class
center, ready to splat into `Colorbar`.

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
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values, EqualInterval(5); colorrange = Percentile(2, 98))
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1; rasterattrs.colorbar...)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points; pointattrs.colorbar...)
figure
```

## `Quantile(5)`

Five classes, each holding an equal share of the in-range observations. Wider
classes where the data is sparse, narrower where it is dense.

```@example breaks
rasterspec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values, Quantile(5); colorrange = Percentile(2, 98))
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1; rasterattrs.colorbar...)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points; pointattrs.colorbar...)
figure
```

## `Pretty(5)`

Interior edges snapped to readable multiples of `{1, 2, 5} * 10ⁿ`, at the cost
of not holding exactly five classes.

```@example breaks
rasterspec = colorspec(raster, Pretty(5); colorrange = Percentile(2, 98))
rasterattrs = makieattributes(rasterspec)
pointspec = colorspec(values, Pretty(5); colorrange = Percentile(2, 98))
pointattrs = makieattributes(pointspec)

figure = Figure(; size = (900, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
Colorbar(figure[1, 2], heatmap1; rasterattrs.colorbar...)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)
Colorbar(figure[1, 4], points; pointattrs.colorbar...)
figure
```
