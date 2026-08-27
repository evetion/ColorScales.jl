using Test
using ColorScales

@testset "color ranges" begin
    @testset "invalid observations" begin
        messy = [1.0, 2.0, missing, NaN, Inf, -Inf, 3.0]
        @test colorrange(messy, Extrema()) == (1.0, 3.0)
        @test_throws ArgumentError colorrange(messy, Extrema(); invalid = :error)
        @test colorrange([1, 2, 3], Extrema(); invalid = :error) == (1.0, 3.0)
        @test_throws ArgumentError colorrange([1.0, NaN], Extrema(); invalid = :error)
        @test_throws ArgumentError colorrange([1.0, missing], Extrema(); invalid = :error)
        @test_throws ArgumentError colorrange(["a", "b"], Extrema())
        @test_throws ArgumentError colorrange([1.0 + 2.0im], Extrema())
        @test_throws ArgumentError colorrange([1.0, 2.0], Extrema(); invalid = :reject)
        @test_throws ArgumentError colorrange([1.0, 2.0], Extrema(); invalid = "skip")
    end

    @testset "extrema" begin
        @test colorrange(1:10, Extrema()) == (1.0, 10.0)
        @test colorrange([5.0], Extrema()) == (5.0, 5.0)
        @test colorrange(1:10) == (1.0, 10.0)
        @test_throws ArgumentError colorrange(Float64[], Extrema())
        @test_throws ArgumentError colorrange([NaN, missing], Extrema())
    end

    @testset "percentile" begin
        z = collect(0.0:100.0)
        @test colorrange(z, Percentile(0, 100)) == (0.0, 100.0)
        @test colorrange(z, Percentile(2, 98)) == (2.0, 98.0)
        @test colorrange(z, Percentile(25, 75)) == (25.0, 75.0)
        @test Percentile(2, 98)(z) == (2.0, 98.0)
        @test Percentile(2, 98)(z; invalid = :skip) == (2.0, 98.0)
        @test Extrema()(z) == (0.0, 100.0)
        @test_throws ArgumentError Percentile(98, 2)
        @test_throws ArgumentError Percentile(-1, 50)
        @test_throws ArgumentError Percentile(0, 101)
        @test_throws ArgumentError Percentile(NaN, 50)
        @test_throws ArgumentError colorrange(Float64[], Percentile(2, 98))
    end

    @testset "mean and standard deviation" begin
        z = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        @test colorrange(z, MeanStd(2; corrected = false)) == (1.0, 9.0)
        corrected = 2 * sqrt(32 / 7)
        @test all(colorrange(z, MeanStd(2)) .≈ (5.0 - corrected, 5.0 + corrected))
        @test colorrange([3.0, 3.0, 3.0], MeanStd(2)) == (3.0, 3.0)
        @test colorrange([3.0], MeanStd(2)) == (3.0, 3.0)
        @test colorrange([3.0], MeanStd(2; corrected = false)) == (3.0, 3.0)
        @test MeanStd().n == 2.0
        @test_throws ArgumentError MeanStd(-1)
        @test_throws ArgumentError MeanStd(0)
        @test_throws ArgumentError colorrange(Float64[], MeanStd(2))
    end

    @testset "fixed range" begin
        @test colorrange(Float64[], FixedRange(-1, 1)) == (-1.0, 1.0)
        @test colorrange([missing, NaN], FixedRange(0, 10)) == (0.0, 10.0)
        @test colorrange((), FixedRange(2, 2)) == (2.0, 2.0)
        @test_throws ArgumentError FixedRange(1, -1)
        @test_throws ArgumentError FixedRange(0, Inf)
    end

    @testset "symmetric" begin
        @test colorrange([-3.0, 1.0, 2.0], Symmetric(Extrema())) == (-3.0, 3.0)
        @test colorrange([-3.0, 1.0, 2.0], Symmetric(Extrema(); center = 1)) == (-3.0, 5.0)
        @test colorrange([1.0, 5.0], Symmetric(FixedRange(1, 5))) == (-5.0, 5.0)
        @test colorrange(Float64[], Symmetric(FixedRange(1, 5))) == (-5.0, 5.0)
        @test Symmetric().center == 0.0
    end

    @testset "constant data" begin
        z = fill(7.0, 4)
        @test colorrange(z, Extrema()) == (7.0, 7.0)
        @test colorrange(z, Percentile(2, 98)) == (7.0, 7.0)
        @test colorrange(z, MeanStd(3)) == (7.0, 7.0)
        @test colorrange(z, Symmetric(Extrema(); center = 7)) == (7.0, 7.0)
    end
end
