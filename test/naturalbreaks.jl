using Test
using ColorScales
using Random
using Statistics

function withinclasssse(data, classes)
    index = [ColorScales.classindex(classes, x) for x in data]
    total = 0.0
    for class in 1:nclasses(classes)
        group = data[index .== class]
        isempty(group) && continue
        total += sum((group .- mean(group)) .^ 2)
    end
    return total
end

@testset "natural breaks" begin
    clustered = [1.0, 2.0, 2.0, 3.0, 50.0, 51.0, 52.0, 100.0, 101.0]

    @testset "hand-verified optimum" begin
        cb = breaks(clustered, NaturalBreaks(3))
        @test cb.edges == [1.0, 26.5, 76.0, 101.0]
        @test nclasses(cb) == 3
        @test withinclasssse(clustered, cb) ≈ 4.5
    end

    @testset "repeated point masses stay separate" begin
        masses = [0.0, 0.0, 0.0, 10.0, 10.0, 10.0]
        cb = breaks(masses, NaturalBreaks(2))
        @test cb.edges == [0.0, 5.0, 10.0]
        @test nclasses(cb) == 2
        @test ColorScales.classindex(cb, 0.0) == 1
        @test ColorScales.classindex(cb, 10.0) == 2
        @test breaks(masses, NaturalBreaks(3)).edges == [0.0, 5.0, 10.0]
    end

    @testset "affine invariance" begin
        a, b = 2.5, -4.0
        moved = breaks(a .* clustered .+ b, NaturalBreaks(3)).edges
        @test moved ≈ a .* breaks(clustered, NaturalBreaks(3)).edges .+ b
    end

    @testset "optimal objective on evenly spaced data" begin
        z = collect(0.0:9.0)
        cb = breaks(z, NaturalBreaks(3))
        @test nclasses(cb) == 3
        @test cb.edges[begin] == 0.0
        @test cb.edges[end] == 9.0
        @test withinclasssse(z, cb) ≈ 9.0
        @test nclasses(breaks(collect(0.0:10.0), NaturalBreaks(Sturges()))) == 5
    end

    @testset "exact work is bounded" begin
        z = collect(0.0:9.0)
        @test_throws ArgumentError breaks(z, NaturalBreaks(3; max_unique = 5))
        @test nclasses(breaks(z, NaturalBreaks(3; max_unique = 10))) == 3
    end

    @testset "explicit sampling reproduces" begin
        z = collect(0.0:99.0)
        policy() = NaturalBreaks(3; max_unique = 20, sampling = RandomSample(20, MersenneTwister(42)))
        sampled = breaks(z, policy()).edges
        @test breaks(z, policy()).edges == sampled
        reused = policy()
        @test breaks(z, reused).edges == breaks(z, reused).edges
        @test length(sampled) == 4
        @test sampled[begin] == 0.0
        @test sampled[end] == 99.0
        @test_throws ArgumentError breaks(z, NaturalBreaks(3; max_unique = 20))
        @test_throws ArgumentError breaks(
            z, NaturalBreaks(3; max_unique = 5, sampling = RandomSample(20, MersenneTwister(42)))
        )
    end

    @testset "sampling requires an explicit generator" begin
        @test_throws MethodError RandomSample(5)
        @test_throws MethodError RandomSample(5; rng = MersenneTwister(1))
        @test_throws MethodError RandomSample(5, 42)
        @test fieldnames(RandomSample) == (:size, :rng)
        @test RandomSample(5, MersenneTwister(1)).rng isa AbstractRNG
        seeded = MersenneTwister(2024)
        policy = RandomSample(20, seeded)
        z = collect(0.0:99.0)
        method = NaturalBreaks(3; max_unique = 20, sampling = policy)
        @test breaks(z, method).edges == breaks(z, method).edges
        @test seeded == MersenneTwister(2024)
    end

    @testset "degenerate data" begin
        @test breaks(fill(4.0, 5), NaturalBreaks(3)).edges == [4.0]
        @test_throws ArgumentError breaks(Float64[], NaturalBreaks(3))
        @test breaks(clustered, NaturalBreaks(2); colorrange = FixedRange(0, 60)).edges == [0.0, 26.5, 60.0]
    end

    @testset "constructor validation" begin
        @test_throws ArgumentError NaturalBreaks(0)
        @test_throws ArgumentError NaturalBreaks(3; max_unique = 0)
        @test_throws ArgumentError RandomSample(0, MersenneTwister(1))
        @test_throws ArgumentError RandomSample(-5, MersenneTwister(1))
        @test NaturalBreaks(3).max_unique == 3000
        @test NaturalBreaks(3).sampling === nothing
        @test RandomSample(10, MersenneTwister(1)).size == 10
    end
end
