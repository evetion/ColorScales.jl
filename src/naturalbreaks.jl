"""
Natural breaks.

An independently implemented weighted Fisher-Jenks dynamic program. Repeated
observations are compressed to unique values and counts before optimization, and
class edges are midpoints between adjacent optimized classes, so distinct point
masses stay in separate classes under right-closed edge semantics.

The dynamic program costs `O(count * n^2)` in the number of unique values, which
is why exact work is bounded by `max_unique`.
"""

"""
    RandomSample(size, rng=Random.default_rng())

Explicit sampling policy for natural breaks above `max_unique` unique values.
The generator is copied before use, so a method used twice gives the same
result.
"""
struct RandomSample
    size::Int
    rng::AbstractRNG
    function RandomSample(size::Integer, rng::AbstractRNG = Random.default_rng())
        size > 0 || throw(ArgumentError("sample size must be positive, got $size"))
        return new(Int(size), rng)
    end
end

"""
    NaturalBreaks(count; max_unique=3000, sampling=nothing)

Fisher-Jenks classes minimizing the within-class sum of squared deviations.

Inputs with more than `max_unique` unique in-range values raise an
`ArgumentError` unless the caller supplies a [`RandomSample`](@ref) policy.
ColorScales never samples silently.
"""
struct NaturalBreaks{C} <: BreakMethod
    count::C
    max_unique::Int
    sampling::Union{Nothing, RandomSample}
    function NaturalBreaks(count; max_unique::Integer = 3000, sampling::Union{Nothing, RandomSample} = nothing)
        c = checkcount(count)
        max_unique >= 1 || throw(ArgumentError("max_unique must be positive, got $max_unique"))
        return new{typeof(c)}(c, Int(max_unique), sampling)
    end
end

datarequirement(::NaturalBreaks) = REQUIRE_VALUES

"""
    compress(values) -> (uniques, weights)

Compress sorted observations into unique values and their counts.
"""
function compress(values::AbstractVector{Float64})
    uniques = Float64[]
    weights = Float64[]
    for v in values
        if !isempty(uniques) && v == uniques[end]
            weights[end] += 1
        else
            push!(uniques, v)
            push!(weights, 1.0)
        end
    end
    return (uniques, weights)
end

"""
    drawsample(values, policy::RandomSample) -> Vector{Float64}

Draw a sorted sample without replacement, leaving the policy's generator
untouched.
"""
function drawsample(values::AbstractVector{Float64}, policy::RandomSample)
    policy.size >= length(values) && return collect(values)
    rng = copy(policy.rng)
    indices = randperm(rng, length(values))[1:policy.size]
    return sort!(values[indices])
end

"""
    fisherjenks(uniques, weights, count) -> Vector{Int}

Start index of every optimal class, minimizing the weighted within-class sum of
squared deviations.
"""
function fisherjenks(uniques::Vector{Float64}, weights::Vector{Float64}, count::Int)
    n = length(uniques)
    count >= n && return collect(1:n)
    starts = Matrix{Int}(undef, count, n)
    previous = Vector{Float64}(undef, n)
    weight = 0.0
    average = 0.0
    sse = 0.0
    for b in 1:n
        weight += weights[b]
        delta = uniques[b] - average
        average += delta * weights[b] / weight
        sse += weights[b] * delta * (uniques[b] - average)
        previous[b] = sse
        starts[1, b] = 1
    end
    current = Vector{Float64}(undef, n)
    for class in 2:count
        fill!(current, Inf)
        for a in class:n
            base = previous[a - 1]
            weight = 0.0
            average = 0.0
            sse = 0.0
            for b in a:n
                weight += weights[b]
                delta = uniques[b] - average
                average += delta * weights[b] / weight
                sse += weights[b] * delta * (uniques[b] - average)
                total = base + sse
                if total < current[b]
                    current[b] = total
                    starts[class, b] = a
                end
            end
        end
        previous, current = current, previous
    end
    bounds = Vector{Int}(undef, count)
    b = n
    for class in count:-1:1
        bounds[class] = starts[class, b]
        b = bounds[class] - 1
    end
    return bounds
end

function breakedges(obs, method::NaturalBreaks, colorrange::Tuple{Float64, Float64})
    low, high = colorrange
    low == high && return [low]
    selected = inrange(require_observations(values_of(obs)), colorrange)
    uniques, weights = compress(selected)
    if length(uniques) > method.max_unique
        method.sampling === nothing && throw(
            ArgumentError(
                "natural breaks over $(length(uniques)) unique values exceed max_unique=$(method.max_unique); " *
                    "supply sampling=RandomSample(size, rng) to sample explicitly"
            )
        )
        uniques, weights = compress(drawsample(selected, method.sampling))
        length(uniques) > method.max_unique && throw(
            ArgumentError(
                "the random sample still holds $(length(uniques)) unique values, above max_unique=$(method.max_unique)"
            )
        )
    end
    count = min(resolvecount(method.count, obs, colorrange), length(uniques))
    bounds = fisherjenks(uniques, weights, count)
    edges = Vector{Float64}(undef, count + 1)
    edges[begin] = low
    for class in 2:count
        start = bounds[class]
        edges[class] = (uniques[start - 1] + uniques[start]) / 2
    end
    edges[end] = high
    return dedupe(edges)
end
