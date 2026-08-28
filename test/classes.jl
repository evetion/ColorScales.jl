using Test
using ColorScales

@testset "class breaks" begin
    @testset "labels and geometry" begin
        cb = ClassBreaks([0.0, 2.5, 5.0, 10.0])
        @test cb.edges == [0.0, 2.5, 5.0, 10.0]
        @test cb.closed === :right
        @test nclasses(cb) == 3
        @test cb.labels == ["[0, 2.5]", "(2.5, 5]", "(5, 10]"]
        @test classcenters(cb) == [1.25, 3.75, 7.5]
        @test length(cb.labels) == nclasses(cb)
    end

    @testset "constant class" begin
        cb = ClassBreaks([4.0])
        @test nclasses(cb) == 1
        @test cb.labels == ["[4, 4]"]
        @test classcenters(cb) == [4.0]
    end

    @testset "validation" begin
        @test_throws ArgumentError ClassBreaks(Float64[])
        @test_throws ArgumentError ClassBreaks([1.0, 0.0])
        @test_throws ArgumentError ClassBreaks([1.0, 1.0])
        @test_throws ArgumentError ClassBreaks([0.0, NaN])
        @test_throws ArgumentError ClassBreaks([0.0, Inf])
        @test_throws ArgumentError ClassBreaks([0.0, 1.0]; closed = :left)
        @test_throws ArgumentError ClassBreaks([0.0, 1.0]; closed = :both)
    end
end
