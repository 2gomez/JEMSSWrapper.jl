using Documenter, JEMSSWrapper

makedocs(
    sitename = "JEMSSWrapper.jl",
    modules = [JEMSSWrapper],
    format = Documenter.HTML(
        prettyurls = true,
    ),
    pages = [
        "Home" => "index.md",
        "JEMSS vs JEMSSWrapper" => "jemss_vs_wrapper.md",
        "User Guide" => [
            "Scenario Configuration" => "scenario_configuration.md",
            "Strategy Development Guide" => "strategies.md",
            "Simulation State" => "simulation_state.md"
        ],
       "API Reference" => "api.md"
    ],
    checkdocs = :none,
)

deploydocs(
    repo = "github.com/2gomez/JEMSSWrapper.jl.git",
    devbranch = "main",
)