using Documenter
using JEMSSWrapper

# Configurar metadatos para doctesting
DocMeta.setdocmeta!(JEMSSWrapper, :DocTestSetup, :(using JEMSSWrapper); recursive = true)

makedocs(
    sitename = "JEMSSWrapper.jl",
    authors = "Sebastián Gómez",
    modules = [JEMSSWrapper],
    format = Documenter.HTML(
        prettyurls = false,
        canonical = "https://2gomez.github.io/JEMSSWrapper.jl",
        assets = String[],
    ),
    pages = [
        "Inicio" => "index.md",
        "Manual de Usuario" => [
            "Instalación" => "installation.md",
            "Guía de Inicio Rápido" => "quickstart.md",
            "Comparación JEMSS y JEMSSWrapper" => "jemss_vs_wrapper.md",
            "Clase `AbstractMoveUpStrategy`" => "moveup.md"
            #"Simulaciones" => "simulations.md",
            #"Escenarios" => "scenarios.md"
        ],
        #"Referencia de API" => [
        #    "Tipos Principales" => "api/types.md",
        #    "Simulación" => "api/simulation.md",
        #    "Inicialización" => "api/initialization.md",
        #    "Utilidades" => "api/utils.md",
        #    ]
        #"Ejemplos" => "examples.md",
        #"Desarrolladores" => "developers.md"
    ],
    warnonly = [:missing_docs],
    checkdocs = :exports
)

# Si quieres desplegar en GitHub Pages más adelante, descomenta:
# deploydocs(
#     repo = "github.com/tu-usuario/JEMSSWrapper.jl.git",
#     devbranch = "main"
# )
