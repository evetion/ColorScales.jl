using Test
using ColorScales

@testset "public surface" begin
    @testset "exports are exactly the documented set" begin
        expected = [
            :ClassBreaks, :ColorScales, :ColorSpec, :EqualInterval, :Extrema,
            :FixedRange, :MeanStd, :Percentile, :Pretty, :Quantile,
            :breaks, :classcenters, :classgradient, :classticks, :colorgradient,
            :colorrange, :colorspec, :makieattributes, :nclasses, :plotsattributes,
        ]
        @test sort(names(ColorScales)) == sort(expected)
    end

    @testset "every export is documented" begin
        documented = Base.Docs.meta(ColorScales)
        for name in setdiff(names(ColorScales), [:ColorScales])
            @test haskey(documented, Base.Docs.Binding(ColorScales, name))
        end
    end

    @testset "range methods are callable" begin
        for method in (Extrema(), Percentile(2, 98), MeanStd(2), FixedRange(0, 1))
            @test method isa ColorScales.ColorRangeMethod
            @test method isa Function
        end
        for method in (EqualInterval(3), Quantile(3), Pretty(3))
            @test method isa ColorScales.BreakMethod
        end
    end
end
