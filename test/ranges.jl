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

    @testset "percentile survives ordinary sample sizes" begin
        z = collect(0.0:1000.0)
        @test length(z) == 1001
        @test colorrange(z, Percentile(2, 98)) == (20.0, 980.0)
        @test colorrange(z, Percentile(25, 75)) == (250.0, 750.0)
        wide = collect(0.0:4999.0)
        @test colorrange(wide, Percentile(2, 98)) == (99.98, 4899.02)
        @test colorrange(wide, Percentile(1, 99)) == (49.99, 4949.01)
    end

    @testset "percentile interpolates between observations" begin
        @test colorrange([0.0, 10.0], Percentile(25, 75)) == (2.5, 7.5)
        @test colorrange([0.0, 10.0], Percentile(0, 100)) == (0.0, 10.0)
        @test colorrange([0.0, 10.0], Percentile(50, 50)) == (5.0, 5.0)
        @test colorrange([0.0, 1.0, 2.0, 3.0], Percentile(30, 70)) == (0.9, 2.1)
        @test colorrange([0.0, 1.0, 2.0, 3.0], Percentile(2.5, 97.5)) == (0.075, 2.925)
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

    @testset "constant data" begin
        z = fill(7.0, 4)
        @test colorrange(z, Extrema()) == (7.0, 7.0)
        @test colorrange(z, Percentile(2, 98)) == (7.0, 7.0)
        @test colorrange(z, MeanStd(3)) == (7.0, 7.0)
    end

    @testset "centered" begin
        @test colorrange([-3.0, 1.0], Centered()) == (-3.0, 3.0)
        @test colorrange([-1.0, 5.0], Centered()) == (-5.0, 5.0)
        @test colorrange([-4.0, 4.0], Centered()) == (-4.0, 4.0)
        @test Centered().center == 0.0
        @test Centered()([-3.0, 1.0]) == (-3.0, 3.0)
    end

    @testset "centered widens the shorter side" begin
        @test colorrange([2.0, 10.0], Centered()) == (-10.0, 10.0)
        @test colorrange([-10.0, -2.0], Centered()) == (-10.0, 10.0)
    end

    @testset "centered wraps any inner range method" begin
        z = collect(-50.0:100.0)
        @test colorrange(z, Centered(Extrema())) == (-100.0, 100.0)
        @test colorrange(z, Centered(Percentile(2, 98))) == (-97.0, 97.0)
        @test colorrange(Float64[], Centered(FixedRange(-5, 20))) == (-20.0, 20.0)
        @test colorrange(Float64[], Centered((-5, 20))) == (-20.0, 20.0)
        spread = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        @test colorrange(spread, Centered(MeanStd(2; corrected = false))) == (-9.0, 9.0)
    end

    @testset "centered about another value" begin
        @test colorrange([0.0, 4.0], Centered(; center = 1)) == (-2.0, 4.0)
        @test colorrange([0.5, 2.0], Centered(; center = 1.0)) == (0.0, 2.0)
        # A center outside the inner range still yields a range containing it.
        @test colorrange([5.0, 10.0], Centered(; center = 20)) == (5.0, 35.0)
    end

    @testset "centered constant data" begin
        @test colorrange([0.0, 0.0], Centered()) == (0.0, 0.0)
        @test colorrange([3.0, 3.0], Centered()) == (-3.0, 3.0)
        @test colorrange([7.0], Centered(; center = 7)) == (7.0, 7.0)
    end

    @testset "centered validation" begin
        @test_throws ArgumentError Centered(; center = NaN)
        @test_throws ArgumentError Centered(; center = Inf)
        @test_throws ArgumentError Centered(:extrema)
        @test_throws ArgumentError Centered((10, 0))
        @test_throws ArgumentError colorrange(Float64[], Centered())
        @test colorrange([-3.0, missing, NaN, 1.0], Centered()) == (-3.0, 3.0)
        @test_throws ArgumentError colorrange([-3.0, missing, 1.0], Centered(); invalid = :error)
    end
end
