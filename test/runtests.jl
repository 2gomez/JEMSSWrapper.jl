using Test
using JEMSS
using JEMSS: simulate!, jemssDir, getAvgCallResponseDuration, getCallsReachedInTime
using JEMSSWrapper

import JEMSSWrapper: SCENARIOS_DIR,
                    create_config_from_toml, 
                    initialize_basic_simulation,
                    initialize_calls,
                    initialize_ambulances, 
                    setup_network!,
                    setup_travel_system!,
                    setup_location_routing!,
                    setup_simulation_statistics!,
                    copy_base_simulation,
                    add_calls!,
                    add_ambulances!


@testset "All Tests" begin
    include("test_public_api.jl")
    include("test_internals.jl")
end