# Color ranges

A color range is the closed span `(low, high)` mapped onto a colormap.
`colorrange(z, method)` computes it, and a method passed as a plot's last
argument colors that plot with it directly — no specification to name, because
a continuous colorbar needs no class labels.

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
figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
rastered = heatmap!(axis1, raster, Extrema(); colormap = :turbo)
Colorbar(figure[1, 2], rastered)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys, values, Extrema(); colormap = :turbo, markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `Percentile(2, 98)`

Two percentiles on the `0`–`100` scale. The outlier saturates at the top of the
colormap instead of dominating it.

```@example ranges
figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
rastered = heatmap!(axis1, raster, Percentile(2, 98); colormap = :turbo)
Colorbar(figure[1, 2], rastered)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys, values, Percentile(2, 98); colormap = :turbo, markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `MeanStd(2)`

`mean ± 2 * std`, not clamped to the data. Wider or narrower than the
percentile range depending on how the data is distributed.

```@example ranges
figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
rastered = heatmap!(axis1, raster, MeanStd(2); colormap = :turbo)
Colorbar(figure[1, 2], rastered)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys, values, MeanStd(2); colormap = :turbo, markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `FixedRange(0, 5000)`

A caller-chosen span; the data is never inspected.

```@example ranges
figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
rastered = heatmap!(axis1, raster, FixedRange(0, 5000); colormap = :turbo)
Colorbar(figure[1, 2], rastered)
axis2 = Axis(figure[1, 3]; title = "points", aspect = DataAspect())
points = scatter!(axis2, xs, ys, values, FixedRange(0, 5000); colormap = :turbo, markersize = 12)
Colorbar(figure[1, 4], points)
figure
```

## `Centered()`

Diverging data — an anomaly, a difference, a trend, a correlation — has a value
that means "no change", and a diverging colormap has a neutral color in its
middle. The two only line up if the range is symmetric about that value.
`Centered(inner; center = 0)` takes whichever side of `inner`'s range reaches
further and mirrors it.

The field below is lopsided on purpose: it runs to `+9` on one side and barely
past `-1.8` on the other.

```@example ranges
anomaly = sample_anomaly()

figure = Figure(; size = (900, 320))
axis1 = Axis(figure[1, 1]; title = "Extrema()", aspect = DataAspect())
plain = heatmap!(axis1, anomaly, Extrema(); colormap = :RdBu)
Colorbar(figure[1, 2], plain)
axis2 = Axis(figure[1, 3]; title = "Centered()", aspect = DataAspect())
centered = heatmap!(axis2, anomaly, Centered(); colormap = :RdBu)
Colorbar(figure[1, 4], centered)
figure
```

Under `Extrema()` the neutral color sits at `3.6`, so genuinely negative cells
read as mildly positive. `Centered()` puts it on zero, at the price of spending
the top of the colormap on values the data never reaches.

Any range method can be centered, which is the usual way to pay less for that:
clip the outlier first, then mirror what is left.

```@example ranges
figure = Figure(; size = (900, 320))
axis1 = Axis(figure[1, 1]; title = "Centered()", aspect = DataAspect())
wide = heatmap!(axis1, anomaly, Centered(); colormap = :RdBu)
Colorbar(figure[1, 2], wide)
axis2 = Axis(figure[1, 3]; title = "Centered(Percentile(2, 98))", aspect = DataAspect())
clipped = heatmap!(axis2, anomaly, Centered(Percentile(2, 98)); colormap = :RdBu)
Colorbar(figure[1, 4], clipped)
figure
```

`center` moves the neutral value elsewhere: `Centered(; center = 1)` for a ratio
that means "no change" at one, for instance.
