using Test
using ColorScales
using LinearAlgebra
using Distributions

@testset "public names avoid ecosystem collisions" begin
    @testset "renamed names stay unambiguous" begin
        @test SymmetricRange <: ColorScales.ColorRangeMethod
        @test GeometricInterval <: ColorScales.BreakMethod
        @test SymmetricRange === ColorScales.SymmetricRange
        @test GeometricInterval === ColorScales.GeometricInterval
        @test colorrange([-3.0, 1.0, 2.0], SymmetricRange()) == (-3.0, 3.0)
        @test breaks(1:1000, GeometricInterval(3)).edges ≈ [1.0, 10.0, 100.0, 1000.0]
    end

    @testset "colliding names belong to their owners" begin
        @test Symmetric === LinearAlgebra.Symmetric
        @test Geometric === Distributions.Geometric
        @test !(:Symmetric in names(ColorScales))
        @test !(:Geometric in names(ColorScales))
    end

    @testset "no exported name collides with LinearAlgebra or Distributions" begin
        ours = setdiff(names(ColorScales), [:ColorScales])
        theirs = union(Set(names(LinearAlgebra)), Set(names(Distributions)))
        @test isempty(intersect(Set(ours), theirs))
    end
end
