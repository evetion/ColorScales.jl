module ColorScalesMakieExt

using ColorScales
using Makie

"""
    makieattributes(spec::ColorSpec) -> (; plot, colorbar)

Makie keyword arguments for `spec`.

`plot` holds `colorrange` and `colormap` for a plotting call such as
`heatmap!`. `colorbar` holds the `Colorbar` keyword arguments: class-centered
`ticks` labelled with the class intervals for a graduated specification, and
nothing for a continuous one, whose colorbar needs no override.

A constant color range is widened to renderer-safe display limits around its
value; `spec.colorrange` itself stays exact.
"""
function ColorScales.makieattributes(spec::ColorSpec)
    plot = (; colorrange = ColorScales.displayrange(colorrange(spec)), colormap = colorgradient(spec))
    ticks = classticks(spec)
    return (; plot = plot, colorbar = ticks === nothing ? NamedTuple() : (; ticks = ticks))
end

"""
    Makie.convert_attribute(spec::ColorSpec, ::Makie.Key{:colormap})
    Makie.convert_attribute(spec::ColorSpec, ::Makie.Key{:colorrange})

Let a plotting call take `spec` directly as `colormap`/`colorrange`, e.g.
`heatmap!(ax, z; colormap = spec, colorrange = spec)`.

Pass `spec` to both keywords together. Passing it to only one leaves the
other at Makie's own default, which is not `spec`'s matching range or
gradient and can silently miscolor the plot.
"""
Makie.convert_attribute(spec::ColorSpec, key::Makie.Key{:colormap}) =
    Makie.convert_attribute(colorgradient(spec), key)
Makie.convert_attribute(spec::ColorSpec, key::Makie.Key{:colorrange}) =
    Makie.convert_attribute(ColorScales.displayrange(colorrange(spec)), key)

end
