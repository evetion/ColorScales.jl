"""
Range-based class breaks.

These methods place class edges from the selected color range alone. The color
range remains authoritative: the first and last edge always equal its endpoints.
"""

"""
    BreakMethod

Supertype of the class-break methods consumed by [`breaks`](@ref).
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
    stepinteriors(low, high, step) -> Vector{Float64}

Multiples of `step` strictly inside `(low, high)`.
"""
function stepinteriors(low::Float64, high::Float64, step::Float64)
    lowest = floor(low / step) + 1
    highest = ceil(high / step) - 1
    interiors = Float64[]
    highest < lowest && return interiors
    for i in Int(lowest):Int(highest)
        value = i * step
        low < value < high && push!(interiors, value)
    end
    return interiors
end

"""
    prettyedges(low, high, count) -> Vector{Float64}

Class edges keeping the exact color-range endpoints and using interior
multiples of one nice step. Of the two nice steps bracketing `span / count`,
the one whose class count is closest to the target wins; ties prefer the
coarser step.
"""
function prettyedges(low::Float64, high::Float64, count::Int)
    high <= low && return [low]
    down, up = nicebracket((high - low) / count)
    chosen = Float64[]
    score = typemax(Int)
    for step in (up, down)
        interiors = stepinteriors(low, high, step)
        candidate = abs(length(interiors) + 1 - count)
        if candidate < score
            score = candidate
            chosen = interiors
        end
    end
    return dedupe([low; chosen; high])
end

"""
    EqualInterval(count)

Classes of equal width over the color range.
"""
struct EqualInterval{C} <: BreakMethod
    count::C
    function EqualInterval(count)
        c = checkcount(count)
        return new{typeof(c)}(c)
    end
end

"""
    Pretty(count=7)

Classes whose interior edges are readable multiples of `{1, 2, 5} * 10^n`. The
count is a target, so the result may hold a nearby number of classes.
"""
struct Pretty{C} <: BreakMethod
    count::C
    function Pretty(count = 7)
        c = checkcount(count)
        return new{typeof(c)}(c)
    end
end

"""
    FixedInterval(width)

Classes of the given width starting at the color range's lower endpoint. The
final class is shorter when the width does not divide the range.
"""
struct FixedInterval <: BreakMethod
    width::Float64
    function FixedInterval(width::Real)
        w = Float64(width)
        (isfinite(w) && w > 0) || throw(ArgumentError("FixedInterval needs a positive finite width, got $width"))
        return new(w)
    end
end

"""
    Geometric(count)

Logarithmically spaced classes in original data units. The color range must be
strictly positive. This method does not set a plotting library's color
transform.
"""
struct Geometric{C} <: BreakMethod
    count::C
    function Geometric(count)
        c = checkcount(count)
        return new{typeof(c)}(c)
    end
end

datarequirement(m::EqualInterval) = datarequirement(m.count)
datarequirement(m::Pretty) = datarequirement(m.count)
datarequirement(m::Geometric) = datarequirement(m.count)
datarequirement(::FixedInterval) = REQUIRE_NONE

function breakedges(obs, method::EqualInterval, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    count = resolvecount(method.count, obs, colorrange)
    return collect(range(low, high; length = count + 1))
end

function breakedges(obs, method::Pretty, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    return prettyedges(low, high, resolvecount(method.count, obs, colorrange))
end

function breakedges(::Any, method::FixedInterval, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    ratio = (high - low) / method.width
    ratio > 1.0e6 && throw(ArgumentError("FixedInterval($(method.width)) would create more than a million classes over ($low, $high)"))
    edges = [low + i * method.width for i in 0:floor(Int, ratio)]
    edges[end] < high ? push!(edges, high) : (edges[end] = high)
    return dedupe(edges)
end

function breakedges(obs, method::Geometric, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low > 0 || throw(ArgumentError("Geometric breaks need a strictly positive color range, got ($low, $high)"))
    low == high && return [low]
    count = resolvecount(method.count, obs, colorrange)
    edges = exp.(range(log(low), log(high); length = count + 1))
    edges[begin] = low
    edges[end] = high
    return dedupe(edges)
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
