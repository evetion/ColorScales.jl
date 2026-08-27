"""
Graduated classes.

Class edges divide a color range into right-closed classes. The first class
includes the range's lower endpoint, `[a, b]`; later classes are `(a, b]`. A
single edge represents one constant class.
"""

"""
    ClassBreaks(edges; closed=:right)

Ordered, strictly increasing class edges together with generated interval
labels. Except for constant data, `k` classes have `k + 1` edges.

Only `closed=:right` is supported, matching QGIS graduated ranges and PlotUtils
categorical gradients.
"""
struct ClassBreaks
    edges::Vector{Float64}
    labels::Vector{String}
    closed::Symbol
    function ClassBreaks(edges::AbstractVector{<:Real}; closed = :right)
        closed === :right || throw(ArgumentError("only closed=:right is supported, got $(repr(closed))"))
        e = collect(Float64, edges)
        isempty(e) && throw(ArgumentError("class breaks need at least one edge"))
        all(isfinite, e) || throw(ArgumentError("class edges must be finite, got $e"))
        for i in firstindex(e):(lastindex(e) - 1)
            e[i] < e[i + 1] || throw(ArgumentError("class edges must be sorted and unique, got $e"))
        end
        return new(e, classlabels(e), closed)
    end
end

"""
    formatedge(x) -> String

Format one edge for a class label: integral values lose their decimal part and
other values keep six significant digits.
"""
function formatedge(x::Real)
    isinteger(x) && abs(x) < 1.0e15 && return string(Int(x))
    return string(round(Float64(x); sigdigits = 6))
end

function classlabels(edges::Vector{Float64})
    length(edges) == 1 && return ["[$(formatedge(edges[1])), $(formatedge(edges[1]))]"]
    labels = Vector{String}(undef, length(edges) - 1)
    for i in eachindex(labels)
        low, high = formatedge(edges[i]), formatedge(edges[i + 1])
        labels[i] = i == 1 ? "[$low, $high]" : "($low, $high]"
    end
    return labels
end

"""
    nclasses(classes::ClassBreaks) -> Int

Number of graduated classes.
"""
nclasses(classes::ClassBreaks) = max(length(classes.edges) - 1, 1)

"""
    classcenters(classes::ClassBreaks) -> Vector{Float64}

Midpoint of every class, used for colorbar ticks. A constant class centers on
its single edge.
"""
function classcenters(classes::ClassBreaks)
    e = classes.edges
    length(e) == 1 && return copy(e)
    return [(e[i] + e[i + 1]) / 2 for i in firstindex(e):(lastindex(e) - 1)]
end

"""
    classindex(classes::ClassBreaks, x) -> Int

Index of the class holding `x`. Values below or above the class edges saturate
on the first and last class, and a value exactly on an interior edge belongs to
the lower class.
"""
function classindex(classes::ClassBreaks, x::Real)
    return clamp(searchsortedfirst(classes.edges, x) - 1, 1, nclasses(classes))
end

"""
    ClassCountMethod

Supertype of the automatic class-count strategies. Counts are clamped to
`maxclasses` so a strategy cannot create an impractical gradient.
"""
abstract type ClassCountMethod end

"""
    Sturges(; maxclasses=256)

Sturges' rule, `ceil(log2(n)) + 1` classes for `n` observations.
"""
struct Sturges <: ClassCountMethod
    maxclasses::Int
    function Sturges(; maxclasses::Integer = 256)
        maxclasses >= 1 || throw(ArgumentError("maxclasses must be positive, got $maxclasses"))
        return new(Int(maxclasses))
    end
end

"""
    FreedmanDiaconis(; maxclasses=256)

Freedman-Diaconis' rule: class width `2 * IQR / cbrt(n)`, converted to a class
count over the selected color range. A zero interquartile range gives one class.
"""
struct FreedmanDiaconis <: ClassCountMethod
    maxclasses::Int
    function FreedmanDiaconis(; maxclasses::Integer = 256)
        maxclasses >= 1 || throw(ArgumentError("maxclasses must be positive, got $maxclasses"))
        return new(Int(maxclasses))
    end
end

"""
    checkcount(count)

Validate a requested class count: a positive `Integer` or a
[`ClassCountMethod`](@ref).
"""
function checkcount(count::Integer)
    count > 0 || throw(ArgumentError("class count must be positive, got $count"))
    return Int(count)
end

checkcount(count::ClassCountMethod) = count

function checkcount(count)
    throw(ArgumentError("class count must be a positive integer or a count strategy, got $(typeof(count))"))
end

datarequirement(::Int) = REQUIRE_NONE
datarequirement(::Sturges) = REQUIRE_SUMMARY
datarequirement(::FreedmanDiaconis) = REQUIRE_VALUES

"""
    resolvecount(count, obs, colorrange) -> Int

Resolve a requested class count against the observations and the selected color
range.
"""
resolvecount(count::Int, ::Any, ::Tuple{Float64, Float64}) = count

function resolvecount(method::Sturges, obs, ::Tuple{Float64, Float64})
    s = require_observations(summary_of(obs))
    return clamp(ceil(Int, log2(s.count)) + 1, 1, method.maxclasses)
end

function resolvecount(method::FreedmanDiaconis, obs, colorrange::Tuple{Float64, Float64})
    values = require_observations(values_of(obs))
    span = colorrange[2] - colorrange[1]
    iqr = quantile(values, 3 // 4; sorted = true) - quantile(values, 1 // 4; sorted = true)
    (iqr > 0 && span > 0) || return 1
    ratio = span / (2 * iqr / cbrt(length(values)))
    ratio >= method.maxclasses && return method.maxclasses
    return max(ceil(Int, ratio), 1)
end
