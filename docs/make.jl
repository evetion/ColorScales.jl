using Documenter
using ColorScales
using CairoMakie
using Plots

CairoMakie.activate!(type = "png")
Plots.gr()
ENV["GKSwstype"] = "100"

DocMeta.setdocmeta!(ColorScales, :DocTestSetup, :(using ColorScales); recursive = true)

makedocs(;
    sitename = "ColorScales.jl",
    modules = [ColorScales],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    remotes = nothing,
    pages = [
        "Home" => "index.md",
        "Color ranges" => "ranges.md",
        "Graduated classes" => "breaks.md",
        "Makie" => "makie.md",
        "Plots" => "plots.md",
        "API reference" => "api.md",
    ],
)

if get(ENV, "CI", nothing) == "true"
    deploydocs(; repo = "github.com/evetion/ColorScales.jl.git")
end
