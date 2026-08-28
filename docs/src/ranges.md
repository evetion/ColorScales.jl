# Color ranges

A color range is the closed span `(low, high)` mapped onto a colormap.
`colorrange(z, method)` computes it; `colorspec(z; colorrange = method)` uses it
directly for a continuous specification, with no class breaks.

Each figure below shows the same raster and the same scattered points, colored
only by the outlined method. Look for how much of the colormap the outlier at
the top eats up.

```@setup ranges
include(joinpath(@__DIR__, "assets", "data.jl"))
using ColorScales, CairoMakie

raster = sample_raster()
xs, ys, values = sample_points()

function rangefigure(method)
    figure = Figure(; size = (700, 340))

    rasterspec = colorspec(raster; colorrange = method, colormap = :turbo)
    rasterattrs = makieattributes(rasterspec)
    axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
    heatmap!(axis1, raster; rasterattrs.plot...)

    pointspec = colorspec(values; colorrange = method, colormap = :turbo)
    pointattrs = makieattributes(pointspec)
    axis2 = Axis(figure[1, 2]; title = "points", aspect = DataAspect())
    scatter!(axis2, xs, ys; color = values, pointattrs.plot..., markersize = 12)

    return figure
end
```

## `Extrema()`

Smallest to largest usable observation. The outlier stretches the whole
colormap, flattening everything else into a single shade.

```@example ranges
rangefigure(Extrema())
```

## `Percentile(2, 98)`

Two percentiles on the `0`–`100` scale. The outlier saturates at the top of the
colormap instead of dominating it.

```@example ranges
rangefigure(Percentile(2, 98))
```

## `MeanStd(2)`

`mean ± 2 * std`, not clamped to the data. Wider or narrower than the
percentile range depending on how the data is distributed.

```@example ranges
rangefigure(MeanStd(2))
```

## `FixedRange(0, 5000)`

A caller-chosen span; the data is never inspected.

```@example ranges
rangefigure(FixedRange(0, 5000))
```
