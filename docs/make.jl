using Documenter, JEMSSWrapper

makedocs(
    sitename = "JEMSSWrapper.jl",
    modules = [JEMSSWrapper],
    format = Documenter.HTML(
        prettyurls = true,
    ),
    pages = [
        "Home" => "index.md",
    ],
)

deploydocs(
    repo = "github.com/2gomez/JEMSSWrapper.jl.git",
    devbranch = "main",
)