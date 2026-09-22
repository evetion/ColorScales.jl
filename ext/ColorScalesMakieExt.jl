module ColorScalesMakieExt

using ColorScales
using Makie

"""
    ColoredValues

The observations a plot colors: an array of reals, possibly holding `missing`.
"""
const ColoredValues = AbstractArray{<:Union{Real, Missing}}

"""
    specplot(P, positions, values, spec) -> Makie.PlotSpec

Plot specification drawing `values` at `positions`, colored by `spec`.

`Makie.convert_arguments` may return a `Makie.PlotSpec`, whose keyword
arguments become plot attributes. That is what lets a [`ColorSpec`](@ref) set
`colormap` and `colorrange` from an argument rather than from splatted
keywords.

The plot type is resolved from `P` and the arguments, so `heatmap`, `surface`,
`image`, `volume`, and `scatter` all share this one implementation.
Point-based plots take their color as an attribute; every other plot takes it
as its last positional argument.
"""
function specplot(P::Type{<:Makie.Plot}, positions::Tuple, values, spec::ColorSpec)
    resolved = Makie.plottype(P, Makie.plottype(positions..., values))
    symbol = Makie.plotsym(resolved)
    symbol === :plot && throw(
        ArgumentError(
            "cannot infer a plot type from these arguments; call a specific plotting " *
                "function such as heatmap or scatter"
        )
    )
    if Makie.conversion_trait(resolved) isa Makie.PointBased
        # Points carry their color as an attribute. Without positions the values
        # are both, just as Makie's own `scatter(values)` expands its dimensions.
        arguments = isempty(positions) ? (values,) : ()
        colorattribute = (; color = values)
    else
        arguments = (values,)
        colorattribute = NamedTuple()
    end
    return Makie.PlotSpec(
        symbol, positions..., arguments...;
        colorrange = colorrange(spec),
        colormap = colorgradient(spec),
        colorattribute...,
    )
end

# The specification goes last, so every arity needs its own method: Julia does
# not allow a `Vararg` to precede a positional argument. Three leading positions
# cover `volume(x, y, z, values, spec)` and `scatter(x, y, z, values, spec)`;
# the rest cover `heatmap(values, spec)`, `heatmap(x, y, values, spec)`,
# `scatter(points, values, spec)`, and `scatter(x, y, values, spec)`.
#
# A break or color-range method in the specification's slot is the inline
# shorthand: `used_attributes` takes `colorrange` and `colormap` from the
# plotting call and Makie withholds both from the backend, which is why
# `colorrange = Percentile(2, 98)` never arrives as a raw method. A
# `ColorRangeMethod` occupies the argument slot itself, so only `colormap` is
# read alongside it.
for arity in 0:3
    positions = [Symbol(:position, i) for i in 1:arity]
    postuple = Expr(:tuple, positions...)
    @eval begin
        Makie.convert_arguments(
            P::Type{<:Makie.Plot}, $(positions...), values::ColoredValues, spec::ColorSpec
        ) = specplot(P, $postuple, values, spec)

        Makie.used_attributes(
            ::Type{<:Makie.Plot}, $(positions...), ::ColoredValues, ::ColorScales.BreakMethod
        ) = (:colorrange, :colormap)

        function Makie.convert_arguments(
                P::Type{<:Makie.Plot}, $(positions...), values::ColoredValues,
                method::ColorScales.BreakMethod; colorrange = Extrema(), colormap = :viridis
            )
            return specplot(P, $postuple, values, colorspec(values, method; colorrange, colormap))
        end

        Makie.used_attributes(
            ::Type{<:Makie.Plot}, $(positions...), ::ColoredValues, ::ColorScales.ColorRangeMethod
        ) = (:colormap,)

        function Makie.convert_arguments(
                P::Type{<:Makie.Plot}, $(positions...), values::ColoredValues,
                method::ColorScales.ColorRangeMethod; colormap = :viridis
            )
            return specplot(P, $postuple, values, colorspec(values; colorrange = method, colormap))
        end
    end
end

"""
    Makie.Colorbar(position, spec::ColorSpec; attributes...)

Colorbar for `spec`, carrying its gradient, its color range, and, for a
graduated specification, one tick per class labelled with the class interval.
Any attribute you pass wins over those.

```julia
figure = Figure()
axis = Axis(figure[1, 1])
heatmap!(axis, elevation, spec)
Colorbar(figure[1, 2], spec; label = "metre")
```

`Colorbar(position, plot)` keeps working as well: Makie renders a categorical
gradient as proportional bands on its own, but labels class edges numerically
instead of by interval.

A constant color range arrives widened to renderer-safe display limits around
its value, as `colorrange(spec)` returns it; `colorrange(spec; display = false)`
is the exact one.
"""
function Makie.Colorbar(position, spec::ColorSpec; attributes...)
    defaults = (;
        colormap = colorgradient(spec),
        colorrange = colorrange(spec),
    )
    ticks = classticks(spec)
    ticked = ticks === nothing ? defaults : (; defaults..., ticks)
    return Makie.Colorbar(position; ticked..., attributes...)
end

"""
    Makie.convert_attribute(spec::ColorSpec, ::Makie.Key{:colormap})
    Makie.convert_attribute(spec::ColorSpec, ::Makie.Key{:colorrange})

Escape hatch for plot types the argument rule cannot reach, letting a plotting
call take `spec` as `colormap`/`colorrange`, e.g.
`hexbin(xs, ys; colormap = spec, colorrange = spec)`.

Pass `spec` to both keywords together. Passing it to only one leaves the other
at Makie's own default, which is not `spec`'s matching range or gradient and
can silently miscolor the plot. Prefer `plot(values, spec)` wherever it
applies.
"""
Makie.convert_attribute(spec::ColorSpec, key::Makie.Key{:colormap}) =
    Makie.convert_attribute(colorgradient(spec), key)
Makie.convert_attribute(spec::ColorSpec, key::Makie.Key{:colorrange}) =
    Makie.convert_attribute(colorrange(spec), key)

end
