using Test
using ColorScales

@testset "ColorScales" begin
    include("ranges.jl")
    include("classes.jl")
    include("rangebreaks.jl")
    include("databreaks.jl")
    include("naturalbreaks.jl")
    include("spec.jl")
end
