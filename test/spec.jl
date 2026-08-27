using Test
using ColorScales
using PlotUtils

@testset "color specification" begin
    @testset "class gradient" begin
        classes = ClassBreaks([0.0, 1.0, 3.0])
        gradient = classgradient(:viridis, classes; colorrange = (0, 3))
        @test gradient isa PlotUtils.CategoricalColorGradient
        @test gradient.values ≈ [0.0, 1 / 3, 1.0]
        @test length(gradient.colors.colors) == nclasses(classes)
    end

    @testset "constant class gradient" begin
        gradient = classgradient(:viridis, ClassBreaks([4.0]); colorrange = (4, 4))
        @test gradient isa PlotUtils.CategoricalColorGradient
        @test length(gradient.colors.colors) == 1
    end

    @testset "graduated specification" begin
        z = collect(0.0:100.0)
        spec = colorspec(z, Quantile(4); colorrange = Percentile(2, 98), colormap = :viridis)
        @test spec isa ColorSpec
        @test spec.colorrange == (2.0, 98.0)
        @test spec.breaks.edges == [2.0, 26.0, 50.0, 74.0, 98.0]
        @test nclasses(spec.breaks) == 4
        @test spec.gradient isa PlotUtils.CategoricalColorGradient
        @test spec.gradient.values ≈ [0.0, 0.25, 0.5, 0.75, 1.0]
        @test fieldnames(ColorSpec) == (:colorrange, :breaks, :gradient)
    end

    @testset "continuous specification" begin
        spec = colorspec(0:10)
        @test spec.colorrange == (0.0, 10.0)
        @test spec.breaks === nothing
        @test spec.gradient isa PlotUtils.ContinuousColorGradient
        @test colorspec(0:10; colorrange = FixedRange(-1, 1)).colorrange == (-1.0, 1.0)
        @test_throws ArgumentError colorspec(Float64[])
        @test_throws ArgumentError colorspec([1.0, missing]; invalid = :error)
    end

    @testset "constant graduated specification" begin
        spec = colorspec(fill(4.0, 5), Quantile(4))
        @test spec.colorrange == (4.0, 4.0)
        @test spec.breaks.edges == [4.0]
        @test nclasses(spec.breaks) == 1
        @test spec.gradient isa PlotUtils.CategoricalColorGradient
    end

    @testset "specifications reuse one pass over the data" begin
        spec = colorspec(Iterators.Stateful(0.0:100.0), Quantile(4))
        @test spec.colorrange == (0.0, 100.0)
        @test spec.breaks.edges == [0.0, 25.0, 50.0, 75.0, 100.0]
    end

    @testset "extension hooks exist without methods" begin
        for hook in (makie, plots, classify)
            @test hook isa Function
            @test isempty(methods(hook))
        end
    end
end
