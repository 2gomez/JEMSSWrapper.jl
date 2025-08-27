"""
MoveUp
======

Abstract interface for move-up strategies in JEMSS simulations.
This module defines the interface that all move-up strategies must implement.
"""
module MoveUp

using JEMSS

export AbstractMoveUpStrategy, should_trigger_on_dispatch, should_trigger_on_free, decide_moveup,
       initialize_strategy!, copy_strategy, update_parameters!, validate_moveup_decision

# =============================================================================
# ABSTRACT TYPES
# =============================================================================

"""
    AbstractMoveUpStrategy

Abstract type for move-up decision strategies.

All concrete move-up strategies must inherit from this type and implement
the required interface methods:
- `should_trigger_on_dispatch(strategy, sim)`
- `should_trigger_on_free(strategy, sim)`  
- `decide_moveup(strategy, sim, triggering_ambulance)`

# Example
```julia
struct MyStrategy <: AbstractMoveUpStrategy
    param1::Float64
    param2::Int
end

function should_trigger_on_dispatch(strategy::MyStrategy, sim::JEMSS.Simulation)
    # Your logic here
    return true  # or false
end

function should_trigger_on_free(strategy::MyStrategy, sim::JEMSS.Simulation)
    # Your logic here  
    return true  # or false
end

function decide_moveup(strategy::MyStrategy, sim::JEMSS.Simulation, triggering_ambulance::JEMSS.Ambulance)
    # Your decision logic here
    movable_ambulances = JEMSS.Ambulance[]
    target_stations = JEMSS.Station[]
    return (movable_ambulances, target_stations)
end
```
"""
abstract type AbstractMoveUpStrategy end

# =============================================================================
# INTERFACE METHODS
# =============================================================================

"""
    should_trigger_on_dispatch(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation) -> Bool

Determine whether move-up should be considered when an ambulance is dispatched to a call.

This method is called whenever an ambulance receives a dispatch event (`ambDispatched`).
The strategy should return `true` if it wants to trigger a move-up consideration event,
or `false` if no move-up should be considered at this time.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The move-up strategy instance
- `sim::JEMSS.Simulation`: The current simulation state

# Returns
- `Bool`: `true` to trigger move-up consideration, `false` otherwise

# Implementation Requirements
This method must be implemented by all concrete strategy types.
"""
function should_trigger_on_dispatch(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation)
    error("should_trigger_on_dispatch not implemented for $(typeof(strategy)). " *
          "All AbstractMoveUpStrategy subtypes must implement this method.")
end

"""
    should_trigger_on_free(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation) -> Bool

Determine whether move-up should be considered when an ambulance becomes free after completing a call.

This method is called whenever an ambulance finishes serving a call (`ambBecomesFree`) and 
there are no queued calls waiting for service. The strategy should return `true` if it 
wants to trigger a move-up consideration event, or `false` if no move-up should be considered.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The move-up strategy instance
- `sim::JEMSS.Simulation`: The current simulation state

# Returns
- `Bool`: `true` to trigger move-up consideration, `false` otherwise

# Implementation Requirements
This method must be implemented by all concrete strategy types.
"""
function should_trigger_on_free(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation)
    error("should_trigger_on_free not implemented for $(typeof(strategy)). " *
          "All AbstractMoveUpStrategy subtypes must implement this method.")
end

"""
    decide_moveup(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation, triggering_ambulance::JEMSS.Ambulance) -> Tuple{Vector{JEMSS.Ambulance}, Vector{JEMSS.Station}}

Make move-up decisions: determine which ambulances should move and to which stations.

This is the core decision-making method of the move-up strategy. It receives the current
simulation state and the ambulance that triggered the move-up consideration, and must
return which ambulances should be moved and their target stations.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The move-up strategy instance
- `sim::JEMSS.Simulation`: The current simulation state
- `triggering_ambulance::JEMSS.Ambulance`: The ambulance that triggered this move-up consideration

# Returns
- `Tuple{Vector{JEMSS.Ambulance}, Vector{JEMSS.Station}}`: A tuple containing:
  - Vector of ambulances that should be moved
  - Vector of target stations (same length as ambulances vector)

# Implementation Requirements
- This method must be implemented by all concrete strategy types
- The returned vectors must have the same length
- Each ambulance in the first vector will be moved to the corresponding station in the second vector
- Ambulances that should not move should not be included in the returned vectors
- The strategy should only move ambulances that are eligible for move-up (typically those that are idle at stations or returning to stations)

# Notes
- The actual move-up execution (event scheduling, route changes, etc.) is handled by the simulation engine
- The strategy only needs to make the decisions, not execute them
- If no moves should be made, return empty vectors
"""
function decide_moveup(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation, triggering_ambulance::JEMSS.Ambulance)
    error("decide_moveup not implemented for $(typeof(strategy)). " *
          "All AbstractMoveUpStrategy subtypes must implement this method.")
end

# =============================================================================
# STRATEGY LIFECYCLE METHODS
# =============================================================================

"""
    initialize_strategy!(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation) -> Nothing

Initialize the strategy with simulation-specific precomputations.

This method is called once before the simulation starts to allow strategies to perform
expensive precomputations that can be reused throughout the simulation. Examples include:
- Computing distance matrices between stations
- Analyzing coverage patterns  
- Training ML models
- Building lookup tables

# Arguments
- `strategy::AbstractMoveUpStrategy`: The move-up strategy instance (modified in-place)
- `sim::JEMSS.Simulation`: The simulation in its initial state

# Implementation Requirements
- This method is optional - default implementation does nothing
- Should modify the strategy in-place to store precomputed data
- Should be idempotent (safe to call multiple times)
- Access to full simulation state including network, stations, ambulances, etc.

# Example
```julia
mutable struct MyMLStrategy <: AbstractMoveUpStrategy
    model::Union{Nothing, MLModel}
    distance_matrix::Union{Nothing, Matrix{Float64}}
    
    MyMLStrategy() = new(nothing, nothing)
end

function initialize_strategy!(strategy::MyMLStrategy, sim::JEMSS.Simulation)
    # Precompute distance matrix (expensive)
    strategy.distance_matrix = compute_distances(sim.stations, sim.net)
    
    # Train ML model (expensive)  
    strategy.model = train_model(sim.hospitals, sim.stations)
    
    @info "Strategy initialized with distance matrix and trained model"
end
```
"""
function initialize_strategy!(strategy::AbstractMoveUpStrategy, sim::JEMSS.Simulation)
    # Default implementation: do nothing
    return nothing
end

"""
    copy_strategy(strategy::AbstractMoveUpStrategy) -> AbstractMoveUpStrategy

Create a deep copy of the strategy, preserving all initialization state.

This method is used for strategy replication when running multiple simulations
with the same base strategy but different parameters. The copied strategy should
preserve all expensive precomputations from initialization while allowing parameter
modifications.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The strategy to copy

# Returns
- `AbstractMoveUpStrategy`: A deep copy of the strategy with preserved initialization state

# Implementation Requirements
- This method must be implemented by strategies that support replication
- Should create a complete independent copy of the strategy
- Must preserve all precomputed data (distance matrices, models, etc.)
- The copy should be safe to modify without affecting the original

# Example
```julia
function copy_strategy(strategy::MyMLStrategy)
    copied = MyMLStrategy()
    copied.model = deepcopy(strategy.model)  # Preserve trained model
    copied.distance_matrix = copy(strategy.distance_matrix)  # Preserve distances
    copied.learning_rate = strategy.learning_rate  # Copy parameters
    return copied
end
```
"""
function copy_strategy(strategy::AbstractMoveUpStrategy)
    error("copy_strategy not implemented for $(typeof(strategy)). " *
          "Strategies that support replication must implement this method.")
end

"""
    update_parameters!(strategy::AbstractMoveUpStrategy, params::Dict{String, Any}) -> Nothing

Update strategy parameters, performing selective re-precomputation as needed.

This method allows modifying strategy parameters after initialization. Depending on which
parameters are changed, the strategy may need to re-precompute some data while preserving
other expensive computations. Used for parameter sweeps and experiments where only specific
parameters change between runs.

# Arguments
- `strategy::AbstractMoveUpStrategy`: The strategy to update (modified in-place)
- `params::Dict{String, Any}`: Dictionary of parameter names and their new values

# Implementation Requirements
- This method must be implemented by strategies that support parameter updates
- Should validate parameter names and types
- Should update parameters in-place
- May trigger selective re-precomputation for parameter-dependent data
- Should preserve expensive precomputations that don't depend on changed parameters
- Should handle unknown parameters gracefully (warn or error)

# Performance Considerations
- Light parameters (thresholds, weights): Update directly, no re-computation needed
- Heavy parameters (model architecture, distance metrics): May require partial re-computation
- The goal is to be more efficient than full re-initialization while maintaining correctness

# Example
```julia
function update_parameters!(strategy::MyMLStrategy, params::Dict{String, Any})
    recompute_needed = false
    
    for (key, value) in params
        if key == "learning_rate"
            strategy.learning_rate = Float64(value)
            # No re-computation needed for learning rate
        elseif key == "distance_metric"
            strategy.distance_metric = value
            recompute_needed = true  # Distance matrix needs update
        elseif key == "threshold"
            strategy.threshold = Float64(value)
            # No re-computation needed for threshold
        else
            @warn "Unknown parameter for MyMLStrategy: \$key"
        end
    end
    
    # Selective re-precomputation
    if recompute_needed && !isnothing(strategy.sim_reference)
        @info "Re-computing distance matrix due to metric change"
        strategy.distance_matrix = compute_distance_matrix(
            strategy.sim_reference.stations, 
            strategy.distance_metric
        )
    end
end
```
"""
function update_parameters!(strategy::AbstractMoveUpStrategy, params::Dict{String, Any})
    error("update_parameters! not implemented for $(typeof(strategy)). " *
          "Strategies that support parameter updates must implement this method.")
end

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

"""
    validate_moveup_decision(movable_ambulances::Vector{JEMSS.Ambulance}, 
                            target_stations::Vector{JEMSS.Station}) -> Bool

Validate that a move-up decision is well-formed.

# Arguments
- `movable_ambulances::Vector{JEMSS.Ambulance}`: Ambulances to move
- `target_stations::Vector{JEMSS.Station}`: Target stations

# Returns
- `Bool`: `true` if the decision is valid, `false` otherwise

# Validation checks
- Vectors have the same length
- No ambulance is assigned to its current station (redundant moves)
- All ambulances are eligible for move-up
"""
function validate_moveup_decision(movable_ambulances::Vector{JEMSS.Ambulance}, 
                                 target_stations::Vector{JEMSS.Station})
    # Check vector lengths match
    if length(movable_ambulances) != length(target_stations)
        @warn "Movable ambulances and target stations vectors have different lengths"
        return false
    end
    
    # Check for redundant moves (ambulance already at target station)
    for i in eachindex(movable_ambulances)
        if movable_ambulances[i].stationIndex == target_stations[i].index
            @warn "Redundant move detected: ambulance $(movable_ambulances[i].index) already at station $(target_stations[i].index)"
            return false
        end
    end
    
    # Check ambulance eligibility (basic check - could be extended)
    for ambulance in movable_ambulances
        if !(ambulance.status == JEMSS.ambIdleAtStation || 
             JEMSS.isGoingToStation(ambulance.status) ||
             (ambulance.status == JEMSS.ambFreeAfterCall && ambulance.event.form == JEMSS.ambReturnsToStation))
            @warn "Ambulance $(ambulance.index) is not eligible for move-up (status: $(ambulance.status))"
            return false
        end
    end
    
    return true
end

end # module MoveUp