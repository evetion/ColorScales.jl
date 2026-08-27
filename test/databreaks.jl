using Test
using ColorScales

@testset "data-based breaks" begin
    @testset "quantile" begin
        z = collect(0.0:100.0)
        @test breaks(z, Quantile(4)).edges == [0.0, 25.0, 50.0, 75.0, 100.0]
        @test nclasses(breaks(z, Quantile(4))) == 4
        @test breaks(z, Quantile(2)).edges == [0.0, 50.0, 100.0]
        @test nclasses(breaks(z, Quantile(Sturges()))) == 8
    end

    @testset "quantile uses only in-range observations" begin
        z = collect(0.0:100.0)
        @test breaks(z, Quantile(4); colorrange = Percentile(20, 80)).edges == [20.0, 35.0, 50.0, 65.0, 80.0]
        @test breaks(z, Quantile(2); colorrange = FixedRange(-50, 150)).edges == [-50.0, 50.0, 150.0]
        @test_throws ArgumentError breaks(z, Quantile(2); colorrange = FixedRange(200, 300))
    end

    @testset "tied quantiles reduce the class count" begin
        tied = vcat(fill(1.0, 8), [2.0, 3.0])
        cb = breaks(tied, Quantile(4))
        @test cb.edges == [1.0, 3.0]
        @test nclasses(cb) == 1
    end

    @testset "quantile is affine invariant" begin
        z = [1.0, 2.0, 4.0, 8.0, 16.0, 32.0]
        a, b = 2.5, -4.0
        @test breaks(a .* z .+ b, Quantile(3)).edges ≈ a .* breaks(z, Quantile(3)).edges .+ b
    end

    @testset "standard deviation" begin
        z = collect(-3.0:3.0)
        corrected = sqrt(28 / 6)
        cb = breaks(z, StdDev(4))
        @test issorted(cb.edges)
        @test cb.edges[begin] == -3.0
        @test cb.edges[end] == 3.0
        @test 0.0 in cb.edges
        @test cb.edges ≈ [-3.0, -corrected, 0.0, corrected, 3.0]
        @test breaks(z, StdDev(4; corrected = false)).edges ≈ [-3.0, -2.0, 0.0, 2.0, 3.0]
        @test StdDev().count == 7
    end

    @testset "standard deviation clips outliers" begin
        z = collect(-3.0:3.0)
        outliers = vcat(z, [-100.0, 100.0])
        @test breaks(outliers, StdDev(4); colorrange = FixedRange(-3, 3)).edges == breaks(z, StdDev(4)).edges
        @test breaks(outliers, StdDev(4)).edges != breaks(z, StdDev(4)).edges
    end

    @testset "standard deviation is affine invariant" begin
        z = collect(-3.0:3.0)
        a, b = 3.0, 7.0
        @test breaks(a .* z .+ b, StdDev(4)).edges ≈ a .* breaks(z, StdDev(4)).edges .+ b
    end

    @testset "degenerate data" begin
        constant = fill(3.0, 5)
        @test breaks(constant, Quantile(4)).edges == [3.0]
        @test breaks(constant, StdDev(4)).edges == [3.0]
        @test breaks(constant, StdDev(4); colorrange = FixedRange(0, 10)).edges == [0.0, 10.0]
        @test_throws ArgumentError breaks(Float64[], Quantile(4))
        @test_throws ArgumentError breaks(Float64[], StdDev(4); colorrange = FixedRange(0, 10))
    end

    @testset "constructor validation" begin
        @test_throws ArgumentError Quantile(0)
        @test_throws ArgumentError Quantile(-3)
        @test_throws ArgumentError StdDev(0)
        @test_throws ArgumentError StdDev(2.5)
    end
end
