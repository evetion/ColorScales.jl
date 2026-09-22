# ColorScales.jl Plotting API Redesign

**Date:** 2026-09-20
**Status:** Implemented
**Supersedes:** the plotting-adapter section of
[`2026-08-27-color-scales-design.md`](2026-08-27-color-scales-design.md)

## Problem

The 0.1.0 plotting interface returns nested named tuples that the caller must
splat:

```julia
spec = colorspec(elevation, Quantile(5); colorrange = Percentile(2, 98))
attributes = makieattributes(spec)

heatmap = heatmap!(axis, elevation; attributes.plot...)
Colorbar(figure[1, 2], heatmap; attributes.colorbar..., label = "metre")
```

Three problems. The caller holds an intermediate object whose only purpose is
to be taken apart. The two halves are reached by field access, `attributes.plot`,
where a function call is the more Julian spelling. And the shape of the named
tuple — which fields exist, whether `colorbar` is empty — is API surface that
has to be documented and tested even though no user should ever care.

The target is to pass the object itself.

## Goals

1. Pass a `ColorSpec` to a plotting call as an argument, not as splatted
   keywords.
2. Keep the numeric core renderer-neutral and data-free, so one spec can color
   several panels on a shared scale.
3. Reach every colored plot type through one rule, not one adapter per plot.
4. Offer a shorthand that needs no named spec for the one-off case.
5. Delete the named-tuple adapters outright. The package is unregistered at
   0.1.0; no deprecation shims.

## Non-goals

No new plot types or recipes of our own. No `contourf` level mapping (see
Deferred). No change to any range method, break method, gradient, or label.

## Verified mechanisms

Every mechanism below was prototyped against Makie 0.24.15, CairoMakie, and
Plots 1.x before this design was accepted.

1. `Makie.convert_arguments` may return a `Makie.PlotSpec`. Makie detects it
   through `got_converted`, routes it through the `PlotList` recipe, and a
   `PlotSpec`'s keyword arguments become plot attributes. This is what lets a
   converter set `colormap` and `colorrange`, which plain `convert_arguments`
   cannot do.
2. The resulting `PlotList` works with `Colorbar(figure[1, 2], plot)`, because
   `extract_colormap_recursive` descends into `plot.plots`.
3. Makie already renders a categorical `cgrad` as proportional bands, so the
   automatic colorbar is correct without help; only the interval labels are
   ours to add.
4. `Makie.used_attributes` lets a converter read keywords off the plot call,
   and Makie then withholds those keywords from the backend. It must be
   declared on `::Type{<:Makie.Plot}`; `::Type{<:AbstractPlot}` is ambiguous
   with Makie's own fallback.
5. `Makie.conversion_trait` distinguishes `PointBased` plots, whose color is an
   attribute, from grid-based plots, whose color is a positional argument.
6. On the Plots side a `@recipe` on `(data, spec)` sets `clims`,
   `seriescolor`, and `colorbar_ticks`, and `RecipesPipeline.is_surface`
   mirrors Makie's conversion trait.

## The argument rule

One rule covers every plot type:

> The spec goes last. The argument before it is what gets colored. Everything
> before that is position.

```julia
heatmap!(axis, elevation, spec)          # elevation is colored
heatmap!(axis, x, y, elevation, spec)    # x, y position; elevation colored
scatter!(axis, xs, ys, values, spec)     # xs, ys position; values colored
```

Whether the colored argument stays positional or moves into a `color` attribute
follows from the plotting library's own classification of the plot type, so
scatter, heatmap, surface, image, and volume all come from one implementation
and the plot type is never hardcoded.

## Core changes

`ColorSpec` and `colorspec` keep their contract unchanged. A specification
still never retains the observations it came from; that is what lets one spec
color several panels on a shared scale, which is the only reason to name a spec
at all.

Field access is replaced by accessors:

| 0.1.0 | proposed |
| --- | --- |
| `spec.colorrange` | `colorrange(spec)` (already exists) |
| `spec.gradient` | `colorgradient(spec)` (already exists) |
| `spec.breaks` | `classbreaks(spec)` |
| `nclasses(spec.breaks)` | `nclasses(spec)` |

`classticks(spec)` and `displayrange(bounds)` are unchanged. `displayrange`
stays internal and now runs inside the converters instead of the adapters, so
constant data keeps rendering.

Removed from the public API: `makieattributes`, `plotsattributes`.

## Makie extension

```julia
colorargument(::Any, values) = (values,), NamedTuple()
colorargument(::Makie.PointBased, values) = (), (; color = values)

function specplot(P, positions::Tuple, values, spec::ColorSpec)
    PT = Makie.plottype(P, Makie.plottype(positions..., values))
    args, kw = colorargument(Makie.conversion_trait(PT), values)
    return Makie.PlotSpec(
        Makie.plotsym(PT), positions..., args...;
        colorrange = displayrange(colorrange(spec)),
        colormap = colorgradient(spec), kw...,
    )
end
```

Four `convert_arguments` methods pin the arity, because Julia does not allow a
`Vararg` to precede a positional argument:

```julia
Makie.convert_arguments(P::Type{<:Makie.Plot}, v, spec::ColorSpec) =
    specplot(P, (), v, spec)
Makie.convert_arguments(P::Type{<:Makie.Plot}, a, v, spec::ColorSpec) =
    specplot(P, (a,), v, spec)
Makie.convert_arguments(P::Type{<:Makie.Plot}, a, b, v, spec::ColorSpec) =
    specplot(P, (a, b), v, spec)
Makie.convert_arguments(P::Type{<:Makie.Plot}, a, b, c, v, spec::ColorSpec) =
    specplot(P, (a, b, c), v, spec)
```

That covers `heatmap(z)`, `heatmap(x, y, z)`, `scatter(x, y, v)`,
`scatter(points, v)`, and `volume(x, y, z, vol)`. The colored argument is typed
`AbstractArray{<:Union{Real, Missing}}` so a wrong call raises a plain
`MethodError` instead of failing deep inside Makie.

The colorbar becomes a method on our own type, which is dispatch rather than
piracy:

```julia
Colorbar(figure[1, 2], spec; label = "metre")
```

It supplies `colormap`, `colorrange`, and, for a graduated specification,
class-interval `ticks`. A keyword passed by the caller wins over ours.
`Colorbar(figure[1, 2], plotobject)` keeps working; it labels class edges
numerically instead of by interval.

The existing `convert_attribute(spec, Key{:colormap})` and `Key{:colorrange}`
hooks stay as a narrow escape hatch for plot types the argument rule cannot
model, documented as "pass it to both keywords or to neither".

## Plots extension

```julia
@recipe function f(values::ColoredValues, spec::ColorSpec)
    seriestype --> :heatmap
    return colorseries!(plotattributes, (), values, spec, seriestypeof(plotattributes))
end

@recipe function f(x, y, values::ColoredValues, spec::ColorSpec)
    seriestype --> :heatmap
    return colorseries!(plotattributes, (x, y), values, spec, seriestypeof(plotattributes))
end
```

`colorseries!` sets `clims`, `seriescolor`, and, for a graduated specification,
`colorbar_ticks`, then routes `values` the way the seriestype demands:
positional for a surface-like series, `line_z` or `marker_z` otherwise, and
both when there are no positions. Every attribute goes in with `get!`, the
same soft-default semantics as `-->`, so an explicit keyword on the call still
wins. The shorthand recipes `delete!` the keywords they consume first, so the
computed values replace them.

```julia
heatmap(elevation, spec; title = "elevation", colorbar_title = "metre")
scatter(xs, ys, values, spec)
```

Plots needs no separate colorbar call, because `colorbar_ticks` rides along on
the series. That asymmetry with Makie is a property of the two libraries and is
documented rather than hidden: in Makie the colorbar is a separate object and
therefore takes the specification separately.

A pre-existing limitation carries over: Plots' GR backend only tests
`colorbar_ticks` for presence and then draws its own numeric axis, so the class
labels reach `pythonplot` and `pgfplotsx` but not GR. The 0.1.0 adapters had
the same behavior. It is documented rather than worked around.

`clims = Percentile(2, 98)` keeps working unchanged, because the range methods
are already callable and Plots calls `clims` on the data itself.

## Inline shorthand

For the one-off case the break method takes the specification's slot and no
specification is ever named.

```julia
Makie.used_attributes(::Type{<:Makie.Plot}, v, ::BreakMethod) =
    (:colorrange, :colormap)

function Makie.convert_arguments(P::Type{<:Makie.Plot}, v, m::BreakMethod;
                                 colorrange = Extrema(), colormap = :viridis)
    return specplot(P, (), v, colorspec(v, m; colorrange, colormap))
end
```

```julia
heatmap(elevation, Quantile(5); colorrange = Percentile(2, 98), colormap = :magma)
```

Because Makie withholds a `used_attributes` name from the backend,
`colorrange = Percentile(2, 98)` never arrives as a raw method; the converter
consumes it and emits the computed span. A `ColorRangeMethod` in the same slot
gives the continuous case, `heatmap(elevation, Percentile(2, 98))`.

Plots takes the same shape from `plotattributes`, reading `:clims` and
`:seriescolor` and treating `:auto` as the default.

The shorthand leaves no specification behind, so the Makie colorbar falls back
to numeric edge ticks and Plots gets no `colorbar_ticks`. That is the intended
split: shorthand for a quick look, a named specification when class labels or a
shared scale are wanted.

## Testing

`test/integration.jl` changes most. The adapter testsets become call-shape
testsets asserting on the `PlotSpec` keyword arguments Makie receives and on
`plot[1][:clims]` and `plot[1][:colorbar_ticks]` for Plots. The constant-data,
outlier-saturation, and name-collision testsets survive unchanged, since
`displayrange` still runs and no exported name is added.

New coverage: the argument rule across `heatmap`, `scatter`, and `surface`; the
point-based versus grid-based routing of the colored argument; the inline
shorthand in both libraries; and `Colorbar(position, spec)` for graduated and
continuous specifications.

## Deferred

`contourf` has no `colorrange` attribute and therefore throws under the
argument rule. The correct mapping is `levels = classbreaks(spec).edges`
together with `colormap`, which is a genuinely good fit for graduated classes.
It is left out rather than special-cased now.
