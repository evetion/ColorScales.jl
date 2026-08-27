"""
Input handling shared by every range and break method.

Observations arrive as an arbitrary finite iterable of real values and optional
`missing`. Methods declare how much of the input they need, so data-independent
methods never touch the iterable, streaming methods consume it once, and only
order statistics force collection.
"""

const _INVALID_POLICIES = (:skip, :error)

"""
    check_invalid(invalid) -> Symbol

Validate an invalid-observation policy. `:skip` ignores `missing` and
non-finite values; `:error` rejects them.
"""
function check_invalid(invalid)
    if invalid isa Symbol && invalid in _INVALID_POLICIES
        return invalid::Symbol
    end
    throw(ArgumentError("invalid must be :skip or :error, got $(repr(invalid))"))
end

const REQUIRE_NONE = 0
const REQUIRE_SUMMARY = 1
const REQUIRE_VALUES = 2

"""
    observation(x, invalid) -> Union{Float64,Nothing}

Convert one input element to a usable observation, `nothing` when it is skipped.
Non-numeric elements are always rejected.
"""
function observation(x, invalid::Symbol)
    if x === missing
        invalid === :error && throw(ArgumentError("missing observation rejected by invalid=:error"))
        return nothing
    elseif x isa Real
        v = Float64(x)
        isfinite(v) && return v
        invalid === :error && throw(ArgumentError("non-finite observation $x rejected by invalid=:error"))
        return nothing
    end
    throw(ArgumentError("expected real or missing observations, got $(typeof(x))"))
end

"""
    DataSummary

Online count, extrema, mean, and sum of squared deviations (`m2`) of the usable
observations.
"""
struct DataSummary
    count::Int
    minimum::Float64
    maximum::Float64
    mean::Float64
    m2::Float64
end

DataSummary() = DataSummary(0, Inf, -Inf, 0.0, 0.0)

function update(s::DataSummary, x::Float64)
    count = s.count + 1
    delta = x - s.mean
    mean = s.mean + delta / count
    m2 = s.m2 + delta * (x - mean)
    return DataSummary(count, min(s.minimum, x), max(s.maximum, x), mean, m2)
end

"""
    summarize(data; invalid=:skip) -> DataSummary

Summarize an iterable in one pass without collecting it.
"""
function summarize(data; invalid::Symbol = :skip)
    s = DataSummary()
    for x in data
        v = observation(x, invalid)
        v === nothing || (s = update(s, v))
    end
    return s
end

"""
    summarize_values(values) -> DataSummary

Summarize already validated observations.
"""
function summarize_values(values::AbstractVector{Float64})
    s = DataSummary()
    for v in values
        s = update(s, v)
    end
    return s
end

"""
    collect_values(data; invalid=:skip) -> Vector{Float64}

Collect the usable observations once, sorted so order statistics are cheap.
"""
function collect_values(data; invalid::Symbol = :skip)
    values = Float64[]
    for x in data
        v = observation(x, invalid)
        v === nothing || push!(values, v)
    end
    sort!(values)
    return values
end

"""
    observe(data, requirement; invalid=:skip)

Consume `data` exactly as much as `requirement` demands.
"""
function observe(data, requirement::Int; invalid::Symbol = :skip)
    requirement == REQUIRE_NONE && return nothing
    requirement == REQUIRE_SUMMARY && return summarize(data; invalid = invalid)
    return collect_values(data; invalid = invalid)
end

summary_of(s::DataSummary) = s
summary_of(values::AbstractVector{Float64}) = summarize_values(values)
summary_of(::Nothing) = error("internal error: no observations were requested")

values_of(values::AbstractVector{Float64}) = values
values_of(::DataSummary) = error("internal error: observations were summarized, not collected")
values_of(::Nothing) = error("internal error: no observations were requested")

"""
    require_observations(s::DataSummary)

Raise when a method that needs data received none.
"""
function require_observations(s::DataSummary)
    s.count == 0 && throw(ArgumentError("no usable observations; the selected method requires data"))
    return s
end

function require_observations(values::AbstractVector{Float64})
    isempty(values) && throw(ArgumentError("no usable observations; the selected method requires data"))
    return values
end

"""
    stddev(s::DataSummary; corrected=true)

Standard deviation of the summarized observations. Fewer than two observations
and constant observations both give `0.0`.
"""
function stddev(s::DataSummary; corrected::Bool = true)
    s.count == 0 && return 0.0
    denominator = corrected ? s.count - 1 : s.count
    denominator <= 0 && return 0.0
    return sqrt(max(s.m2, 0.0) / denominator)
end
