module ColorScalesPlotsExt

using ColorScales
using Plots

"""
    ColoredValues

The observations a series colors: an array of reals, possibly holding
`missing`.
"""
const ColoredValues = AbstractArray{<:Union{Real, Missing}}

"""
    colorattributes(spec::ColorSpec) -> NamedTuple

Series attributes carrying `spec`: `clims`, `seriescolor`, and, for a graduated
specification, one `colorbar_ticks` entry per class labelled with the class
interval. Plots needs no separate colorbar call, because the ticks ride along
on the series.

The GR backend draws its own numeric colorbar ticks and ignores custom labels;
`pythonplot` and `pgfplotsx` render them.

A constant color range arrives widened to renderer-safe display limits around
its value, as `colorrange(spec)` returns it; `colorrange(spec; display = false)`
is the exact one.
"""
function colorattributes(spec::ColorSpec)
    attributes = (;
        clims = colorrange(spec),
        seriescolor = colorgradient(spec),
    )
    ticks = classticks(spec)
    return ticks === nothing ? attributes : (; attributes..., colorbar_ticks = ticks)
end

"""
    colorseries!(plotattributes, positions, values, spec, seriestype) -> Tuple

Attach `spec` to the series being built and return the positional arguments
that carry `values`.

Every attribute is a default, so an explicit keyword on the plotting call still
wins.

A surface-like series colors its last positional argument, so `values` stays
positional. Every other series colors through `line_z` or `marker_z`, mirroring
how Makie routes color for point-based plots. Without positions the values are
both, just as `scatter(values)` plots them against their own indices.
"""
function colorseries!(plotattributes, positions::Tuple, values, spec::ColorSpec, seriestype::Symbol)
    for (key, value) in pairs(colorattributes(spec))
        get!(plotattributes, key, value)
    end
    Plots.RecipesPipeline.is_surface(seriestype) && return (positions..., values)
    get!(plotattributes, Plots.like_line(seriestype) ? :line_z : :marker_z, values)
    return isempty(positions) ? (values,) : positions
end

seriestypeof(plotattributes) = get(plotattributes, :seriestype, :heatmap)

# Color `values` with `spec`, defaulting to a heatmap:
#
#     heatmap(elevation, spec; title = "elevation", colorbar_title = "metre")
#     scatter(xs, ys, values, spec)
#
@recipe function f(values::ColoredValues, spec::ColorSpec)
    seriestype --> :heatmap
    return colorseries!(plotattributes, (), values, spec, seriestypeof(plotattributes))
end

@recipe function f(x, y, values::ColoredValues, spec::ColorSpec)
    seriestype --> :heatmap
    return colorseries!(plotattributes, (x, y), values, spec, seriestypeof(plotattributes))
end

# The inline shorthand: a break or color-range method in the specification's
# slot. `clims` takes a color-range method and `seriescolor` a colormap. Both
# are inputs to the computation rather than series attributes, so they are
# consumed here and replaced by the computed values, the way Makie's
# `used_attributes` withholds them from the backend:
#
#     heatmap(elevation, Quantile(5); clims = Percentile(2, 98))
#     heatmap(elevation, Percentile(2, 98))
#
# `clims = Percentile(2, 98)` also works on its own, because the range methods
# are callable and Plots calls `clims` on the data itself.
@recipe function f(
        values::ColoredValues, method::ColorScales.BreakMethod;
        clims = Extrema(), seriescolor = :viridis
    )
    seriestype --> :heatmap
    spec = colorspec(values, method; colorrange = clims, colormap = seriescolor)
    delete!(plotattributes, :clims)
    delete!(plotattributes, :seriescolor)
    return colorseries!(plotattributes, (), values, spec, seriestypeof(plotattributes))
end

@recipe function f(
        values::ColoredValues, method::ColorScales.ColorRangeMethod; seriescolor = :viridis
    )
    seriestype --> :heatmap
    spec = colorspec(values; colorrange = method, colormap = seriescolor)
    delete!(plotattributes, :seriescolor)
    return colorseries!(plotattributes, (), values, spec, seriestypeof(plotattributes))
end

end
