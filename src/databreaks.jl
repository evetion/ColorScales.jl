"""
Data-based class breaks.

These methods first let the color range fall out of every usable observation and
then place their edges using only the observations inside that inclusive range,
so values outside the range cannot move a class boundary.
"""

"""
    Quantile(count)

Classes holding an equal share of the observations inside the color range,
placed with type-7 linear interpolation. Tied observations remove duplicate
edges, which can lower the actual class count.
"""
struct Quantile <: BreakMethod
    count::Int
    Quantile(count) = new(checkcount(count))
end

datarequirement(::Quantile) = REQUIRE_VALUES

function breakedges(obs, method::Quantile, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    selected = inrange(require_observations(values_of(obs)), colorrange)
    count = method.count
    interiors = [quantile7(selected, i, count) for i in 1:(count - 1)]
    return spanedges(interiors, low, high)
end
