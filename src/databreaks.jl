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
struct Quantile{C} <: BreakMethod
    count::C
    function Quantile(count)
        c = checkcount(count)
        return new{typeof(c)}(c)
    end
end

"""
    StdDev(count=7; corrected=true)

Classes centered on the mean of the in-range observations. Edges are pretty
values in standard-deviation units, clipped to the color range and mapped back
to original units. `corrected=false` uses the population standard deviation.
"""
struct StdDev{C} <: BreakMethod
    count::C
    corrected::Bool
    function StdDev(count = 7; corrected::Bool = true)
        c = checkcount(count)
        return new{typeof(c)}(c, corrected)
    end
end

datarequirement(::Quantile) = REQUIRE_VALUES
datarequirement(::StdDev) = REQUIRE_VALUES

function breakedges(obs, method::Quantile, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    selected = inrange(require_observations(values_of(obs)), colorrange)
    count = resolvecount(method.count, obs, colorrange)
    interiors = [quantile7(selected, i, count) for i in 1:(count - 1)]
    return spanedges(interiors, low, high)
end

function breakedges(obs, method::StdDev, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    selected = inrange(require_observations(values_of(obs)), colorrange)
    moments = summarize_values(selected)
    spread = stddev(moments; corrected = method.corrected)
    spread == 0 && return [low, high]
    count = resolvecount(method.count, obs, colorrange)
    zedges = prettyedges((low - moments.mean) / spread, (high - moments.mean) / spread, count)
    interiors = [moments.mean + z * spread for z in view(zedges, 2:(length(zedges) - 1))]
    return spanedges(interiors, low, high)
end
