using Documenter, JEMSSWrapper

makedocs(
    sitename = "JEMSSWrapper.jl",
    modules = [JEMSSWrapper],
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(
    repo = "github.com/2gomez/JEMSSWrapper.jl.git",
    devbranch = "main"
)