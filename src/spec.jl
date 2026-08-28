"""
Color specifications.

A `ColorSpec` is the renderer-neutral result: a color range, optional class
breaks, and one PlotUtils gradient shared by every plotting adapter. It never
retains the observations it came from.
"""

"""
    ColorSpec(colorrange, breaks, gradient)

Completed color result. `breaks` is `nothing` for a continuous specification and
a [`ClassBreaks`](@ref) for a graduated one, whose gradient is categorical.

`colorrange` is exactly what the data gave, including the zero-width `(v, v)` of
constant data. Only the plotting adapters widen that span into renderer-safe
display limits.
"""
struct ColorSpec
    colorrange::Tuple{Float64, Float64}
    breaks::Union{Nothing, ClassBreaks}
    gradient::PlotUtils.ColorGradient
end

"""
    classgradient(colormap, classes; colorrange) -> PlotUtils.CategoricalColorGradient

Categorical gradient whose stops are `classes`' edges normalized to
`colorrange`. The gradient always holds exactly `nclasses(classes)` colors.

Except for constant classes, the edges must span `colorrange` exactly: the
first edge has to equal its lower endpoint and the last edge its upper one.
Edges that fall short of or reach past the color range raise an
`ArgumentError` instead of being silently clamped onto a different class count.
Constant classes give a one-color gradient.

```jldoctest
julia> classgradient(:viridis, ClassBreaks([0.0, 1.0, 3.0]); colorrange = (0, 3)).values
3-element Vector{Float64}:
 0.0
 0.3333333333333333
 1.0
```
"""
function classgradient(colormap, classes::ClassBreaks; colorrange)
    low, high = checkrange(colorrange)
    edges = classes.edges
    length(edges) == 1 && return cgrad(colormap, [0.0, 1.0]; categorical = true)
    (first(edges) == low && last(edges) == high) || throw(
        ArgumentError(
            "class edges must span the color range exactly; got edges ($(first(edges)), $(last(edges))) " *
                "over the color range ($low, $high)"
        )
    )
    stops = (edges .- low) ./ (high - low)
    stops[begin] = 0.0
    stops[end] = 1.0
    return cgrad(colormap, stops; categorical = true)
end

"""
    colorspec(data; colorrange=Extrema(), colormap=:viridis, invalid=:skip) -> ColorSpec
    colorspec(data, method; colorrange=Extrema(), colormap=:viridis, invalid=:skip) -> ColorSpec

Compute a continuous or graduated color specification for `data` in one pass.

Without a break `method` the specification is continuous and carries no classes.
With one it is graduated: the color range comes from every usable observation,
the class edges from the observations inside that range, and the gradient is
categorical.

```jldoctest
julia> colorspec(0:100, Quantile(4); colorrange = Percentile(2, 98)).breaks.edges
5-element Vector{Float64}:
  2.0
 26.0
 50.0
 74.0
 98.0
```
"""
function colorspec(data; colorrange = Extrema(), colormap = :viridis, invalid = :skip)
    policy = check_invalid(invalid)
    selected = rangemethod(colorrange)
    obs = observe(data, datarequirement(selected); invalid = policy)
    return ColorSpec(rangefrom(obs, selected), nothing, cgrad(colormap))
end

function colorspec(data, method::BreakMethod; colorrange = Extrema(), colormap = :viridis, invalid = :skip)
    policy = check_invalid(invalid)
    selected = rangemethod(colorrange)
    requirement = max(datarequirement(selected), datarequirement(method))
    obs = observe(data, requirement; invalid = policy)
    bounds = rangefrom(obs, selected)
    classes = ClassBreaks(breakedges(obs, method, bounds))
    return ColorSpec(bounds, classes, classgradient(colormap, classes; colorrange = bounds))
end

"""
    displayrange(bounds) -> Tuple{Float64,Float64}

Renderer-safe display limits for the color range `bounds`.

A nondegenerate range is returned unchanged. A constant range `(v, v)` has no
defined position for `v`, so mapping it through a categorical gradient indexes
with `nothing` and the renderer throws. Such a range is therefore widened
symmetrically around `v` by a relative half-width of `sqrt(eps())`, floored at
half a unit so that `v == 0` widens too, and clipped to `floatmax` so extreme
centers stay finite.

Only the plotting adapters widen. A [`ColorSpec`](@ref)'s own `colorrange`
keeps the exact `(v, v)` computed from the data.
"""
function displayrange(bounds::Tuple{Float64, Float64})
    low, high = bounds
    low < high && return bounds
    center = low
    halfwidth = max(abs(center) * sqrt(eps(one(center))), oneunit(center) / 2)
    limit = floatmax(center)
    return (max(center - halfwidth, -limit), min(center + halfwidth, limit))
end

"""
    makieattributes(spec::ColorSpec) -> (; plot, colorbar)

Makie keyword arguments for `spec`: `plot` for the plotting call and `colorbar`
for `Colorbar`. Defined by the Makie extension.
"""
function makieattributes end

"""
    plotsattributes(spec::ColorSpec) -> (; plot)

Plots keyword arguments for `spec`: `plot` for the plotting call, including its
colorbar ticks. Defined by the Plots extension.
"""
function plotsattributes end
