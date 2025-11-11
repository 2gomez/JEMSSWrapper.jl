"""
JEMSSWrapper
============

Main wrapper module for JEMSS simulation framework with extensible move-up strategies.
"""
module JEMSSWrapper

using Dates
using DataFrames
using Random
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
include("encoding/state.jl")

include("strategies/abstract.jl")
include("strategies/logging.jl")

include("strategies/neuronal.jl")
include("strategies/ddsm.jl")
include("strategies/nullstrategy.jl")

include("simulation.jl")

export 
    # All JEMSS utils
    JEMSS,

    # Scenario management
    ScenarioData,
    load_scenario_from_config, 
    update_scenario_calls, 
    update_scenario_ambulances,
    randomize_ambulance_stations,
    
    # Simulation from an scenario 
    simulate_scenario,

    # Metrics
    extract_all_metrics,
    get_metric,
    
    # Move-up strategy interface
    AbstractMoveUpStrategy, 
    should_trigger_on_dispatch,
    should_trigger_on_free,
    decide_moveup,
    initialize_strategy,

    # Simulation State utils
    get_entity_property,
    get_all_entity_properties,
    
    # Neural strategy
    AbstractEncoder, 
    encode_state, 
    AbstractNeuralNetwork,
    forward, 
    NeuronalStrategy,

    # Logging system
    MoveUpLogger,
    get_entries,
    clear_log!,
    to_dataframe,

    # Move-up Implemented
    DDSMStrategy,
    NullStrategy

end # module JEMSSWrapper