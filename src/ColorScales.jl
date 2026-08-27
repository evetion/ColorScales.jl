"""
ColorScales turns univariate numeric data into renderer-neutral color
specifications: robust color ranges, interpretable graduated classes, and
readable class breaks for both Makie and Plots.
"""
module ColorScales

using PlotUtils
using Random
using Statistics

export Extrema, Percentile, MeanStd, FixedRange, Symmetric, colorrange
export Sturges, FreedmanDiaconis, ClassBreaks, nclasses, classcenters
export EqualInterval, Pretty, FixedInterval, Geometric
export Quantile, StdDev, NaturalBreaks, RandomSample, breaks
export ColorSpec, classgradient, colorspec
export makie, plots, classify

include("input.jl")
include("ranges.jl")
include("classes.jl")
include("rangebreaks.jl")
include("databreaks.jl")
include("naturalbreaks.jl")
include("spec.jl")

end
