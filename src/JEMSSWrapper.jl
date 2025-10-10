"""
JEMSSWrapper
============

Main wrapper module for JEMSS simulation framework with extensible move-up strategies.
"""
module JEMSSWrapper

using Dates
using DataFrames
using JEMSS
using TOML
using Printf
using CSV
using Statistics

include("core/paths.jl")
include("core/types.jl")
include("core/initialization.jl")
include("core/replication.jl")
include("core/scenario.jl")
include("core/metrics.jl")

include("encoding/abstract.jl")
include("encoding/utils.jl")
include("encoding/basic.jl")

include("strategies/abstract.jl")
include("strategies/logging.jl")

# Implemented strategies
include("strategies/neuronal.jl")
include("strategies/ddsm.jl")
include("strategies/nullstrategy.jl")

include("simulation.jl")

export 
    # All JEMSS utils
    JEMSS,

    # Scenario management
    ScenarioConfig,
    ScenarioData,
    load_scenario_from_config, 
    update_scenario_calls, 
    update_scenario_ambulances,
    
    # Simulation instances management
    create_simulation_instance, 
    
    # Custom simulation with move-up strategies
    simulate_custom!,
    simulate_scenario,
    
    # Move-up strategy interface
    AbstractMoveUpStrategy, 
    should_trigger_on_dispatch,
    should_trigger_on_free,
    decide_moveup,
    initialize_strategy,

    # Simulation State utils
    get_entity_property,
    get_all_entity_properties,
    
    # Neural strategy components (types and interface)
    AbstractEncoder, 
    AbstractNeuralNetwork,
    encode_state, 
    forward, 

    # Encodings
    BasicStateEncoder,

    # Logging system
    MoveUpDecision,
    MoveUpLogEntry,
    MoveUpLogger,
    create_log_entry,
    add_entry!,
    get_entries,
    clear_log!,
    num_entries,
    to_dataframe,
    save_dataframe,

    # Move-up Strategies
    NeuronalStrategy,
    DDSMStrategy,
    NullStrategy

end # module JEMSSWrapper