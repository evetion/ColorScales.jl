#
# Graduated Makie heatmap with a class-labelled colorbar.
#
# Run it from an environment holding ColorScales, Makie, and a Makie backend:
#
#     julia> include("examples/makie.jl")
#     julia> figure = makie_example()
#
# Displaying or saving `figure` needs a backend such as GLMakie or CairoMakie.
#

using ColorScales
using Makie

"""
    makie_example() -> Makie.Figure

Heatmap of a smooth surface holding one large outlier.

The color range is the 2nd to 98th percentile, so the outlier saturates instead
of flattening the rest of the surface, and the five quantile classes give the
colorbar one tick per class, labelled with its right-closed interval.
"""
function makie_example()
    elevation = [Float64((i + j)^2) for i in 1:20, j in 1:20]
    elevation[10, 10] = 1.0e6

    spec = colorspec(elevation, Quantile(5); colorrange = Percentile(2, 98), colormap = :viridis)
    attributes = makieattributes(spec)

    figure = Makie.Figure()
    axis = Makie.Axis(figure[1, 1]; title = "Elevation", xlabel = "column", ylabel = "row")
    heatmap = Makie.heatmap!(axis, elevation; attributes.plot...)
    Makie.Colorbar(figure[1, 2], heatmap; attributes.colorbar..., label = "metre")
    return figure
end
