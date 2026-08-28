using Test
using ColorScales
using Makie
using Plots
# Makie exports its own `plots`, so the explicit import picks ours.
using ColorScales: plots

include(joinpath(@__DIR__, "..", "examples", "makie.jl"))
include(joinpath(@__DIR__, "..", "examples", "plots.jl"))

@testset "Makie and Plots integration" begin
    z = reshape(collect(1.0:100.0), 10, 10)
    z[end, end] = 1.0e6
    spec = colorspec(z, Quantile(5); colorrange = Percentile(2, 98))

    @testset "graduated specification saturates the outlier" begin
        @test spec.colorrange == (2.98, 98.02)
        @test spec.breaks.edges == [2.98, 22.0, 41.0, 60.0, 79.0, 98.02]
        @test spec.breaks.labels == ["[2.98, 22]", "(22, 41]", "(41, 60]", "(60, 79]", "(79, 98.02]"]
        @test nclasses(spec.breaks) == 5
        @test length(spec.gradient.colors) == 5
    end

    @testset "makie adapter" begin
        attributes = makie(spec)
        @test keys(attributes) == (:plot, :colorbar)
        @test keys(attributes.plot) == (:colorrange, :colormap)
        @test attributes.plot.colorrange == (2.98, 98.02)
        @test attributes.plot.colormap === spec.gradient
        @test keys(attributes.colorbar) == (:ticks,)
        @test attributes.colorbar.ticks[1] ≈ [12.49, 31.5, 50.5, 69.5, 88.51]
        @test attributes.colorbar.ticks[2] == spec.breaks.labels
        @test attributes.colorbar.ticks[1] == classcenters(spec.breaks)
    end

    @testset "makie adapter of a continuous specification" begin
        continuous = colorspec(z; colorrange = Percentile(2, 98))
        attributes = makie(continuous)
        @test attributes.plot.colorrange == (2.98, 98.02)
        @test attributes.plot.colormap === continuous.gradient
        @test attributes.colorbar == NamedTuple()
    end

    @testset "user keywords override adapter keywords" begin
        merged = merge(makie(spec).plot, (; colormap = :magma))
        @test merged.colormap === :magma
        @test merged.colorrange == (2.98, 98.02)
        @test merge(plots(spec).plot, (; clims = (0.0, 1.0))).clims == (0.0, 1.0)
    end

    @testset "plots adapter" begin
        attributes = plots(spec)
        @test keys(attributes) == (:plot,)
        @test keys(attributes.plot) == (:clims, :color, :colorbar_ticks)
        @test attributes.plot.clims == (2.98, 98.02)
        @test attributes.plot.color === spec.gradient
        @test attributes.plot.colorbar_ticks[1] ≈ [12.49, 31.5, 50.5, 69.5, 88.51]
        @test attributes.plot.colorbar_ticks[2] == spec.breaks.labels
    end

    @testset "plots adapter of a continuous specification" begin
        continuous = colorspec(z; colorrange = Percentile(2, 98))
        attributes = plots(continuous)
        @test keys(attributes.plot) == (:clims, :color)
        @test attributes.plot.clims == (2.98, 98.02)
        @test attributes.plot.color === continuous.gradient
    end

    @testset "makie renders a figure and a colorbar" begin
        attributes = makie(spec)
        figure = Makie.Figure()
        axis = Makie.Axis(figure[1, 1])
        heatmap = Makie.heatmap!(axis, z; attributes.plot...)
        colorbar = Makie.Colorbar(figure[1, 2], heatmap; attributes.colorbar...)
        @test figure isa Makie.Figure
        @test colorbar isa Makie.Colorbar
        @test collect(heatmap.colorrange[]) ≈ [2.98, 98.02]
    end

    @testset "plots renders a heatmap" begin
        plot = Plots.heatmap(z; plots(spec).plot...)
        @test plot isa Plots.Plot
        @test plot[1][:clims] == (2.98, 98.02)
        @test plot[1][:colorbar_ticks][2] == spec.breaks.labels
        @test plot[1][1][:seriescolor] === spec.gradient
    end

    @testset "plots accepts a color range method directly" begin
        plot = Plots.heatmap(z; clims = Percentile(2, 98))
        @test plot isa Plots.Plot
        @test Plots.get_clims(plot[1]) == (2.98, 98.02)
    end

    @testset "only the plots adapter clashes with a plotting library" begin
        @test intersect(names(ColorScales), names(Makie)) == [:plots]
        @test isempty(intersect(names(ColorScales), names(Plots)))
        @test plots === ColorScales.plots
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
