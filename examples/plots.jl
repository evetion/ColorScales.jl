#
# Graduated Plots heatmap with a class-labelled colorbar.
#
# Run it from an environment holding ColorScales and Plots:
#
#     julia> include("examples/plots.jl")
#     julia> plot = plots_example()
#

using ColorScales
using Plots

"""
    plots_example() -> Plots.Plot

Heatmap of a smooth surface holding one large outlier.

The color range is the 2nd to 98th percentile, so the outlier saturates instead
of flattening the rest of the surface, and the pretty classes give the colorbar
one tick per class, labelled with its right-closed interval.
"""
function plots_example()
    elevation = [Float64((i + j)^2) for i in 1:20, j in 1:20]
    elevation[10, 10] = 1.0e6

    spec = colorspec(elevation, Pretty(5); colorrange = Percentile(2, 98), colormap = :viridis)

    return Plots.heatmap(elevation; plotsattributes(spec).plot..., title = "Elevation", colorbar_title = "metre")
end
