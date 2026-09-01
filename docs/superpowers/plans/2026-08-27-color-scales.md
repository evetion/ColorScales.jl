# ColorScales.jl Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Julia package that computes robust color ranges and graduated class breaks, emits PlotUtils gradients, and adapts one result to Makie and Plots.

**Architecture:** Keep numerical range and break algorithms in the core package, with PlotUtils as the shared gradient representation. Represent graduated results as `ClassBreaks` and complete mappings as `ColorSpec`; package extensions translate those values into Makie, Plots, Distributions, and CategoricalArrays interfaces without recomputing statistics.

**Tech Stack:** Julia 1.10, Statistics, Random, PlotUtils, package extensions, Test, Makie, Plots, Distributions, CategoricalArrays.

---

## File map

| Path | Responsibility |
|---|---|
| `Project.toml` | Package identity, compatibility, weak dependencies, extensions, and test target |
| `src/ColorScales.jl` | Module entry point, exports, includes, and extension function declarations |
| `src/input.jl` | Invalid-value policy, finite-value iteration, collection, and online summaries |
| `src/ranges.jl` | Callable color-range method types and `colorrange` |
| `src/classes.jl` | `ClassBreaks`, interval labels, class centers, class lookup, and automatic count rules |
| `src/breaks/range_based.jl` | Equal-interval, pretty, fixed-interval, and geometric breaks |
| `src/breaks/data_based.jl` | Quantile and standard-deviation breaks |
| `src/breaks/natural.jl` | Weighted Fisher-Jenks optimization and explicit sampling |
| `src/spec.jl` | `ColorSpec`, `classgradient`, `colorspec`, and backend adapter declarations |
| `src/public_docs.jl` | Docstrings for the compact exported interface |
| `ext/ColorScalesMakieExt.jl` | Makie plot and Colorbar attribute bundles |
| `ext/ColorScalesPlotsExt.jl` | Plots attributes, including colorbar ticks |
| `ext/ColorScalesDistributionsExt.jl` | Ranges and equal-probability breaks from a supplied distribution |
| `ext/ColorScalesCategoricalArraysExt.jl` | Ordered categorical assignment with right-closed classes |
| `test/runtests.jl` | Test-suite entry point |
| `test/ranges.jl` | Range methods and invalid-input behavior |
| `test/classes.jl` | Class representation, labels, centers, and automatic counts |
| `test/range_based_breaks.jl` | Deterministic range-based break methods |
| `test/data_based_breaks.jl` | Quantile and standard-deviation methods |
| `test/natural_breaks.jl` | Fisher-Jenks objective, compression, limits, and reproducibility |
| `test/spec.jl` | PlotUtils gradient and composed specification behavior |
| `test/extensions.jl` | Makie, Plots, Distributions, and CategoricalArrays integration |
| `README.md` | Installation, concepts, examples, semantics, and limitations |
| `LICENSE` | MIT license |
| `.github/workflows/CI.yml` | Julia 1.10 and current stable test matrix |

## Task 1: Scaffold the package

**Files:**
- Create: `Project.toml`
- Create: `src/ColorScales.jl`
- Create: `test/runtests.jl`
- Create: `LICENSE`
- Create: `.gitignore`

- [ ] **Step 1: Write the package-loading test**

Create `test/runtests.jl`:

```julia
using Test
using ColorScales

@testset "ColorScales" begin
    @test nameof(ColorScales) === :ColorScales
end
```

- [ ] **Step 2: Run the test to verify package metadata is absent**

Run with `julia-julia_eval`, using
`env_path="/Users/evetion/projects/makiecolors"`:

```julia
using Pkg
Pkg.test()
```

Expected: failure because `Project.toml` does not define `ColorScales`.

- [ ] **Step 3: Create package metadata and the module**

Create `Project.toml`:

```toml
name = "ColorScales"
uuid = "31aba9d7-1b70-4d4a-aefa-a818fd040592"
authors = ["ColorScales contributors"]
version = "0.1.0"

[deps]
PlotUtils = "995b91a9-d308-5afd-9ec6-746e21dbc043"
Random = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[weakdeps]
CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"

[extensions]
ColorScalesCategoricalArraysExt = "CategoricalArrays"
ColorScalesDistributionsExt = "Distributions"
ColorScalesMakieExt = "Makie"
ColorScalesPlotsExt = "Plots"

[compat]
CategoricalArrays = "1"
Distributions = "0.25"
Makie = "0.24"
PlotUtils = "1"
Plots = "1"
julia = "1.10"

[extras]
CategoricalArrays = "324d7699-5711-5eae-9e2f-1d82baa6b597"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[targets]
test = ["CategoricalArrays", "Distributions", "Makie", "Plots", "Test"]
```

Create `src/ColorScales.jl`:

```julia
module ColorScales

using PlotUtils
using Random
using Statistics

end
```

Create `.gitignore`:

```gitignore
Manifest.toml
coverage/
*.cov
*.mem
```

Create `LICENSE` with the standard MIT license text and the copyright line:

```text
MIT License

Copyright (c) 2026 ColorScales contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Resolve dependencies and run the loading test**

Run with `julia-julia_eval`, using the package environment:

```julia
using Pkg
Pkg.resolve()
Pkg.test()
```

Expected: the `ColorScales` testset passes.

- [ ] **Step 5: Commit the scaffold**

```bash
git add Project.toml src/ColorScales.jl test/runtests.jl LICENSE .gitignore
git commit -m "chore: scaffold ColorScales package" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 2: Implement input handling and color ranges

**Files:**
- Create: `src/input.jl`
- Create: `src/ranges.jl`
- Create: `test/ranges.jl`
- Modify: `src/ColorScales.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing range tests**

Create `test/ranges.jl`:

```julia
using Test
using ColorScales

@testset "color ranges" begin
    x = Union{Missing, Float64}[missing, -Inf, 0, 1, 2, 3, 100, NaN]

    @test colorrange(x, Extrema()) == (0.0, 100.0)
    @test colorrange(x, Percentile(0, 100)) == (0.0, 100.0)
    @test colorrange(0:100, Percentile(2, 98)) == (2.0, 98.0)
    @test Percentile(2, 98)(0:100) == (2.0, 98.0)
    @test colorrange([1, 2, 3], MeanStd(1; corrected=false)) ≈
        (2 - sqrt(2 / 3), 2 + sqrt(2 / 3))
    @test colorrange([1, 2, 3], MeanStd(1; corrected=true)) ≈ (1.0, 3.0)
    @test colorrange(Int[], FixedRange(-1, 1)) == (-1, 1)
    @test colorrange([-2, 1], Symmetric(Extrema(); center=0)) == (-2.0, 2.0)
    @test colorrange([5], MeanStd(2)) == (5.0, 5.0)

    @test_throws ArgumentError colorrange([1, NaN], Extrema(); invalid=:error)
    @test_throws ArgumentError colorrange([missing, NaN], Extrema())
    @test_throws ArgumentError colorrange(["not numeric"], Extrema())
    @test_throws ArgumentError Percentile(98, 2)
    @test_throws ArgumentError Percentile(-1, 98)
    @test_throws ArgumentError MeanStd(-1)
    @test_throws ArgumentError FixedRange(2, 1)
end
```

Append to `test/runtests.jl`:

```julia
include("ranges.jl")
```

- [ ] **Step 2: Run the range tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales
include("test/ranges.jl")
```

Expected: failure because `Extrema`, `Percentile`, and `colorrange` are
undefined.

- [ ] **Step 3: Implement finite-value iteration and online summaries**

Create `src/input.jl`:

```julia
const INVALID_POLICIES = (:skip, :error)

function _check_invalid_policy(invalid::Symbol)
    invalid in INVALID_POLICIES ||
        throw(ArgumentError("invalid must be :skip or :error, got :$invalid"))
    return invalid
end

function _foreach_valid(f, data, invalid::Symbol)
    _check_invalid_policy(invalid)
    n = 0
    for raw in data
        if ismissing(raw)
            invalid === :error &&
                throw(ArgumentError("input contains missing"))
        elseif !(raw isa Real)
            throw(ArgumentError("input values must be real numbers or missing"))
        elseif !isfinite(raw)
            invalid === :error &&
                throw(ArgumentError("input contains non-finite value $raw"))
        else
            f(float(raw))
            n += 1
        end
    end
    return n
end

function _collect_valid(data; invalid::Symbol=:skip)
    raw_values = Real[]
    _foreach_valid(data, invalid) do value
        push!(raw_values, value)
    end
    isempty(raw_values) &&
        throw(ArgumentError("input contains no finite observations"))
    T = foldl(promote_type, (typeof(value) for value in raw_values))
    return T[value for value in raw_values]
end

function _summary(data; invalid::Symbol=:skip)
    n = 0
    lo = nothing
    hi = nothing
    avg = nothing
    m2 = nothing

    _foreach_valid(data, invalid) do value
        n += 1
        if n == 1
            lo = hi = avg = value
            m2 = zero(value)
        else
            lo = min(lo, value)
            hi = max(hi, value)
            delta = value - avg
            avg += delta / n
            m2 += delta * (value - avg)
        end
    end

    n == 0 && throw(ArgumentError("input contains no finite observations"))
    return (; n, lo, hi, mean=avg, m2)
end
```

- [ ] **Step 4: Implement callable range methods**

Create `src/ranges.jl`:

```julia
abstract type ColorRangeMethod <: Function end

struct Extrema <: ColorRangeMethod end

struct Percentile{T<:Real} <: ColorRangeMethod
    low::T
    high::T
    function Percentile(low::T, high::T) where {T<:Real}
        0 <= low <= high <= 100 ||
            throw(ArgumentError("percentiles must satisfy 0 <= low <= high <= 100"))
        return new{T}(low, high)
    end
end

Percentile(low::Real, high::Real) = Percentile(promote(low, high)...)

struct MeanStd{T<:Real} <: ColorRangeMethod
    n::T
    corrected::Bool
    function MeanStd(n::T; corrected::Bool=true) where {T<:Real}
        n >= 0 || throw(ArgumentError("standard-deviation multiplier must be nonnegative"))
        return new{T}(n, corrected)
    end
end

struct FixedRange{T<:Real} <: ColorRangeMethod
    low::T
    high::T
    function FixedRange(low::T, high::T) where {T<:Real}
        isfinite(low) && isfinite(high) ||
            throw(ArgumentError("fixed bounds must be finite"))
        low <= high || throw(ArgumentError("fixed bounds must satisfy low <= high"))
        return new{T}(low, high)
    end
end

FixedRange(low::Real, high::Real) = FixedRange(promote(low, high)...)

struct Symmetric{M<:ColorRangeMethod,T<:Real} <: ColorRangeMethod
    method::M
    center::T
end

Symmetric(method::ColorRangeMethod; center::Real=0) =
    Symmetric(method, center)

(method::ColorRangeMethod)(data; kwargs...) =
    colorrange(data, method; kwargs...)

function colorrange(data, ::Extrema; invalid::Symbol=:skip)
    summary = _summary(data; invalid)
    return (summary.lo, summary.hi)
end

function colorrange(data, method::Percentile; invalid::Symbol=:skip)
    values = _collect_valid(data; invalid)
    probabilities = [method.low / 100, method.high / 100]
    result = quantile(values, probabilities)
    return (result[1], result[2])
end

function colorrange(data, method::MeanStd; invalid::Symbol=:skip)
    summary = _summary(data; invalid)
    denominator = method.corrected && summary.n > 1 ? summary.n - 1 : summary.n
    sigma = summary.n == 1 ? zero(summary.mean) : sqrt(summary.m2 / denominator)
    delta = method.n * sigma
    return (summary.mean - delta, summary.mean + delta)
end

function colorrange(data, method::FixedRange; invalid::Symbol=:skip)
    _check_invalid_policy(invalid)
    return (method.low, method.high)
end

function colorrange(data, method::Symmetric; invalid::Symbol=:skip)
    low, high = colorrange(data, method.method; invalid)
    radius = max(abs(low - method.center), abs(high - method.center))
    return (method.center - radius, method.center + radius)
end
```

Modify `src/ColorScales.jl`:

```julia
module ColorScales

using PlotUtils
using Random
using Statistics

export Extrema, Percentile, MeanStd, FixedRange, Symmetric
export colorrange

include("input.jl")
include("ranges.jl")

end
```

- [ ] **Step 5: Run the range tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all loading and range tests pass.

- [ ] **Step 6: Commit range support**

```bash
git add src/ColorScales.jl src/input.jl src/ranges.jl test/runtests.jl test/ranges.jl
git commit -m "feat: add scientific color range methods" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 3: Add class representation and automatic counts

**Files:**
- Create: `src/classes.jl`
- Create: `test/classes.jl`
- Modify: `src/ColorScales.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing class tests**

Create `test/classes.jl`:

```julia
using Test
using ColorScales

@testset "class breaks" begin
    classes = ClassBreaks([0.0, 1.0, 3.0])
    @test classes.edges == [0.0, 1.0, 3.0]
    @test classes.closed === :right
    @test classes.labels == ["[0.0, 1.0]", "(1.0, 3.0]"]
    @test nclasses(classes) == 2
    @test classcenters(classes) == [0.5, 2.0]
    @test ColorScales.classindex(-1, classes) == 1
    @test ColorScales.classindex(0, classes) == 1
    @test ColorScales.classindex(1, classes) == 1
    @test ColorScales.classindex(nextfloat(1.0), classes) == 2
    @test ColorScales.classindex(4, classes) == 2

    constant = ClassBreaks([2.0])
    @test nclasses(constant) == 1
    @test classcenters(constant) == [2.0]
    @test constant.labels == ["[2.0]"]

    @test_throws ArgumentError ClassBreaks(Float64[])
    @test_throws ArgumentError ClassBreaks([0.0, 2.0, 1.0])
    @test_throws ArgumentError ClassBreaks([0.0, 1.0, 1.0])
    @test_throws ArgumentError ClassBreaks([0.0, 1.0]; closed=:left)
    @test_throws ArgumentError Sturges(maxclasses=0)
    @test_throws ArgumentError FreedmanDiaconis(maxclasses=0)
end
```

Append to `test/runtests.jl`:

```julia
include("classes.jl")
```

- [ ] **Step 2: Run the class tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales
include("test/classes.jl")
```

Expected: failure because `ClassBreaks` is undefined.

- [ ] **Step 3: Implement class invariants, labels, and lookup**

Create `src/classes.jl`:

```julia
abstract type ClassCountMethod end

struct Sturges <: ClassCountMethod
    maxclasses::Int
    function Sturges(; maxclasses::Integer=256)
        maxclasses > 0 || throw(ArgumentError("maxclasses must be positive"))
        return new(Int(maxclasses))
    end
end

struct FreedmanDiaconis <: ClassCountMethod
    maxclasses::Int
    function FreedmanDiaconis(; maxclasses::Integer=256)
        maxclasses > 0 || throw(ArgumentError("maxclasses must be positive"))
        return new(Int(maxclasses))
    end
end

function _default_labels(edges)
    length(edges) == 1 && return ["[$(only(edges))]"]
    labels = String["[$(edges[1]), $(edges[2])]"]
    for index in 2:(length(edges) - 1)
        push!(labels, "($(edges[index]), $(edges[index + 1])]")
    end
    return labels
end

struct ClassBreaks{T<:Real}
    edges::Vector{T}
    labels::Vector{String}
    closed::Symbol
end

function ClassBreaks(
        edges::AbstractVector{T};
        labels::Union{Nothing,AbstractVector{<:AbstractString}}=nothing,
        closed::Symbol=:right,
    ) where {T<:Real}
    isempty(edges) && throw(ArgumentError("class edges cannot be empty"))
    closed === :right ||
        throw(ArgumentError("only right-closed classes are supported"))
    issorted(edges) || throw(ArgumentError("class edges must be sorted"))
    allunique(edges) || throw(ArgumentError("class edges must be unique"))
    expected = length(edges) == 1 ? 1 : length(edges) - 1
    actual_labels = labels === nothing ? _default_labels(edges) : String.(labels)
    length(actual_labels) == expected ||
        throw(ArgumentError("expected $expected labels, got $(length(actual_labels))"))
    return ClassBreaks{T}(collect(edges), actual_labels, closed)
end

nclasses(classes::ClassBreaks) =
    length(classes.edges) == 1 ? 1 : length(classes.edges) - 1

function classcenters(classes::ClassBreaks)
    length(classes.edges) == 1 && return copy(classes.edges)
    return [
        (classes.edges[index] + classes.edges[index + 1]) / 2
        for index in 1:(length(classes.edges) - 1)
    ]
end

function classindex(value::Real, classes::ClassBreaks)
    length(classes.edges) == 1 && return 1
    index = searchsortedfirst(classes.edges, value) - 1
    return clamp(index, 1, nclasses(classes))
end

function _classcount(data, method::Sturges; invalid::Symbol=:skip)
    summary = _summary(data; invalid)
    count = ceil(Int, log2(summary.n) + 1)
    return clamp(count, 1, method.maxclasses)
end

function _classcount(
    data,
    method::FreedmanDiaconis,
    range::Tuple;
    invalid::Symbol=:skip,
)
    values = _collect_valid(data; invalid)
    q1, q3 = quantile(values, [0.25, 0.75])
    iqr = q3 - q1
    iszero(iqr) && return 1
    width = 2 * iqr / cbrt(length(values))
    count = ceil(Int, (range[2] - range[1]) / width)
    return clamp(count, 1, method.maxclasses)
end
```

Modify `src/ColorScales.jl` by adding:

```julia
export Sturges, FreedmanDiaconis
export ClassBreaks, nclasses, classcenters

include("classes.jl")
```

Place the include after `include("ranges.jl")`.

- [ ] **Step 4: Run the class tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass.

- [ ] **Step 5: Commit class representation**

```bash
git add src/ColorScales.jl src/classes.jl test/runtests.jl test/classes.jl
git commit -m "feat: represent graduated color classes" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 4: Implement range-based break methods

**Files:**
- Create: `src/breaks/range_based.jl`
- Create: `test/range_based_breaks.jl`
- Modify: `src/ColorScales.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing range-based break tests**

Create `test/range_based_breaks.jl`:

```julia
using Test
using ColorScales

@testset "range-based breaks" begin
    x = 0:10

    @test breaks(x, EqualInterval(2)).edges == [0.0, 5.0, 10.0]
    @test breaks(x, EqualInterval(Sturges())).edges[begin] == 0.0
    @test breaks(x, EqualInterval(Sturges())).edges[end] == 10.0
    @test nclasses(breaks(x, EqualInterval(Sturges()))) == 5
    @test nclasses(
        breaks(x, EqualInterval(FreedmanDiaconis()); colorrange=(0, 10)),
    ) == 3

    pretty = breaks(3:97, Pretty(5))
    @test first(pretty.edges) == 3.0
    @test last(pretty.edges) == 97.0
    @test all(edge -> edge in (20.0, 40.0, 60.0, 80.0), pretty.edges[2:(end - 1)])

    @test breaks(0:10, FixedInterval(4)).edges == [0.0, 4.0, 8.0, 10.0]
    @test breaks(1:1000, Geometric(3)).edges ≈ [1.0, 10.0, 100.0, 1000.0]
    @test breaks(Int[], EqualInterval(2); colorrange=FixedRange(-1, 1)).edges ==
        [-1.0, 0.0, 1.0]
    @test breaks(fill(2.0, 3), EqualInterval(5)).edges == [2.0]
    base = breaks(0:10, EqualInterval(4)).edges
    transformed = breaks(3 .* (0:10) .+ 7, EqualInterval(4)).edges
    @test transformed ≈ 3 .* base .+ 7
    @test nclasses(
        breaks(fill(2.0, 4), EqualInterval(FreedmanDiaconis())),
    ) == 1

    @test_throws ArgumentError EqualInterval(0)
    @test_throws ArgumentError Pretty(0)
    @test_throws ArgumentError FixedInterval(0)
    @test_throws ArgumentError Geometric(0)
    @test_throws ArgumentError breaks([-1, 1], Geometric(3))
    @test_throws ArgumentError breaks([1, NaN], EqualInterval(2); invalid=:error)
end
```

Append to `test/runtests.jl`:

```julia
include("range_based_breaks.jl")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales
include("test/range_based_breaks.jl")
```

Expected: failure because `EqualInterval` and `breaks` are undefined.

- [ ] **Step 3: Implement break types, count resolution, and range resolution**

Create `src/breaks/range_based.jl`:

```julia
abstract type BreakMethod end

function _check_count(count)
    count isa Integer && count > 0 && return Int(count)
    count isa ClassCountMethod && return count
    throw(ArgumentError("class count must be positive or an automatic count method"))
end

struct EqualInterval{C} <: BreakMethod
    count::C
    function EqualInterval(count)
        checked = _check_count(count)
        return new{typeof(checked)}(checked)
    end
end

struct Pretty{C} <: BreakMethod
    count::C
    function Pretty(count=7)
        checked = _check_count(count)
        return new{typeof(checked)}(checked)
    end
end

struct FixedInterval{T<:Real} <: BreakMethod
    width::T
    function FixedInterval(width::T) where {T<:Real}
        width > 0 || throw(ArgumentError("fixed interval must be positive"))
        return new{T}(width)
    end
end

struct Geometric{C} <: BreakMethod
    count::C
    function Geometric(count)
        checked = _check_count(count)
        return new{typeof(checked)}(checked)
    end
end

function _resolve_range(data, method::ColorRangeMethod, invalid::Symbol)
    return colorrange(data, method; invalid)
end

function _resolve_range(data, range::Tuple{<:Real,<:Real}, invalid::Symbol)
    _check_invalid_policy(invalid)
    return FixedRange(range...)(data)
end

function _resolve_count(data, count::Integer, range, invalid)
    return count
end

function _resolve_count(data, count::Sturges, range, invalid)
    return _classcount(data, count; invalid)
end

function _resolve_count(data, count::FreedmanDiaconis, range, invalid)
    return _classcount(data, count, range; invalid)
end

function _range_and_count(data, count, range_method, invalid)
    source = count isa Integer ? data : _collect_valid(data; invalid)
    bounds = _resolve_range(source, range_method, invalid)
    return bounds, _resolve_count(source, count, bounds, invalid)
end

function _make_edges(low, high, count::Integer)
    low == high && return [float(low)]
    return collect(range(float(low), float(high); length=count + 1))
end

function _pretty_step(low, high, target::Integer)
    span = high - low
    raw = span / target
    exponent = floor(Int, log10(raw))
    candidates = [
        multiplier * 10.0^power
        for power in (exponent - 1):(exponent + 1)
        for multiplier in (1.0, 2.0, 5.0, 10.0)
    ]
    return argmin(step -> abs(span / step - target), candidates)
end

function _pretty_edges(low, high, target::Integer)
    low == high && return [float(low)]
    step = _pretty_step(low, high, target)
    first_interior = ceil(low / step) * step
    interior = collect(first_interior:step:(high - step / 2))
    filter!(edge -> low < edge < high, interior)
    return unique!([float(low); interior; float(high)])
end

function breaks(
    data,
    method::EqualInterval;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    bounds, count = _range_and_count(data, method.count, colorrange, invalid)
    return ClassBreaks(_make_edges(bounds..., count))
end

function breaks(
    data,
    method::Pretty;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    bounds, count = _range_and_count(data, method.count, colorrange, invalid)
    return ClassBreaks(_pretty_edges(bounds..., count))
end

function breaks(
    data,
    method::FixedInterval;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    low, high = _resolve_range(data, colorrange, invalid)
    low == high && return ClassBreaks([float(low)])
    edges = collect(float(low):float(method.width):float(high))
    last(edges) == high || push!(edges, float(high))
    return ClassBreaks(edges)
end

function breaks(
    data,
    method::Geometric;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    bounds, count = _range_and_count(data, method.count, colorrange, invalid)
    low, high = bounds
    0 < low < high ||
        throw(ArgumentError("geometric breaks require 0 < low < high"))
    edges = exp.(range(log(float(low)), log(float(high)); length=count + 1))
    edges[1] = float(low)
    edges[end] = float(high)
    return ClassBreaks(edges)
end
```

Modify `src/ColorScales.jl` by adding:

```julia
export EqualInterval, Pretty, FixedInterval, Geometric
export breaks

include("breaks/range_based.jl")
```

Place the include after `include("classes.jl")`.

- [ ] **Step 4: Run the range-based break tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass; `Pretty(5)` selects a step of `20` for `3:97`.

- [ ] **Step 5: Commit range-based methods**

```bash
git add src/ColorScales.jl src/breaks/range_based.jl test/runtests.jl test/range_based_breaks.jl
git commit -m "feat: add range-based class breaks" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 5: Implement quantile and standard-deviation breaks

**Files:**
- Create: `src/breaks/data_based.jl`
- Create: `test/data_based_breaks.jl`
- Modify: `src/ColorScales.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing data-based break tests**

Create `test/data_based_breaks.jl`:

```julia
using Test
using ColorScales

@testset "data-based breaks" begin
    @test breaks(0:100, Quantile(4)).edges == [0.0, 25.0, 50.0, 75.0, 100.0]
    @test breaks(0:100, Quantile(4); colorrange=Percentile(20, 80)).edges ==
        [20.0, 35.0, 50.0, 65.0, 80.0]
    @test breaks([0, 0, 0, 1], Quantile(4)).edges == [0.0, 0.25, 1.0]

    standard = breaks([-2, -1, 0, 1, 2], StdDev(4; corrected=false))
    @test first(standard.edges) == -2.0
    @test last(standard.edges) == 2.0
    @test issorted(standard.edges)
    @test 0.0 in standard.edges

    clipped = breaks(
        [-100, -2, -1, 0, 1, 2, 100],
        StdDev(4; corrected=false);
        colorrange=(-2, 2),
    )
    @test clipped.edges == standard.edges

    base = breaks(0:100, Quantile(4)).edges
    transformed = breaks(3 .* (0:100) .+ 7, Quantile(4)).edges
    @test transformed ≈ 3 .* base .+ 7

    @test_throws ArgumentError Quantile(0)
    @test_throws ArgumentError StdDev(0)
end
```

Append to `test/runtests.jl`:

```julia
include("data_based_breaks.jl")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales
include("test/data_based_breaks.jl")
```

Expected: failure because `Quantile` and `StdDev` are undefined.

- [ ] **Step 3: Implement quantile and standard-deviation methods**

Create `src/breaks/data_based.jl`:

```julia
struct Quantile{C} <: BreakMethod
    count::C
    function Quantile(count)
        checked = _check_count(count)
        return new{typeof(checked)}(checked)
    end
end

struct StdDev{C} <: BreakMethod
    count::C
    corrected::Bool
end
StdDev(count=7; corrected::Bool=true) =
    StdDev(_check_count(count), corrected)

function _values_and_range(data, range_method, invalid)
    values = _collect_valid(data; invalid)
    range = _resolve_range(values, range_method, invalid)
    low, high = range
    inrange = filter(value -> low <= value <= high, values)
    isempty(inrange) &&
        throw(ArgumentError("selected color range contains no observations"))
    return inrange, range
end

function breaks(
    data,
    method::Quantile;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    values, bounds = _values_and_range(data, colorrange, invalid)
    count = _resolve_count(values, method.count, bounds, invalid)
    probabilities = collect(Base.range(0, 1; length=count + 1))
    edges = collect(quantile(values, probabilities))
    edges[1], edges[end] = bounds
    return ClassBreaks(unique!(sort!(edges)))
end

function breaks(
    data,
    method::StdDev;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    values, bounds = _values_and_range(data, colorrange, invalid)
    count = _resolve_count(values, method.count, bounds, invalid)
    average = mean(values)
    sigma = length(values) == 1 ? zero(average) :
        std(values; corrected=method.corrected)
    iszero(sigma) && return ClassBreaks([float(average)])
    zlow = (bounds[1] - average) / sigma
    zhigh = (bounds[2] - average) / sigma
    zedges = _pretty_edges(zlow, zhigh, count)
    edges = average .+ sigma .* zedges
    edges[1], edges[end] = bounds
    return ClassBreaks(unique!(sort!(edges)))
end
```

Modify `src/ColorScales.jl` by adding:

```julia
export Quantile, StdDev

include("breaks/data_based.jl")
```

Place the include after `include("breaks/range_based.jl")`.

- [ ] **Step 4: Run all core break tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass.

- [ ] **Step 5: Commit data-based methods**

```bash
git add src/ColorScales.jl src/breaks/data_based.jl test/runtests.jl test/data_based_breaks.jl
git commit -m "feat: add distribution-based class breaks" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 6: Implement weighted Fisher-Jenks natural breaks

**Files:**
- Create: `src/breaks/natural.jl`
- Create: `test/natural_breaks.jl`
- Modify: `src/ColorScales.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing natural-break tests**

Create `test/natural_breaks.jl`:

```julia
using Test
using Random
using Statistics
using ColorScales

function within_class_sse(values, classes)
    return sum(1:nclasses(classes)) do index
        members = filter(values) do value
            ColorScales.classindex(value, classes) == index
        end
        isempty(members) ? 0.0 : sum(abs2, members .- mean(members))
    end
end

@testset "natural breaks" begin
    values = [1.0, 2, 2, 3, 50, 51, 52, 100, 101]
    classes = breaks(values, NaturalBreaks(3))
    @test classes.edges == [1.0, 26.5, 76.0, 101.0]
    @test within_class_sse(values, classes) == 4.5
    @test breaks(3 .* values .+ 7, NaturalBreaks(3)).edges ≈
        3 .* classes.edges .+ 7

    repeated = breaks(vcat(fill(0.0, 100), fill(10.0, 100)), NaturalBreaks(2))
    @test repeated.edges == [0.0, 5.0, 10.0]
    @test nclasses(repeated) == 2

    oversized = collect(1.0:10.0)
    @test_throws ArgumentError breaks(
        oversized,
        NaturalBreaks(3; max_unique=5),
    )

    method1 = NaturalBreaks(
        3;
        max_unique=5,
        sampling=RandomSample(5, MersenneTwister(42)),
    )
    method2 = NaturalBreaks(
        3;
        max_unique=5,
        sampling=RandomSample(5, MersenneTwister(42)),
    )
    @test breaks(oversized, method1).edges == breaks(oversized, method2).edges
    @test_throws ArgumentError NaturalBreaks(0)
    @test_throws ArgumentError RandomSample(0, MersenneTwister(1))
end
```

Append to `test/runtests.jl`:

```julia
include("natural_breaks.jl")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales
include("test/natural_breaks.jl")
```

Expected: failure because `NaturalBreaks` is undefined.

- [ ] **Step 3: Implement explicit sampling and weighted dynamic programming**

Create `src/breaks/natural.jl`:

```julia
struct RandomSample{R<:AbstractRNG}
    size::Int
    rng::R
    function RandomSample(size::Integer, rng::R) where {R<:AbstractRNG}
        size > 0 || throw(ArgumentError("sample size must be positive"))
        return new{R}(Int(size), rng)
    end
end

struct NaturalBreaks{C,S} <: BreakMethod
    count::C
    max_unique::Int
    sampling::S
    function NaturalBreaks(
        count;
        max_unique::Integer=3000,
        sampling::Union{Nothing,RandomSample}=nothing,
    )
        checked = _check_count(count)
        max_unique > 0 || throw(ArgumentError("max_unique must be positive"))
        return new{typeof(checked),typeof(sampling)}(
            checked,
            Int(max_unique),
            sampling,
        )
    end
end

function _sample_values(values, sampling::RandomSample)
    sampling.size >= length(values) && return copy(values)
    rng = copy(sampling.rng)
    indices = randperm(rng, length(values))[1:sampling.size]
    return values[indices]
end

function _compress(values)
    sorted = sort(values)
    unique_values = eltype(sorted)[]
    weights = Int[]
    for value in sorted
        if isempty(unique_values) || value != last(unique_values)
            push!(unique_values, value)
            push!(weights, 1)
        else
            weights[end] += 1
        end
    end
    return unique_values, weights
end

function _prefix_costs(values, weights)
    n = length(values)
    weight = zeros(Float64, n + 1)
    weighted_value = zeros(Float64, n + 1)
    weighted_square = zeros(Float64, n + 1)
    for index in 1:n
        w = weights[index]
        x = values[index]
        weight[index + 1] = weight[index] + w
        weighted_value[index + 1] = weighted_value[index] + w * x
        weighted_square[index + 1] = weighted_square[index] + w * x * x
    end
    return weight, weighted_value, weighted_square
end

function _segment_sse(prefixes, first_index, last_index)
    weight, weighted_value, weighted_square = prefixes
    w = weight[last_index + 1] - weight[first_index]
    s = weighted_value[last_index + 1] - weighted_value[first_index]
    s2 = weighted_square[last_index + 1] - weighted_square[first_index]
    return max(0.0, s2 - s * s / w)
end

function _jenks_split_indices(values, weights, requested_classes)
    n = length(values)
    classes = min(requested_classes, n)
    costs = fill(Inf, classes, n)
    previous = zeros(Int, classes, n)
    prefixes = _prefix_costs(values, weights)

    for last_index in 1:n
        costs[1, last_index] = _segment_sse(prefixes, 1, last_index)
    end

    for class in 2:classes
        for last_index in class:n
            for split in (class - 1):(last_index - 1)
                candidate =
                    costs[class - 1, split] +
                    _segment_sse(prefixes, split + 1, last_index)
                if candidate < costs[class, last_index]
                    costs[class, last_index] = candidate
                    previous[class, last_index] = split
                end
            end
        end
    end

    upper_indices = Vector{Int}(undef, classes)
    last_index = n
    for class in classes:-1:1
        upper_indices[class] = last_index
        last_index = class == 1 ? 0 : previous[class, last_index]
    end
    return upper_indices[1:(end - 1)]
end

function breaks(
    data,
    method::NaturalBreaks;
    colorrange=Extrema(),
    invalid::Symbol=:skip,
)
    values, range = _values_and_range(data, colorrange, invalid)
    unique_values, weights = _compress(values)
    if length(unique_values) > method.max_unique
        method.sampling === nothing && throw(
            ArgumentError(
                "natural breaks found $(length(unique_values)) unique values; " *
                "set an explicit RandomSample to exceed max_unique=$(method.max_unique)",
            ),
        )
        values = _sample_values(values, method.sampling)
        unique_values, weights = _compress(values)
        length(unique_values) <= method.max_unique || throw(
            ArgumentError(
                "sample still contains $(length(unique_values)) unique values; " *
                "reduce RandomSample size to max_unique=$(method.max_unique) or less",
            ),
        )
    end
    count = _resolve_count(values, method.count, range, invalid)
    split_indices = _jenks_split_indices(unique_values, weights, count)
    boundaries = map(split_indices) do index
        lower = float(unique_values[index])
        upper = float(unique_values[index + 1])
        lower + (upper - lower) / 2
    end
    edges = unique!([float(range[1]); boundaries; float(range[2])])
    edges[end] = float(range[2])
    return ClassBreaks(edges)
end
```

Modify `src/ColorScales.jl` by adding:

```julia
export NaturalBreaks, RandomSample

include("breaks/natural.jl")
```

Place the include after `include("breaks/data_based.jl")`.

- [ ] **Step 4: Run natural-break and full package tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass, including the hand-computed SSE value `4.5`.

- [ ] **Step 5: Commit natural breaks**

```bash
git add src/ColorScales.jl src/breaks/natural.jl test/runtests.jl test/natural_breaks.jl
git commit -m "feat: add reproducible natural breaks" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 7: Compose PlotUtils color specifications

**Files:**
- Create: `src/spec.jl`
- Create: `test/spec.jl`
- Modify: `src/ColorScales.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing color-specification tests**

Create `test/spec.jl`:

```julia
using Test
using PlotUtils
using ColorScales

@testset "color specifications" begin
    classes = ClassBreaks([0.0, 1.0, 3.0])
    gradient = classgradient(:viridis, classes; colorrange=(0.0, 3.0))
    @test gradient isa PlotUtils.CategoricalColorGradient
    @test gradient.values == [0.0, 1 / 3, 1.0]

    graduated = colorspec(
        0:100,
        Quantile(4);
        colorrange=Percentile(2, 98),
        colormap=:viridis,
    )
    @test graduated.colorrange == (2.0, 98.0)
    @test graduated.classes.edges == [2.0, 26.0, 50.0, 74.0, 98.0]
    @test graduated.gradient isa PlotUtils.CategoricalColorGradient

    continuous = colorspec(0:100; colorrange=Percentile(2, 98), colormap=:viridis)
    @test continuous.colorrange == (2.0, 98.0)
    @test continuous.classes === nothing
    @test continuous.gradient isa PlotUtils.ContinuousColorGradient

    constant = colorspec(fill(2.0, 3), EqualInterval(4))
    @test constant.classes.edges == [2.0]
    @test constant.gradient isa PlotUtils.CategoricalColorGradient
end
```

Append to `test/runtests.jl`:

```julia
include("spec.jl")
```

- [ ] **Step 2: Run the specification tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales
include("test/spec.jl")
```

Expected: failure because `ColorSpec` is undefined.

- [ ] **Step 3: Implement gradients and composed specifications**

Create `src/spec.jl`:

```julia
struct ColorSpec{T<:Real,C,G}
    colorrange::Tuple{T,T}
    classes::C
    gradient::G
end

function classgradient(colormap, classes::ClassBreaks; colorrange)
    low, high = colorrange
    if low == high || length(classes.edges) == 1
        return PlotUtils.cgrad(colormap, 1; categorical=true)
    end
    normalized = (classes.edges .- low) ./ (high - low)
    first(normalized) == 0 && last(normalized) == 1 ||
        throw(ArgumentError("class edges must span the color range"))
    return PlotUtils.cgrad(colormap, normalized; categorical=true)
end

function colorspec(
    data;
    colorrange=Extrema(),
    colormap=:viridis,
    invalid::Symbol=:skip,
)
    range = _resolve_range(data, colorrange, invalid)
    gradient = PlotUtils.cgrad(colormap)
    return ColorSpec(range, nothing, gradient)
end

function colorspec(
    data,
    method::BreakMethod;
    colorrange=Extrema(),
    colormap=:viridis,
    invalid::Symbol=:skip,
)
    classes = breaks(data, method; colorrange, invalid)
    range = length(classes.edges) == 1 ?
        (only(classes.edges), only(classes.edges)) :
        (first(classes.edges), last(classes.edges))
    gradient = classgradient(colormap, classes; colorrange=range)
    return ColorSpec(range, classes, gradient)
end

function makie end
function plots end
function classify end
```

Modify `src/ColorScales.jl` by adding:

```julia
export ColorSpec, classgradient, colorspec
export makie, plots, classify

include("spec.jl")
```

Place the include after all break-method includes.

- [ ] **Step 4: Run specification and full tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass.

- [ ] **Step 5: Commit color specifications**

```bash
git add src/ColorScales.jl src/spec.jl test/runtests.jl test/spec.jl
git commit -m "feat: compose backend-neutral color specifications" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 8: Add Makie and Plots adapters

**Files:**
- Create: `ext/ColorScalesMakieExt.jl`
- Create: `ext/ColorScalesPlotsExt.jl`
- Create: `test/extensions.jl`
- Modify: `test/runtests.jl`

- [ ] **Step 1: Write failing plotting-adapter tests**

Create `test/extensions.jl` with the plotting tests first:

```julia
using Test
using ColorScales
using Makie
using Plots

@testset "plotting adapters" begin
    spec = colorspec(0:10, EqualInterval(2); colormap=:viridis)

    makie_attributes = makie(spec)
    @test keys(makie_attributes) == (:plot, :colorbar)
    @test makie_attributes.plot.colorrange == (0.0, 10.0)
    @test makie_attributes.plot.colormap === spec.gradient
    @test makie_attributes.colorbar.ticks ==
        ([2.5, 7.5], ["[0.0, 5.0]", "(5.0, 10.0]"])

    figure = Makie.Figure()
    axis = Makie.Axis(figure[1, 1])
    plot = Makie.heatmap!(axis, reshape(0.0:8.0, 3, 3); makie_attributes.plot...)
    @test plot isa Makie.Heatmap

    plots_attributes = plots(spec)
    @test keys(plots_attributes) == (:plot,)
    @test plots_attributes.plot.clims == (0.0, 10.0)
    @test plots_attributes.plot.color === spec.gradient
    @test plots_attributes.plot.colorbar_ticks ==
        ([2.5, 7.5], ["[0.0, 5.0]", "(5.0, 10.0]"])

    plot_object = Plots.heatmap(reshape(0.0:8.0, 3, 3); plots_attributes.plot...)
    @test plot_object isa Plots.Plot

    continuous = colorspec(0:10)
    @test makie(continuous).colorbar == (;)
    @test !haskey(plots(continuous).plot, :colorbar_ticks)
end
```

Ensure `test/runtests.jl` ends with:

```julia
include("extensions.jl")
```

- [ ] **Step 2: Run adapter tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales, Makie, Plots
include("test/extensions.jl")
```

Expected: `makie(spec)` and `plots(spec)` have no methods.

- [ ] **Step 3: Implement Makie attributes**

Create `ext/ColorScalesMakieExt.jl`:

```julia
module ColorScalesMakieExt

using ColorScales
import Makie

function ColorScales.makie(spec::ColorScales.ColorSpec)
    plot = (; colorrange=spec.colorrange, colormap=spec.gradient)
    colorbar = spec.classes === nothing ? (;) : (;
        ticks=(
            ColorScales.classcenters(spec.classes),
            spec.classes.labels,
        ),
    )
    return (; plot, colorbar)
end

end
```

- [ ] **Step 4: Implement Plots attributes**

Create `ext/ColorScalesPlotsExt.jl`:

```julia
module ColorScalesPlotsExt

using ColorScales
import Plots

function ColorScales.plots(spec::ColorScales.ColorSpec)
    base = (; clims=spec.colorrange, color=spec.gradient)
    plot = if spec.classes === nothing
        base
    else
        merge(base, (;
            colorbar_ticks=(
                ColorScales.classcenters(spec.classes),
                spec.classes.labels,
            ),
        ))
    end
    return (; plot)
end

end
```

- [ ] **Step 5: Run plotting-adapter tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass without opening a window or saving an image.

- [ ] **Step 6: Commit plotting adapters**

```bash
git add ext/ColorScalesMakieExt.jl ext/ColorScalesPlotsExt.jl test/runtests.jl test/extensions.jl
git commit -m "feat: adapt color specifications to Makie and Plots" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 9: Add Distributions and CategoricalArrays extensions

**Files:**
- Create: `ext/ColorScalesDistributionsExt.jl`
- Create: `ext/ColorScalesCategoricalArraysExt.jl`
- Modify: `test/extensions.jl`

- [ ] **Step 1: Add failing extension tests**

Append to `test/extensions.jl`:

```julia
using Distributions
using CategoricalArrays

@testset "Distributions extension" begin
    distribution = Normal(10, 2)
    expected_range = (quantile(distribution, 0.02), quantile(distribution, 0.98))
    @test colorrange(distribution, Percentile(2, 98)) == expected_range

    classes = breaks(
        distribution,
        Quantile(4);
        colorrange=Percentile(2, 98),
    )
    expected_probabilities = range(0.02, 0.98; length=5)
    @test classes.edges ≈ quantile.(Ref(distribution), expected_probabilities)
end

@testset "CategoricalArrays extension" begin
    classes = ClassBreaks([0.0, 1.0, 3.0])
    result = classify([-1.0, 0.0, 1.0, nextfloat(1.0), 3.0, 4.0], classes)
    @test result isa CategoricalArray
    @test isordered(result)
    @test String.(result) == [
        "[0.0, 1.0]",
        "[0.0, 1.0]",
        "[0.0, 1.0]",
        "(1.0, 3.0]",
        "(1.0, 3.0]",
        "(1.0, 3.0]",
    ]
end
```

- [ ] **Step 2: Run extension tests to verify they fail**

Run with `julia-julia_eval`:

```julia
using ColorScales, Distributions, CategoricalArrays
include("test/extensions.jl")
```

Expected: no `colorrange` method exists for `Distribution`, and `classify`
has no method.

- [ ] **Step 3: Implement supplied-distribution ranges and breaks**

Create `ext/ColorScalesDistributionsExt.jl`:

```julia
module ColorScalesDistributionsExt

using ColorScales
using Distributions

function ColorScales.colorrange(
    distribution::Distributions.UnivariateDistribution,
    method::ColorScales.Percentile;
    invalid::Symbol=:skip,
)
    ColorScales._check_invalid_policy(invalid)
    probabilities = (method.low / 100, method.high / 100)
    values = quantile.(Ref(distribution), probabilities)
    all(isfinite, values) ||
        throw(ArgumentError("selected distribution percentiles are not finite"))
    return values
end

function ColorScales.colorrange(
    distribution::Distributions.UnivariateDistribution,
    method::ColorScales.FixedRange;
    invalid::Symbol=:skip,
)
    ColorScales._check_invalid_policy(invalid)
    return (method.low, method.high)
end

function ColorScales.breaks(
    distribution::Distributions.UnivariateDistribution,
    method::ColorScales.Quantile;
    colorrange=ColorScales.Percentile(0, 100),
    invalid::Symbol=:skip,
)
    method.count isa Integer ||
        throw(ArgumentError("distribution quantiles require an explicit class count"))
    low, high = ColorScales.colorrange(distribution, colorrange; invalid)
    plow = cdf(distribution, low)
    phigh = cdf(distribution, high)
    probabilities = range(plow, phigh; length=method.count + 1)
    edges = quantile.(Ref(distribution), probabilities)
    edges[1], edges[end] = low, high
    return ColorScales.ClassBreaks(unique!(collect(edges)))
end

end
```

The unrestricted `Percentile(0, 100)` default can produce infinite bounds for
unbounded distributions. Keep the finite-result error; users must select
finite percentiles or fixed bounds.

- [ ] **Step 4: Implement right-closed categorical assignment**

Create `ext/ColorScalesCategoricalArraysExt.jl`:

```julia
module ColorScalesCategoricalArraysExt

using ColorScales
using CategoricalArrays

function ColorScales.classify(data, classes::ColorScales.ClassBreaks)
    labels = map(data) do value
        if ismissing(value)
            missing
        elseif !(value isa Real) || !isfinite(value)
            throw(ArgumentError("classification values must be finite real numbers or missing"))
        else
            classes.labels[ColorScales.classindex(value, classes)]
        end
    end
    result = categorical(labels; ordered=true)
    levels!(result, classes.labels)
    return result
end

end
```

- [ ] **Step 5: Run all extension and package tests**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass, including exact right-closed edge assignment and
theoretical distribution quantiles.

- [ ] **Step 6: Commit statistical extensions**

```bash
git add ext/ColorScalesDistributionsExt.jl ext/ColorScalesCategoricalArraysExt.jl test/extensions.jl
git commit -m "feat: integrate distributions and categorical classes" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 10: Document the package and add CI

**Files:**
- Create: `README.md`
- Create: `.github/workflows/CI.yml`
- Create: `src/public_docs.jl`
- Modify: `src/ColorScales.jl`

- [ ] **Step 1: Write README doctest-style examples**

Create `README.md`:

```markdown
# ColorScales.jl

ColorScales computes robust numeric color ranges and graduated class breaks,
then translates one result to Makie or Plots.

## Installation

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

These commands instantiate a local checkout. Add the registered package with
`Pkg.add("ColorScales")` after its first General registry release.

## Robust continuous color ranges

```julia
using ColorScales

z = reshape([0.0, 1, 2, 3, 4, 100], 2, 3)
colorrange(z, Percentile(2, 98))
colorrange(z, MeanStd(2))
colorrange(z, Symmetric(Percentile(2, 98); center=0))
```

## Graduated colors

```julia
spec = colorspec(
    z,
    Quantile(5);
    colorrange=Percentile(2, 98),
    colormap=:viridis,
)
```

Available break methods are `EqualInterval`, `Quantile`, `Pretty`, `StdDev`,
`FixedInterval`, `NaturalBreaks`, and `Geometric`. Counts can be explicit or
selected with `Sturges()` and `FreedmanDiaconis()`.

## Makie

```julia
using Makie

attributes = makie(spec)
figure, axis, plot = heatmap(z; attributes.plot...)
Colorbar(figure[1, 2], plot; attributes.colorbar...)
```

## Plots

```julia
using Plots

attributes = plots(spec)
heatmap(z; attributes.plot...)
heatmap(z; clims=Percentile(2, 98))
```

## Semantics

- Range selection and class selection are independent.
- `Percentile(2, 98)` uses percent values, not probabilities.
- Graduated classes are right-closed: `(a, b]`, with the first lower endpoint
  included.
- `missing`, `NaN`, and infinite observations are skipped by default. Pass
  `invalid=:error` to reject them.
- Values outside the color range saturate at the endpoint colors.
- Quantile and natural-break methods collect finite observations. Natural
  breaks above `max_unique` require an explicit `RandomSample`.
- `Pretty` and `StdDev` use the requested count as a target. Ties can reduce
  the actual number of classes.

## License

ColorScales is available under the MIT license. QGIS and R classInt are
feature references only; their GPL source is not copied or translated.
```

- [ ] **Step 2: Add complete public docstrings**

Create `src/public_docs.jl`:

```julia
@doc "Select the finite minimum and maximum as the color range." Extrema

@doc """
    Percentile(low, high)

Select a color range from data percentiles on the inclusive 0-to-100 scale.
Calling the object on data is equivalent to `colorrange(data, method)`.
""" Percentile

@doc """
    MeanStd(n; corrected=true)

Select `mean(data) +/- n * std(data)`. Set `corrected=false` for population
standard deviation and QGIS-compatible behavior.
""" MeanStd

@doc "Use explicit finite `low` and `high` color bounds." FixedRange

@doc """
    Symmetric(method; center=0)

Expand another method's result equally around `center`.
""" Symmetric

@doc """
    colorrange(data, method; invalid=:skip)

Compute a numeric `(low, high)` color range. `invalid` accepts `:skip` or
`:error` for `missing`, `NaN`, and infinite observations.
""" colorrange

@doc "Choose an automatic class count with Sturges' rule." Sturges

@doc """
    FreedmanDiaconis(; maxclasses=256)

Choose a class count from the Freedman-Diaconis width. A zero interquartile
range produces one class.
""" FreedmanDiaconis

@doc """
    ClassBreaks(edges; labels, closed=:right)

Represent ordered right-closed graduated classes. The first class also
includes the lowest edge.
""" ClassBreaks

@doc "Return the actual number of graduated classes." nclasses
@doc "Return the arithmetic center of every graduated class." classcenters

@doc "Create `count` equal-width classes over the selected color range." EqualInterval

@doc """
    Pretty(count=7)

Choose approximately `count` classes with interior steps from
`{1, 2, 5} * 10^n` while preserving the selected outer bounds.
""" Pretty

@doc "Create classes of fixed positive `width`, with a shorter final class when needed." FixedInterval

@doc """
    Geometric(count)

Create logarithmically spaced edges in original units. The selected range
must satisfy `0 < low < high`.
""" Geometric

@doc """
    Quantile(count)

Split observations inside the selected color range into approximately equal
counts. Tied quantiles can reduce the actual class count.
""" Quantile

@doc """
    StdDev(count=7; corrected=true)

Create pretty class edges in standard-deviation units, then convert them to
the original data units and selected outer bounds.
""" StdDev

@doc """
    RandomSample(size, rng)

Opt into reproducible sampling for an oversized natural-break calculation.
The random-number generator is copied before use.
""" RandomSample

@doc """
    NaturalBreaks(count; max_unique=3000, sampling=nothing)

Minimize within-class squared error with weighted Fisher-Jenks dynamic
programming. Exact optimization is `O(count * n^2)` in unique values.
Oversized inputs require an explicit `RandomSample`.
""" NaturalBreaks

@doc """
    breaks(data, method; colorrange=Extrema(), invalid=:skip)

Compute ordered class edges and labels inside a selected color range.
""" breaks

@doc """
    ColorSpec

Store a color range, optional `ClassBreaks`, and a PlotUtils gradient without
retaining source observations.
""" ColorSpec

@doc "Create a categorical PlotUtils gradient whose stops follow class edges." classgradient

@doc """
    colorspec(data, [method]; colorrange=Extrema(), colormap=:viridis, invalid=:skip)

Compose color-range selection, optional graduated breaks, and a PlotUtils
gradient.
""" colorspec

@doc "Translate a `ColorSpec` into Makie plot and Colorbar attribute bundles." makie
@doc "Translate a `ColorSpec` into a Plots attribute bundle." plots
@doc "Assign values to ordered, right-closed categories when CategoricalArrays is loaded." classify
```

Append this include after `include("spec.jl")` in `src/ColorScales.jl`:

```julia
include("public_docs.jl")
```

- [ ] **Step 3: Add continuous integration**

Create `.github/workflows/CI.yml`:

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        julia-version:
          - "1.10"
          - "1"
    steps:
      - uses: actions/checkout@v4
      - uses: julia-actions/setup-julia@v2
        with:
          version: ${{ matrix.julia-version }}
      - uses: julia-actions/cache@v2
      - uses: julia-actions/julia-buildpkg@v1
      - uses: julia-actions/julia-runtest@v1
```

- [ ] **Step 4: Run the complete package test suite**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.test()
```

Expected: every core and extension test passes.

- [ ] **Step 5: Check the clean package environment**

Run with `julia-julia_eval`:

```julia
using Pkg
Pkg.resolve()
Pkg.status()
```

Expected: `ColorScales v0.1.0` lists PlotUtils as the only non-stdlib hard
dependency; Makie, Plots, Distributions, and CategoricalArrays appear only in
the test target and weak-dependency sections. Do not commit `Manifest.toml`.

- [ ] **Step 6: Commit documentation and CI**

```bash
git add README.md .github/workflows/CI.yml src
git commit -m "docs: document ColorScales workflows" \
  -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

## Task 11: Perform final package verification

**Files:**
- No planned file changes

- [ ] **Step 1: Run tests in a fresh Julia process**

Run with `julia-julia_eval`, after restarting the package environment only if
the existing Julia session has stale method definitions:

```julia
using Pkg
Pkg.test()
```

Expected: all tests pass with no warnings from package loading or extension
activation.

- [ ] **Step 2: Verify public examples**

Run with `julia-julia_eval`:

```julia
using ColorScales

z = reshape(vcat(collect(0.0:98.0), 10_000.0), 10, 10)
spec = colorspec(
    z,
    Pretty(7);
    colorrange=Percentile(2, 98),
    colormap=:viridis,
)

@assert first(spec.classes.edges) == spec.colorrange[1]
@assert last(spec.classes.edges) == spec.colorrange[2]
@assert nclasses(spec.classes) >= 1
```

Expected: all assertions pass.

- [ ] **Step 3: Verify both plotting integrations**

Run with `julia-julia_eval`:

```julia
using ColorScales
using Makie
using Plots

z = reshape(1.0:100.0, 10, 10)
spec = colorspec(z, Quantile(5); colorrange=Percentile(2, 98))

makie_attributes = makie(spec)
figure = Makie.Figure()
axis = Makie.Axis(figure[1, 1])
makie_plot = Makie.heatmap!(axis, z; makie_attributes.plot...)
Makie.Colorbar(figure[1, 2], makie_plot; makie_attributes.colorbar...)

plots_attributes = plots(spec)
plots_plot = Plots.heatmap(z; plots_attributes.plot...)

@assert makie_plot isa Makie.Heatmap
@assert plots_plot isa Plots.Plot
```

Expected: both assertions pass without opening a GUI.

- [ ] **Step 4: Inspect the final diff**

```bash
git --no-pager status --short
git --no-pager diff --check
git --no-pager log --oneline --decorate -12
```

Expected: no uncommitted package changes, no whitespace errors, and one
focused commit for each completed task.
