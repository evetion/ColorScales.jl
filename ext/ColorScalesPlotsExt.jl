module ColorScalesPlotsExt

using ColorScales
using Plots

"""
    plots(spec::ColorSpec) -> (; plot)

Plots keyword arguments for `spec`.

`plot` holds `clims` and `color` for a plotting call such as `heatmap`, plus
class-centered `colorbar_ticks` labelled with the class intervals when `spec`
is graduated.
"""
function ColorScales.plots(spec::ColorSpec)
    classes = spec.breaks
    classes === nothing && return (; plot = (; clims = spec.colorrange, color = spec.gradient))
    ticks = (classcenters(classes), classes.labels)
    return (; plot = (; clims = spec.colorrange, color = spec.gradient, colorbar_ticks = ticks))
end

end
