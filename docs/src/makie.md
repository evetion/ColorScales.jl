# Makie

A specification goes last, after the values it colors. `Colorbar` takes it on
its own, and labels each class center with its interval when the specification
is graduated.

```@setup makie
include(joinpath(@__DIR__, "assets", "data.jl"))
using ColorScales, CairoMakie

raster = sample_raster()
xs, ys, values = sample_points()
```

## Continuous heatmap

```@example makie
spec = colorspec(raster; colorrange = Percentile(2, 98))

figure = Figure(; size = (500, 420))
axis = Axis(figure[1, 1]; title = "elevation", aspect = DataAspect())
heatmap!(axis, raster, spec)
Colorbar(figure[1, 2], spec; label = "metre")
figure
```

## Graduated heatmap with a class-labelled colorbar

```@example makie
spec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (500, 420))
axis = Axis(figure[1, 1]; title = "elevation", aspect = DataAspect())
heatmap!(axis, raster, spec)
Colorbar(figure[1, 2], spec; label = "metre")
figure
```

## Graduated scatter of point data

The same rule colors points: `xs` and `ys` position them, `values` is what gets
colored, and the specification goes last. Makie's own classification of the
plot type decides whether the colored argument stays positional or becomes the
`color` attribute, so nothing about the call changes.

```@example makie
spec = colorspec(values, Pretty(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (500, 420))
axis = Axis(figure[1, 1]; title = "stations", aspect = DataAspect())
scatter!(axis, xs, ys, values, spec; markersize = 16)
Colorbar(figure[1, 2], spec; label = "value")
figure
```

## One scale across several panels

A specification never retains the observations it came from, so one of them can
color several plots on a shared scale. Compute it from the data that should set
the scale and pass it everywhere.

```@example makie
spec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (760, 340))
axis1 = Axis(figure[1, 1]; title = "raster", aspect = DataAspect())
heatmap!(axis1, raster, spec)
axis2 = Axis(figure[1, 2]; title = "stations", aspect = DataAspect())
scatter!(axis2, xs, ys, values, spec; markersize = 12)
Colorbar(figure[1, 3], spec; label = "metre")
figure
```

## Shorthand: no specification at all

For a one-off plot, put the break method in the specification's slot.
`colorrange` and `colormap` are read from the plotting call itself, so
`colorrange = Percentile(2, 98)` reads exactly as it would anywhere else in
Makie.

```@example makie
figure = Figure(; size = (500, 420))
axis = Axis(figure[1, 1]; title = "elevation", aspect = DataAspect())
plot = heatmap!(axis, raster, Quantile(5); colorrange = Percentile(2, 98))
Colorbar(figure[1, 2], plot; label = "metre")
figure
```

A color-range method in the same slot gives the continuous case,
`heatmap!(axis, raster, Percentile(2, 98))`.

The shorthand leaves no specification behind, so the colorbar here is built
from the plot and labels class edges numerically. Name a specification when you
want the class intervals, or one scale across panels.

## Constant data

`colorrange(spec)` widens a constant range so the renderer has a nonzero span
to map through, and `display = false` gives the exact `(v, v)` the data
produced:

```@example makie
spec = colorspec(fill(7.0, 4), Quantile(4))
colorrange(spec), colorrange(spec; display = false)
```

## Escape hatch

For a plot type the argument rule cannot reach, a `ColorSpec` still converts
directly to `colormap`/`colorrange`:

```@example makie
spec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (500, 420))
axis = Axis(figure[1, 1]; title = "elevation", aspect = DataAspect())
heatmap!(axis, raster; colormap = spec, colorrange = spec)
figure
```

Pass `spec` to both keywords together: giving it to only one leaves the other
at Makie's default, which does not match `spec` and can miscolor the plot.

## Writing it out by hand

That still goes through this package's conversions. Underneath them a
specification is three plain values, and passing those yourself works whatever
else is in the call — your own recipe, an argument list the rule would collide
with, a plot type neither route reaches:

```@example makie
spec = colorspec(raster, Quantile(5); colorrange = Percentile(2, 98))

figure = Figure(; size = (500, 420))
axis = Axis(figure[1, 1]; title = "elevation", aspect = DataAspect())
heatmap!(axis, raster; colormap = colorgradient(spec), colorrange = colorrange(spec))
Colorbar(
    figure[1, 2]; label = "metre",
    colormap = colorgradient(spec), colorrange = colorrange(spec), ticks = classticks(spec),
)
figure
```

`colorrange(spec)` is renderer-safe as it comes, so nothing here needs a
special case for constant data. `classticks(spec)` is what labels each class
center with its interval; it is `nothing` for a continuous specification, whose
colorbar needs no tick override at all.

`colorrange(spec)`, `colorgradient(spec)`, `classbreaks(spec)`, and
`classticks(spec)` are the accessors everything on this page is built from.
