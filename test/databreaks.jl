using Test
using ColorScales

@testset "data-based breaks" begin
    @testset "quantile" begin
        z = collect(0.0:100.0)
        @test breaks(z, Quantile(4)).edges == [0.0, 25.0, 50.0, 75.0, 100.0]
        @test nclasses(breaks(z, Quantile(4))) == 4
        @test breaks(z, Quantile(2)).edges == [0.0, 50.0, 100.0]
    end

    @testset "quantile survives ordinary sample sizes" begin
        z = collect(0.0:999.0)
        @test length(z) == 1000
        cb = breaks(z, Quantile(7))
        @test nclasses(cb) == 7
        @test cb.edges[begin] == 0.0
        @test cb.edges[end] == 999.0
        @test cb.edges ≈ [
            0.0, 142.71428571428572, 285.42857142857144, 428.14285714285717,
            570.8571428571429, 713.5714285714286, 856.2857142857143, 999.0,
        ]
        @test issorted(cb.edges)
        @test nclasses(breaks(collect(0.0:1000.0), Quantile(3))) == 3
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

    @testset "degenerate data" begin
        constant = fill(3.0, 5)
        @test breaks(constant, Quantile(4)).edges == [3.0]
        @test_throws ArgumentError breaks(Float64[], Quantile(4))
    end

    @testset "constructor validation" begin
        @test_throws ArgumentError Quantile(0)
        @test_throws ArgumentError Quantile(-3)
        @test_throws ArgumentError Quantile(2.5)
    end
end
