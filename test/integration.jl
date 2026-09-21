using Test
using ColorScales
using Makie
using Plots

# Render headlessly: GR must initialize without a window before the first plot.
ENV["GKSwstype"] = "100"

include(joinpath(@__DIR__, "..", "examples", "makie.jl"))
include(joinpath(@__DIR__, "..", "examples", "plots.jl"))

@testset "Makie and Plots integration" begin
    z = reshape(collect(1.0:100.0), 10, 10)
    z[end, end] = 1.0e6
    spec = colorspec(z, Quantile(5); colorrange = Percentile(2, 98))

    xs = collect(range(0, 1; length = 25))
    ys = reverse(xs)
    values = collect(range(0.0, 100.0; length = 25))
    points = colorspec(values, Pretty(5))

    @testset "graduated specification saturates the outlier" begin
        @test colorrange(spec) == (2.98, 98.02)
        @test classbreaks(spec).edges == [2.98, 22.0, 41.0, 60.0, 79.0, 98.02]
        @test classbreaks(spec).labels == ["[2.98, 22]", "(22, 41]", "(41, 60]", "(60, 79]", "(79, 98.02]"]
        @test nclasses(spec) == 5
        @test length(colorgradient(spec).colors) == 5
    end

    @testset "specification accessors" begin
        continuous = colorspec(z; colorrange = Percentile(2, 98))
        @test classbreaks(continuous) === nothing
        @test nclasses(continuous) == 0
        @test classticks(continuous) === nothing
    end

    @testset "makie colors a plot from the specification" begin
        converted = Makie.convert_arguments(Makie.Heatmap, z, spec)
        @test converted isa Makie.PlotSpec
        @test converted.type === :Heatmap
        @test converted.args == [z]
        @test converted.kwargs[:colormap] === colorgradient(spec)
        @test collect(converted.kwargs[:colorrange]) ≈ [2.98, 98.02]
    end

    @testset "makie resolves the plot type from the call" begin
        @test Makie.convert_arguments(Makie.Heatmap, z, spec).type === :Heatmap
        @test Makie.convert_arguments(Makie.Surface, z, spec).type === :Surface
        @test Makie.convert_arguments(Makie.Plot{Makie.plot}, z, spec).type === :Heatmap
        # Makie infers no plot type for a four-dimensional array.
        @test_throws ArgumentError Makie.convert_arguments(
            Makie.Plot{Makie.plot}, zeros(2, 2, 2, 2), colorspec(zeros(2, 2, 2, 2), Quantile(2))
        )
    end

    @testset "makie routes color by conversion trait" begin
        grid = Makie.convert_arguments(Makie.Heatmap, 1:10, 1:10, z, spec)
        @test length(grid.args) == 3
        @test !haskey(grid.kwargs, :color)

        scattered = Makie.convert_arguments(Makie.Scatter, xs, ys, values, points)
        @test scattered.type === :Scatter
        @test length(scattered.args) == 2
        @test scattered.kwargs[:color] ≈ values

        # Without positions the values are both position and color.
        alone = Makie.convert_arguments(Makie.Scatter, values, points)
        @test length(alone.args) == 1
        @test alone.kwargs[:color] ≈ values
    end

    @testset "makie renders a figure and a class-labelled colorbar" begin
        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        plot = Makie.heatmap!(axis, z, spec)
        colorbar = Makie.Colorbar(figure[1, 2], spec; label = "metre")
        @test plot isa Makie.PlotList
        @test collect(plot.plots[1].colorrange[]) ≈ [2.98, 98.02]
        @test plot.plots[1].colormap[] === colorgradient(spec)
        @test colorbar.ticks[] == classticks(spec)
        @test colorbar.ticks[][1] ≈ [12.49, 31.5, 50.5, 69.5, 88.51]
        @test colorbar.ticks[][2] == classbreaks(spec).labels
        @test colorbar.label[] == "metre"
    end

    @testset "makie colorbar of a continuous specification keeps its own ticks" begin
        continuous = colorspec(z; colorrange = Percentile(2, 98))
        figure = Makie.Figure()
        colorbar = Makie.Colorbar(figure[1, 1], continuous)
        @test colorbar.ticks[] == Makie.automatic
        @test colorbar.colormap[] === colorgradient(continuous)
    end

    @testset "makie scatter renders through the same rule" begin
        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        plot = Makie.scatter!(axis, xs, ys, values, points; markersize = 12)
        @test plot isa Makie.PlotList
        @test plot.plots[1] isa Makie.Scatter
        @test Makie.Colorbar(figure[1, 2], points) isa Makie.Colorbar
    end

    @testset "makie inline shorthand needs no named specification" begin
        graduated = Makie.convert_arguments(
            Makie.Heatmap, z, Quantile(5); colorrange = Percentile(2, 98), colormap = :magma
        )
        @test collect(graduated.kwargs[:colorrange]) ≈ [2.98, 98.02]
        @test graduated.kwargs[:colormap] == colorgradient(colorspec(z, Quantile(5); colorrange = Percentile(2, 98), colormap = :magma))

        continuous = Makie.convert_arguments(Makie.Heatmap, z, Percentile(2, 98))
        @test collect(continuous.kwargs[:colorrange]) ≈ [2.98, 98.02]

        @test Makie.used_attributes(Makie.Heatmap, z, Quantile(5)) == (:colorrange, :colormap)
        @test Makie.used_attributes(Makie.Heatmap, z, Percentile(2, 98)) == (:colormap,)

        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        plot = Makie.heatmap!(axis, z, Quantile(5); colorrange = Percentile(2, 98))
        @test collect(plot.plots[1].colorrange[]) ≈ [2.98, 98.02]
    end

    @testset "makie keywords override the specification" begin
        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        plot = Makie.heatmap!(axis, z, spec; colormap = :magma)
        @test plot.plots[1].colormap[] === :magma
        @test collect(plot.plots[1].colorrange[]) ≈ [2.98, 98.02]

        colorbar = Makie.Colorbar(figure[1, 2], spec; ticks = Makie.LinearTicks(3))
        @test colorbar.ticks[] isa Makie.LinearTicks
    end

    @testset "makie takes a specification as colormap and colorrange" begin
        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        plot = Makie.heatmap!(axis, z; colormap = spec, colorrange = spec)
        @test collect(plot.colorrange[]) ≈ [2.98, 98.02]
        @test plot.colormap[] === colorgradient(spec)
    end

    @testset "plots colors a series from the specification" begin
        plot = Plots.heatmap(z, spec; title = "elevation")
        @test plot isa Plots.Plot
        @test plot[1][:clims] == (2.98, 98.02)
        @test plot[1][1][:seriescolor] === colorgradient(spec)
        @test plot[1][:colorbar_ticks][1] ≈ [12.49, 31.5, 50.5, 69.5, 88.51]
        @test plot[1][:colorbar_ticks][2] == classbreaks(spec).labels
    end

    @testset "plots routes color by seriestype" begin
        grid = Plots.heatmap(1:10, 1:10, z, spec)
        @test grid[1][:clims] == (2.98, 98.02)

        scattered = Plots.scatter(xs, ys, values, points)
        @test scattered[1][1][:marker_z] == values
        @test scattered[1][:clims] == (0.0, 100.0)

        lined = Plots.plot(xs, ys, values, points; seriestype = :path)
        @test lined[1][1][:line_z] == values
    end

    @testset "plots continuous specification carries no class ticks" begin
        continuous = colorspec(z; colorrange = Percentile(2, 98))
        plot = Plots.heatmap(z, continuous)
        @test plot[1][:clims] == (2.98, 98.02)
        @test plot[1][1][:seriescolor] === colorgradient(continuous)
        @test plot[1][:colorbar_ticks] == :auto
    end

    @testset "plots inline shorthand needs no named specification" begin
        graduated = Plots.heatmap(z, Quantile(5); clims = Percentile(2, 98))
        @test graduated[1][:clims] == (2.98, 98.02)
        @test graduated[1][:colorbar_ticks][2] == classbreaks(spec).labels

        continuous = Plots.heatmap(z, Percentile(2, 98))
        @test continuous[1][:clims] == (2.98, 98.02)
        @test continuous[1][:colorbar_ticks] == :auto
    end

    @testset "plots keywords override the specification" begin
        plot = Plots.heatmap(z, spec; clims = (0.0, 1.0))
        @test plot[1][:clims] == (0.0, 1.0)
        @test plot[1][1][:seriescolor] === colorgradient(spec)
    end

    @testset "plots takes a color range method directly" begin
        plot = Plots.heatmap(z; clims = Percentile(2, 98))
        @test plot isa Plots.Plot
        @test Plots.get_clims(plot[1]) == (2.98, 98.02)
    end

    @testset "a centered range reaches both renderers" begin
        anomaly = [-2.0 1.0; 3.0 9.0]
        converted = Makie.convert_arguments(Makie.Heatmap, anomaly, Centered())
        @test collect(converted.kwargs[:colorrange]) == [-9.0, 9.0]
        plot = Plots.heatmap(anomaly; clims = Centered())
        @test Plots.get_clims(plot[1]) == (-9.0, 9.0)
    end

    @testset "fixed breaks reach both renderers" begin
        anomaly = [-2.0 1.0; 3.0 9.0]
        fixed = colorspec(anomaly, FixedBreaks([-10, -5, 0, 5, 10]))
        @test colorrange(fixed) == (-10.0, 10.0)
        @test nclasses(fixed) == 4
        converted = Makie.convert_arguments(Makie.Heatmap, anomaly, fixed)
        @test collect(converted.kwargs[:colorrange]) == [-10.0, 10.0]
        plot = Plots.heatmap(anomaly, fixed)
        @test Plots.get_clims(plot[1]) == (-10.0, 10.0)
    end

    @testset "no exported name collides with a plotting library" begin
        @test isempty(intersect(names(ColorScales), names(Makie)))
        @test isempty(intersect(names(ColorScales), names(Plots)))
        @test !isdefined(ColorScales, :makieattributes)
        @test !isdefined(ColorScales, :plotsattributes)
    end

    @testset "constant data still renders" begin
        constant = fill(7.0, 10, 10)
        flat = colorspec(constant, Quantile(4))
        @test colorrange(flat) == (7.0, 7.0)
        @test classbreaks(flat).edges == [7.0]
        @test nclasses(flat) == 1

        converted = Makie.convert_arguments(Makie.Heatmap, constant, flat)
        widened = collect(converted.kwargs[:colorrange])
        @test all(isfinite, widened)
        @test widened[1] < 7.0 < widened[2]

        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        plot = Makie.heatmap!(axis, constant, flat)
        colorbar = Makie.Colorbar(figure[1, 2], flat)
        @test colorbar isa Makie.Colorbar
        @test collect(plot.plots[1].colorrange[]) ≈ widened

        rendered = Plots.heatmap(constant, flat)
        @test rendered[1][:clims][1] < 7.0 < rendered[1][:clims][2]
        buffer = IOBuffer()
        show(buffer, MIME("image/png"), rendered)
        @test position(buffer) > 0
    end

    @testset "documented examples run" begin
        figure = makie_example()
        @test figure isa Makie.Figure
        @test length(figure.content) == 2
        plot = plots_example()
        @test plot isa Plots.Plot
        @test plot[1][:clims] isa Tuple{Float64, Float64}
    end
end
