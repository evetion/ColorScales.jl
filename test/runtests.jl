using Test
using ColorScales

@testset "ColorScales" begin
    include("ranges.jl")
    include("classes.jl")
    include("rangebreaks.jl")
    include("databreaks.jl")
    include("spec.jl")
    include("exports.jl")
    include("integration.jl")
end
