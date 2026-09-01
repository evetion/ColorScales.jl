"""
Range-based class breaks.

These methods place class edges from the selected color range alone.
[`EqualInterval`](@ref) and [`Quantile`](@ref) keep the color range
authoritative: their first and last edge always equal its endpoints.
[`Pretty`](@ref) is the one exception: it may widen the range outward to nice
bounds, and the widened bounds become the color range downstream.
"""

"""
    BreakMethod

Supertype of the class-break methods consumed by [`breaks`](@ref). Every
method is callable, so `EqualInterval(4)(z)` is shorthand for
`breaks(z, EqualInterval(4))`.
"""
abstract type BreakMethod end

"""
    dedupe(edges) -> Vector{Float64}

Sort edges and drop tied duplicates, which can lower the actual class count.
"""
function dedupe(edges::AbstractVector{Float64})
    sorted = sort(edges)
    unique = Float64[]
    for e in sorted
        (isempty(unique) || e > unique[end]) && push!(unique, e)
    end
    return unique
end

"""
    spanedges(interiors, low, high) -> Vector{Float64}

Class edges that begin exactly at `low` and end exactly at `high`.

Only interior edges strictly inside the color range survive, and tied edges are
dropped. Generated edges that collapse at the floating-point resolution
therefore lower the class count instead of producing an invalid sequence.
"""
function spanedges(interiors, low::Float64, high::Float64)
    edges = Float64[low]
    for e in interiors
        low < e < high && push!(edges, e)
    end
    push!(edges, high)
    return dedupe(edges)
end

const NICE_FRACTIONS = (1.0, 2.0, 5.0, 10.0)

"""
    nicebracket(x) -> Tuple{Float64,Float64}

The largest nice step not above `x` and the smallest nice step not below it,
where a nice step is `{1, 2, 5} * 10^n`.
"""
function nicebracket(x::Float64)
    decade = exp10(floor(log10(x)))
    fraction = x / decade
    lower = NICE_FRACTIONS[1]
    upper = NICE_FRACTIONS[end]
    for nice in NICE_FRACTIONS
        nice <= fraction && (lower = nice)
    end
    for nice in Iterators.reverse(NICE_FRACTIONS)
        nice >= fraction && (upper = nice)
    end
    return (lower * decade, upper * decade)
end

"""
    niceedges(low, high, step) -> Vector{Float64}

Multiples of `step` from the largest one not above `low` to the smallest one
not below `high`, i.e. `low` and `high` widened outward to the nearest
multiples of `step`.
"""
function niceedges(low::Float64, high::Float64, step::Float64)
    lowest = floor(low / step)
    highest = ceil(high / step)
    return [i * step for i in Int(lowest):Int(highest)]
end

"""
    prettyedges(low, high, count) -> Vector{Float64}

Class edges on multiples of one nice step, widening `low` and `high` outward
to the nearest such multiple. Of the two nice steps bracketing `span / count`,
the one whose resulting class count is closest to the target wins; ties
prefer the coarser step.
"""
function prettyedges(low::Float64, high::Float64, count::Int)
    high <= low && return [low]
    down, up = nicebracket((high - low) / count)
    chosen = Float64[]
    score = typemax(Int)
    for step in (up, down)
        edges = niceedges(low, high, step)
        candidate = abs(length(edges) - 1 - count)
        if candidate < score
            score = candidate
            chosen = edges
        end
    end
    return dedupe(chosen)
end

"""
    EqualInterval(count)

Classes of equal width over the color range. Edges that coincide at the
floating-point resolution collapse, so a span too narrow for `count` distinct
edges yields fewer classes rather than an error.
"""
struct EqualInterval <: BreakMethod
    count::Int
    EqualInterval(count) = new(checkcount(count))
end

"""
    Pretty(count=7)

Classes whose edges are readable multiples of `{1, 2, 5} * 10^n`. The count is
a target, so the result may hold a nearby number of classes. Unlike
[`EqualInterval`](@ref) and [`Quantile`](@ref), `Pretty` may widen the color
range outward so its outer edges are nice too, not just its interior ones.
"""
struct Pretty <: BreakMethod
    count::Int
    Pretty(count = 7) = new(checkcount(count))
end

datarequirement(::EqualInterval) = REQUIRE_NONE
datarequirement(::Pretty) = REQUIRE_NONE

function breakedges(::Any, method::EqualInterval, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    count = method.count
    grid = range(low, high; length = count + 1)
    return spanedges(view(grid, 2:count), low, high)
end

function breakedges(::Any, method::Pretty, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    return prettyedges(low, high, method.count)
end

"""
    breaks(data, method; colorrange=Extrema(), invalid=:skip) -> ClassBreaks

Compute graduated class edges for `data`.

`colorrange` accepts a [`ColorRangeMethod`](@ref) or an explicit `(low, high)`
pair, and is computed from every usable observation. Data-dependent methods then
place their edges using only the observations inside that inclusive range. Tied
edges are removed, so the actual class count can be lower than requested, and
constant data collapses to one class.

```jldoctest
julia> breaks(0:10, EqualInterval(2)).edges
3-element Vector{Float64}:
  0.0
  5.0
 10.0
```
"""
function breaks(data, method::BreakMethod; colorrange = Extrema(), invalid = :skip)
    policy = check_invalid(invalid)
    selected = rangemethod(colorrange)
    requirement = max(datarequirement(selected), datarequirement(method))
    obs = observe(data, requirement; invalid = policy)
    return ClassBreaks(breakedges(obs, method, rangefrom(obs, selected)))
end

(method::BreakMethod)(data; colorrange = Extrema(), invalid = :skip) =
    breaks(data, method; colorrange = colorrange, invalid = invalid)
