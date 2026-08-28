# Shared synthetic datasets used across the documentation pages.
#
# `raster` is a smooth surface with one large outlier, the same shape as the
# scenario in `examples/makie.jl` and `examples/plots.jl`. `points`, `xs`, and
# `ys` are a scattered sample of that same surface, standing in for vector
# data such as station measurements.

using Random

function sample_raster()
    raster = [Float64((i - 20)^2 + (j - 20)^2) for i in 1:40, j in 1:40]
    raster[15, 30] = 1.0e6
    return raster
end

function sample_points()
    rng = Random.MersenneTwister(1)
    xs = rand(rng, 1:40, 120)
    ys = rand(rng, 1:40, 120)
    values = Float64[(x - 20)^2 + (y - 20)^2 for (x, y) in zip(xs, ys)]
    values[1] = 1.0e6
    return xs, ys, values
end
