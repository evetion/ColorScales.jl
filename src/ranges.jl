"""
Color-range methods.

A color range is the closed numeric span `(low, high)` mapped onto a colormap.
Range selection is independent of class-break selection.
"""

"""
    ColorRangeMethod

Supertype of the callable color-range methods. Every method is a `Function`, so
`Percentile(2, 98)(z)` is shorthand for `colorrange(z, Percentile(2, 98))`.
"""
abstract type ColorRangeMethod <: Function end

"""
    Extrema()

Color range spanning the smallest and largest usable observation.
"""
struct Extrema <: ColorRangeMethod end

"""
    Percentile(low, high)

Color range between two percentiles on the inclusive `0` to `100` scale, using
type-7 linear interpolation, the convention of `Statistics.quantile` and QGIS.
"""
struct Percentile <: ColorRangeMethod
    low::Float64
    high::Float64
    function Percentile(low::Real, high::Real)
        l, h = Float64(low), Float64(high)
        (isfinite(l) && isfinite(h)) || throw(ArgumentError("percentile bounds must be finite, got ($low, $high)"))
        (0 <= l && h <= 100) || throw(ArgumentError("percentile bounds must lie in 0..100, got ($low, $high)"))
        l <= h || throw(ArgumentError("percentile bounds must be ordered, got ($low, $high)"))
        return new(l, h)
    end
end

"""
    MeanStd(n=2; corrected=true)

Color range `mean ± n * std`. `corrected=false` uses the population standard
deviation. The interval is not clamped to the observed extrema.
"""
struct MeanStd <: ColorRangeMethod
    n::Float64
    corrected::Bool
    function MeanStd(n::Real = 2; corrected::Bool = true)
        v = Float64(n)
        (isfinite(v) && v > 0) || throw(ArgumentError("MeanStd requires a positive finite multiplier, got $n"))
        return new(v, corrected)
    end
end

"""
    FixedRange(low, high)

Color range supplied by the caller. It never inspects the observations.
"""
struct FixedRange <: ColorRangeMethod
    low::Float64
    high::Float64
    function FixedRange(low::Real, high::Real)
        l, h = Float64(low), Float64(high)
        (isfinite(l) && isfinite(h)) || throw(ArgumentError("fixed color range must be finite, got ($low, $high)"))
        l <= h || throw(ArgumentError("fixed color range must have low <= high, got ($low, $high)"))
        return new(l, h)
    end
end

"""
    SymmetricRange(method=Extrema(); center=0)

Widen `method`'s range to the interval of equal width on both sides of `center`.
"""
struct SymmetricRange{M <: ColorRangeMethod} <: ColorRangeMethod
    method::M
    center::Float64
    function SymmetricRange(method::M = Extrema(); center::Real = 0) where {M <: ColorRangeMethod}
        c = Float64(center)
        isfinite(c) || throw(ArgumentError("symmetric center must be finite, got $center"))
        return new{M}(method, c)
    end
end

datarequirement(::Extrema) = REQUIRE_SUMMARY
datarequirement(::Percentile) = REQUIRE_VALUES
datarequirement(::MeanStd) = REQUIRE_SUMMARY
datarequirement(::FixedRange) = REQUIRE_NONE
datarequirement(m::SymmetricRange) = datarequirement(m.method)
datarequirement(::Tuple{Float64, Float64}) = REQUIRE_NONE

"""
    checkrange(bounds) -> Tuple{Float64,Float64}

Validate an explicit `(low, high)` color range.
"""
function checkrange(bounds)
    length(bounds) == 2 || throw(ArgumentError("a color range needs exactly two values, got $(length(bounds))"))
    low, high = Float64(first(bounds)), Float64(last(bounds))
    (isfinite(low) && isfinite(high)) || throw(ArgumentError("color range must be finite, got ($low, $high)"))
    low <= high || throw(ArgumentError("color range must have low <= high, got ($low, $high)"))
    return (low, high)
end

rangemethod(method::ColorRangeMethod) = method
rangemethod(bounds::Tuple) = checkrange(bounds)
rangemethod(bounds::AbstractVector) = checkrange(bounds)
function rangemethod(x)
    throw(ArgumentError("colorrange must be a ColorRangeMethod or a (low, high) pair, got $(typeof(x))"))
end

rangefrom(::Any, bounds::Tuple{Float64, Float64}) = bounds

function rangefrom(obs, ::Extrema)
    s = require_observations(summary_of(obs))
    return (s.minimum, s.maximum)
end

function rangefrom(obs, m::Percentile)
    values = require_observations(values_of(obs))
    low = quantile7(values, m.low, 100)
    high = quantile7(values, m.high, 100)
    return (low, high)
end

function rangefrom(obs, m::MeanStd)
    s = require_observations(summary_of(obs))
    spread = m.n * stddev(s; corrected = m.corrected)
    return (s.mean - spread, s.mean + spread)
end

rangefrom(::Any, m::FixedRange) = (m.low, m.high)

function rangefrom(obs, m::SymmetricRange)
    low, high = rangefrom(obs, m.method)
    radius = max(abs(low - m.center), abs(high - m.center))
    return (m.center - radius, m.center + radius)
end

"""
    colorrange(data, method=Extrema(); invalid=:skip) -> Tuple{Float64,Float64}

Compute the color range of `data` with `method`.

`invalid=:skip` ignores `missing` and non-finite observations; `invalid=:error`
rejects them. Methods that need observations raise an `ArgumentError` when none
remain.

```jldoctest
julia> colorrange([1.0, missing, 9.0], Percentile(0, 100))
(1.0, 9.0)
```
"""
function colorrange(data, method::ColorRangeMethod = Extrema(); invalid = :skip)
    policy = check_invalid(invalid)
    obs = observe(data, datarequirement(method); invalid = policy)
    return rangefrom(obs, method)
end

(method::ColorRangeMethod)(data; invalid = :skip) = colorrange(data, method; invalid = invalid)
