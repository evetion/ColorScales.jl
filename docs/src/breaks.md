# Graduated classes

`breaks` divides a color range into right-closed classes and labels them.
`colorspec(z, method; colorrange)` computes both the range and the classes in
one pass, and the resulting gradient is categorical: one flat color per class,
with a class-labelled colorbar tick at each class center.

Every figure below fixes the color range to `Percentile(2, 98)` and varies only
the break method, so the difference is the classes, not the range.

```@setup breaks
include(joinpath(@__DIR__, "assets", "data.jl"))
using ColorScales, CairoMakie

raster = sample_raster()
xs, ys, values = sample_points()

function breaksfigure(method)
    figure = Figure(; size = (760, 340))

    rasterspec = colorspec(raster, method; colorrange = Percentile(2, 98))
    rasterattrs = makieattributes(rasterspec)
    axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
    heatmap1 = heatmap!(axis1, raster; rasterattrs.plot...)
    Colorbar(figure[1, 2], heatmap1; rasterattrs.colorbar...)

    pointspec = colorspec(values, method; colorrange = Percentile(2, 98))
    pointattrs = makieattributes(pointspec)
    axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
    scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)

    return figure
end
```

## `EqualInterval(5)`

Five classes of equal width over the color range.

```@example breaks
breaksfigure(EqualInterval(5))
```

## `Quantile(5)`

Five classes, each holding an equal share of the in-range observations. Wider
classes where the data is sparse, narrower where it is dense.

```@example breaks
breaksfigure(Quantile(5))
```

## `Pretty(5)`

Interior edges snapped to readable multiples of `{1, 2, 5} * 10ⁿ`, at the cost
of not holding exactly five classes.

```@example breaks
breaksfigure(Pretty(5))
```
