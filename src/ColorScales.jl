"""
ColorScales turns univariate numeric data into renderer-neutral color
specifications: robust color ranges, interpretable graduated classes, and
readable class breaks for both Makie and Plots.
"""
module ColorScales

using PlotUtils

export Extrema, Percentile, MeanStd, FixedRange, Centered, colorrange
export ClassBreaks, nclasses, classcenters
export EqualInterval, Quantile, Pretty, FixedBreaks, breaks
export ColorSpec, classgradient, colorspec, colorgradient, classbreaks, classticks

include("input.jl")
include("ranges.jl")
include("classes.jl")
include("rangebreaks.jl")
include("databreaks.jl")
include("spec.jl")

end
