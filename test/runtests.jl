using Test
using JEMSSWrapper


@testset "All Tests" begin
    include("test_public_api.jl")
    include("test_internals.jl")
end