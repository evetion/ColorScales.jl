module ColorScalesPlotsExt

using ColorScales
using Plots

"""
    plotsattributes(spec::ColorSpec) -> (; plot)

Plots keyword arguments for `spec`.

`plot` holds `clims` and `color` for a plotting call such as `heatmap`, plus
class-centered `colorbar_ticks` labelled with the class intervals when `spec`
is graduated.

A constant color range is widened to renderer-safe display limits around its
value; `spec.colorrange` itself stays exact.
"""
function ColorScales.plotsattributes(spec::ColorSpec)
    clims = ColorScales.displayrange(spec.colorrange)
    classes = spec.breaks
    classes === nothing && return (; plot = (; clims = clims, color = spec.gradient))
    ticks = (classcenters(classes), classes.labels)
    return (; plot = (; clims = clims, color = spec.gradient, colorbar_ticks = ticks))
end

end
