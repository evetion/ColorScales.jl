using Test
using ColorScales

@testset "range-based breaks" begin
    @testset "equal interval" begin
        @test breaks(0:10, EqualInterval(2)).edges == [0.0, 5.0, 10.0]
        @test breaks(0:10, EqualInterval(1)).edges == [0.0, 10.0]
        @test nclasses(breaks(0:10, EqualInterval(4))) == 4
        @test breaks(0:10, EqualInterval(2)).labels == ["[0, 5]", "(5, 10]"]
    end

    @testset "equal interval is affine invariant" begin
        z = [1.0, 3.7, 5.2, 9.9]
        a, b = 2.5, -4.0
        plain = breaks(z, EqualInterval(4)).edges
        moved = breaks(a .* z .+ b, EqualInterval(4)).edges
        @test moved ≈ a .* plain .+ b
    end

    @testset "pretty" begin
        @test Pretty().count == 7
        @test breaks(0:100, Pretty(5)).edges == [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
        @test all(e -> e % 20 == 0, breaks(3:97, Pretty(5)).edges)
        @test breaks([0.0, 1.0], Pretty(2)).edges == [0.0, 0.5, 1.0]
    end

    @testset "pretty widens the range to nice bounds" begin
        # 3:97 is not already nice at either end, so both bounds move outward.
        @test breaks(3:97, Pretty(5)).edges == [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
        @test breaks(1:19, Pretty(2)).edges == [0.0, 10.0, 20.0]
        # Already-nice bounds stay put.
        @test breaks(0:100, Pretty(5)).edges[[1, end]] == [0.0, 100.0]
    end

    @testset "equal interval degrades at the float resolution" begin
        cb = breaks([1.0e6, 1.0e6 + 3.0e-10], EqualInterval(10))
        @test cb isa ClassBreaks
        @test nclasses(cb) >= 1
        @test cb.edges[begin] == 1.0e6
        @test cb.edges[end] == 1.0e6 + 3.0e-10
        @test issorted(cb.edges)
        @test allunique(cb.edges)
        @test length(cb.edges) < 11
        @test nclasses(breaks([1.0e16, nextfloat(1.0e16)], EqualInterval(8))) == 1
    end

    @testset "constant data collapses" begin
        z = fill(3.0, 5)
        for method in (EqualInterval(4), Pretty(4), Quantile(4))
            cb = breaks(z, method)
            @test cb.edges == [3.0]
            @test nclasses(cb) == 1
        end
    end

    @testset "fixed color range without observations" begin
        @test breaks(Float64[], EqualInterval(2); colorrange = FixedRange(0, 10)).edges == [0.0, 5.0, 10.0]
        @test breaks((), EqualInterval(2); colorrange = (0, 10)).edges == [0.0, 5.0, 10.0]
        @test breaks([missing], Pretty(2); colorrange = FixedRange(0, 10)).edges == [0.0, 5.0, 10.0]
    end

    @testset "explicit color ranges" begin
        @test breaks(0:100, EqualInterval(2); colorrange = Percentile(20, 80)).edges == [20.0, 50.0, 80.0]
        @test breaks(0:100, EqualInterval(2); colorrange = (0, 200)).edges == [0.0, 100.0, 200.0]
        @test_throws ArgumentError breaks(0:100, EqualInterval(2); colorrange = (10, 0))
        @test_throws ArgumentError breaks(0:100, EqualInterval(2); colorrange = (1, 2, 3))
        @test_throws ArgumentError breaks(0:100, EqualInterval(2); colorrange = :extrema)
    end

    @testset "invalid observations" begin
        @test breaks([1.0, missing, NaN, 9.0], EqualInterval(2)).edges == [1.0, 5.0, 9.0]
        @test_throws ArgumentError breaks([1.0, missing, 9.0], EqualInterval(2); invalid = :error)
        @test_throws ArgumentError breaks([1.0, 9.0], EqualInterval(2); invalid = :nope)
        @test_throws ArgumentError breaks(Float64[], EqualInterval(2))
    end

    @testset "constructor validation" begin
        @test_throws ArgumentError EqualInterval(0)
        @test_throws ArgumentError EqualInterval(-2)
        @test_throws ArgumentError Pretty(0)
        @test_throws ArgumentError EqualInterval(2.5)
        @test_throws ArgumentError EqualInterval(:automatic)
    end
end

@testset "one-shot iterables" begin
    @test breaks(Iterators.Stateful(0.0:10.0), EqualInterval(2)).edges == [0.0, 5.0, 10.0]
    @test breaks(Iterators.Stateful(0.0:10.0), Quantile(2)).edges == [0.0, 5.0, 10.0]
    @test colorrange(Iterators.Stateful(0.0:10.0), Percentile(0, 100)) == (0.0, 10.0)
end
