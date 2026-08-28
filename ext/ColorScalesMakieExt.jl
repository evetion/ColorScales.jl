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
    plot = (; colorrange = ColorScales.displayrange(spec.colorrange), colormap = spec.gradient)
    classes = spec.breaks
    classes === nothing && return (; plot = plot, colorbar = NamedTuple())
    return (; plot = plot, colorbar = (; ticks = (classcenters(classes), classes.labels)))
end

end
