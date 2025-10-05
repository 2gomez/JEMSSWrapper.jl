push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Documenter
using JEMSSWrapper 

makedocs(
    sitename = "JEMSSWrapper.jl",
    modules = [JEMSSWrapper],
    format = Documenter.HTML(
        prettyurls = true,
    ),
    pages = [
        "Home" => "index.md",
    ],
    remotes = nothing,
)

deploydocs(
    repo = "github.com/2gomez/JEMSSWrapper.jl.git",
    devbranch = "main",
)