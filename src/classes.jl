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
        e = checkedges(edges)
        return new(e, classlabels(e), closed)
    end
end

"""
    checkedges(edges) -> Vector{Float64}

Validate class edges: at least one, all finite, and strictly increasing.
"""
function checkedges(edges)
    e = collect(Float64, edges)
    isempty(e) && throw(ArgumentError("class breaks need at least one edge"))
    all(isfinite, e) || throw(ArgumentError("class edges must be finite, got $e"))
    for i in firstindex(e):(lastindex(e) - 1)
        e[i] < e[i + 1] || throw(ArgumentError("class edges must be sorted and unique, got $e"))
    end
    return e
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
    checkcount(count) -> Int

Validate a requested class count: a positive `Integer`.
"""
function checkcount(count::Integer)
    count > 0 || throw(ArgumentError("class count must be positive, got $count"))
    return Int(count)
end

function checkcount(count)
    throw(ArgumentError("class count must be a positive integer, got $(typeof(count))"))
end
