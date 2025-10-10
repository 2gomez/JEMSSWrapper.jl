using Test
using JEMSSWrapper
using DataFrames
using CSV

@testset "All JEMSSWrapper Tests" begin
    # Public API tests
    include("test_public_api.jl")
    
    # Internal functions tests
    include("test_internals.jl")
    
    # Logging system tests
    include("test_logging.jl")
    
    # Strategies and abstract types tests
    include("test_strategies/test_core.jl")
    include("test_strategies/test_neuronal.jl")
    include("test_strategies/test_ddsm.jl")
end