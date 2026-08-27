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

    @testset "right-closed lookup" begin
        cb = ClassBreaks([0.0, 2.5, 5.0, 10.0])
        @test ColorScales.classindex(cb, 0.0) == 1
        @test ColorScales.classindex(cb, 1.0) == 1
        @test ColorScales.classindex(cb, 2.5) == 1
        @test ColorScales.classindex(cb, nextfloat(2.5)) == 2
        @test ColorScales.classindex(cb, 5.0) == 2
        @test ColorScales.classindex(cb, nextfloat(5.0)) == 3
        @test ColorScales.classindex(cb, 10.0) == 3
        @test ColorScales.classindex(cb, -1.0e6) == 1
        @test ColorScales.classindex(cb, 1.0e6) == 3
    end

    @testset "constant class" begin
        cb = ClassBreaks([4.0])
        @test nclasses(cb) == 1
        @test cb.labels == ["[4, 4]"]
        @test classcenters(cb) == [4.0]
        @test ColorScales.classindex(cb, -1.0) == 1
        @test ColorScales.classindex(cb, 4.0) == 1
        @test ColorScales.classindex(cb, 9.0) == 1
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

@testset "automatic class counts" begin
    z = collect(0.0:10.0)

    @testset "sturges" begin
        @test nclasses(breaks(z, EqualInterval(Sturges()))) == 5
        @test breaks(z, Pretty(Sturges())).edges == [0.0, 2.0, 4.0, 6.0, 8.0, 10.0]
        @test nclasses(breaks([5.0], EqualInterval(Sturges()); colorrange = FixedRange(0, 10))) == 1
        @test Sturges().maxclasses == 256
        @test nclasses(breaks(z, EqualInterval(Sturges(; maxclasses = 3)))) == 3
    end

    @testset "freedman-diaconis" begin
        @test nclasses(breaks(z, EqualInterval(FreedmanDiaconis()))) == 3
        @test FreedmanDiaconis().maxclasses == 256
        @test nclasses(breaks(z, EqualInterval(FreedmanDiaconis(; maxclasses = 2)))) == 2
        flat = vcat(fill(5.0, 20), [0.0, 10.0])
        @test nclasses(breaks(flat, EqualInterval(FreedmanDiaconis()))) == 1
    end

    @testset "validation" begin
        @test_throws ArgumentError Sturges(; maxclasses = 0)
        @test_throws ArgumentError FreedmanDiaconis(; maxclasses = -1)
        @test_throws ArgumentError breaks(Float64[], EqualInterval(Sturges()); colorrange = FixedRange(0, 10))
        @test_throws ArgumentError breaks(Float64[], EqualInterval(FreedmanDiaconis()); colorrange = FixedRange(0, 10))
        @test_throws ArgumentError EqualInterval(:automatic)
    end
end
