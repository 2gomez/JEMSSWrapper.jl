"""
JEMSSWrapper
============

Main wrapper module for JEMSS simulation framework with extensible move-up strategies.
"""
module JEMSSWrapper

using Dates
using JEMSS
using TOML
using Printf # To check

include("paths.jl")
include("types.jl")
include("initialization.jl")
include("replication.jl")
include("scenario.jl")
include("moveup.jl")
include("simulation.jl")  # TODO: include validate_decision_moveup
# include("evaluation.jl")  or stats.jl or metrics.jl  (Possible to future)

export 
    # Scenario management
    load_scenario_from_config, 
    update_scenario_calls, 
    update_scenario_ambulances,
    
    # Simulation instances management
    create_simulation_instance, 
    
    # Custom simulation with move-up strategies
    simulate_custom!,
    
    # Move-up strategy interface
    AbstractMoveUpStrategy, 
    should_trigger_on_dispatch,
    should_trigger_on_free,
    decide_moveup

end # module JEMSSWrapper