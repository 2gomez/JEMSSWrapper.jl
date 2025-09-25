# src/JEMSSWrapper.jl
"""
JEMSSWrapper
============

Main wrapper module for JEMSS simulation framework with extensible move-up strategies.
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

include("moveup.jl")
using .MoveUp

include("initialization.jl")
using .Initialization

include("scenario.jl")
using .Scenario

include("replication.jl")
using .Replication

include("simulation.jl")
using .Simulation

# Main exports
export 
    # JEMSS access
    jemss,
    
    # Path utilities
    PROJECT_DIR, JEMSS_DIR, SCENARIOS_DIR,
    
    # Types 
    ScenarioData,

    # Scenario management
    load_scenario_from_config,
    
    # Simulation instances management
    create_simulation_instance, 
    
    # Custom simulation with move-up strategies
    simulate_custom!,
    
    # Move-up strategy interface
    AbstractMoveUpStrategy, validate_moveup_decision

end # module JEMSSWrapper