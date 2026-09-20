using Test
using ColorScales
using PlotUtils

@testset "color specification" begin
    @testset "class gradient" begin
        classes = ClassBreaks([0.0, 1.0, 3.0])
        gradient = classgradient(:viridis, classes; colorrange = (0, 3))
        @test gradient isa PlotUtils.CategoricalColorGradient
        @test gradient.values ≈ [0.0, 1 / 3, 1.0]
        @test gradient.values[begin] == 0.0
        @test gradient.values[end] == 1.0
        @test length(gradient.colors) == nclasses(classes)
        @test length(gradient.colors.colors) == nclasses(classes)
    end

    @testset "class gradient must span the color range" begin
        classes = ClassBreaks([0.0, 1.0, 3.0])
        @test_throws ArgumentError classgradient(:viridis, classes; colorrange = (0, 10))
        @test_throws ArgumentError classgradient(:viridis, classes; colorrange = (-1, 3))
        @test_throws ArgumentError classgradient(:viridis, classes; colorrange = (0, 3.5))
        @test_throws ArgumentError classgradient(:viridis, ClassBreaks([-5.0, 1.0, 30.0]); colorrange = (0, 3))
        @test_throws ArgumentError classgradient(:viridis, ClassBreaks([-5.0, 1.0, 3.0]); colorrange = (0, 3))
        @test_throws ArgumentError classgradient(:viridis, ClassBreaks([0.0, 1.0, 30.0]); colorrange = (0, 3))
        @test_throws ArgumentError classgradient(:viridis, classes; colorrange = (3, 3))
        for count in 2:12
            edges = collect(range(-4.0, 6.0; length = count + 1))
            cb = ClassBreaks(edges)
            @test length(classgradient(:viridis, cb; colorrange = (-4, 6)).colors) == nclasses(cb)
        end
    end

    @testset "categorical gradients are right closed" begin
        classes = ClassBreaks([0.0, 1.0, 3.0])
        gradient = classgradient(:viridis, classes; colorrange = (0, 3))
        edge = gradient.values[2]
        @test 0.0 < edge < 1.0
        @test gradient[edge] == gradient.colors[1]
        @test gradient[nextfloat(edge)] == gradient.colors[2]
        @test gradient[prevfloat(edge)] == gradient.colors[1]
        @test gradient[0.0] == gradient.colors[1]
        @test gradient[1.0] == gradient.colors[2]
        @test gradient.colors[1] != gradient.colors[2]
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

    @testset "pretty breaks widen the specification's color range" begin
        spec = colorspec(1:19, Pretty(2))
        @test spec.colorrange == (0.0, 20.0)
        @test spec.breaks.edges == [0.0, 10.0, 20.0]
        @test spec.gradient isa PlotUtils.CategoricalColorGradient
        @test spec.gradient.values ≈ [0.0, 0.5, 1.0]
    end

    @testset "core accessors" begin
        z = collect(0.0:100.0)
        graduated = colorspec(z, Quantile(4); colorrange = Percentile(2, 98))
        @test colorrange(graduated) == graduated.colorrange
        @test colorgradient(graduated) === graduated.gradient
        @test classbreaks(graduated) === graduated.breaks
        @test nclasses(graduated) == nclasses(graduated.breaks) == 4
        @test classticks(graduated) == (classcenters(graduated.breaks), graduated.breaks.labels)

        continuous = colorspec(0:10)
        @test colorrange(continuous) == continuous.colorrange
        @test colorgradient(continuous) === continuous.gradient
        @test classbreaks(continuous) === nothing
        @test nclasses(continuous) == 0
        @test classticks(continuous) === nothing
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

    @testset "every break method yields a gradient with one color per class" begin
        z = collect(0.0:100.0)
        for method in (EqualInterval(4), Pretty(5), Quantile(4))
            spec = colorspec(z, method; colorrange = FixedRange(1, 100))
            @test length(spec.gradient.colors) == nclasses(spec.breaks)
            @test spec.breaks.edges[begin] == spec.colorrange[1]
            @test spec.breaks.edges[end] == spec.colorrange[2]
        end
    end

    @testset "renderer-safe display range" begin
        @test ColorScales.displayrange((2.0, 8.0)) === (2.0, 8.0)
        @test ColorScales.displayrange((7.0, 7.0)) == (6.5, 7.5)
        @test ColorScales.displayrange((0.0, 0.0)) == (-0.5, 0.5)
        for center in (0.0, 7.0, -7.0, 1.0e-300, 1.0e16, 1.0e300, -1.0e300)
            low, high = ColorScales.displayrange((center, center))
            @test isfinite(low) && isfinite(high)
            @test low < center < high
            @test high - center ≈ center - low
        end
        extreme = ColorScales.displayrange((floatmax(Float64), floatmax(Float64)))
        @test all(isfinite, extreme)
        @test extreme[1] < extreme[2]
        @test extreme[1] <= floatmax(Float64) <= extreme[2]
    end

    @testset "show renders the gradient as colors" begin
        spec = colorspec(0:100, Quantile(4); colorrange = Percentile(2, 98))

        plain = sprint(show, MIME("text/plain"), spec; context = :color => false)
        @test occursin("ColorSpec", plain)
        @test occursin("2.0", plain)
        @test occursin("98.0", plain)
        @test occursin("4 classes", plain)
        @test !occursin("\e[", plain)

        colored = sprint(show, MIME("text/plain"), spec; context = :color => true)
        @test occursin("\e[38;2;", colored)
        @test occursin("\e[0m", colored)
        @test length(colored) > length(plain)

        continuous = colorspec(0:10)
        continuousplain = sprint(show, MIME("text/plain"), continuous; context = :color => false)
        @test occursin("continuous", continuousplain)
        @test !occursin("classes", continuousplain)

        compact = sprint(show, spec)
        @test occursin("ColorSpec", compact)
        @test !occursin("\n", compact)
    end

    @testset "collapsed classes still match their gradient" begin
        spec = colorspec([1.0e6, 1.0e6 + 3.0e-10], EqualInterval(10))
        @test nclasses(spec.breaks) == 3
        @test length(spec.gradient.colors) == nclasses(spec.breaks)
        @test spec.breaks.edges[begin] == 1.0e6
        @test spec.breaks.edges[end] == 1.0e6 + 3.0e-10
        narrow = colorspec([1.0e16, nextfloat(1.0e16)], EqualInterval(8))
        @test nclasses(narrow.breaks) == 1
        @test length(narrow.gradient.colors) == 1
    end
end
