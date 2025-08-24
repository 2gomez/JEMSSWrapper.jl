# src/JEMSSWrapper.jl
"""
JEMSSWrapper
============

Main wrapper module for JEMSS simulation framework.
"""
module JEMSSWrapper

using JEMSS

@info "✅ Successfully loaded JEMSS from local fork"

# Make JEMSS accessible through JEMSSWrapper
const jemss = JEMSS

# Load modules
include("utils/path_utils.jl")
using .PathUtils

include("types.jl")
using .Types

include("simulation.jl")
using .Simulation

include("scenario.jl")
using .Scenario

# Main exports
export 
    # JEMSS access
    jemss,
    
    # Path utilities
    PROJECT_DIR, JEMSS_DIR, SCENARIOS_DIR,
    
    # Types 
    SimulationConfig, ScenarioData,

    # Scenario management
    load_scenario_from_config,
    
    # Simulation management
    initialize_simulation, set_ambulances_data!, initialize_calls,
    create_simulation_instances

end # module JEMSSWrapper