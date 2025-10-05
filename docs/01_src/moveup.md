# MoveUp Module

```@meta
CurrentModule = JEMSSWrapper
```

## Overview

The MoveUp module provides an abstract interface for implementing move-up strategies in JEMSS simulations. Move-up strategies determine when and how ambulances should be repositioned to improve system coverage and response times.

All move-up strategies must inherit from `AbstractMoveUpStrategy` and implement the required interface methods for triggering and decision-making.


## Abstract Types

```@docs
MoveUp.AbstractMoveUpStrategy
```

## Core Interface Methods

These methods must be implemented by all concrete move-up strategies:

### Triggering Methods

```@docs
MoveUp.should_trigger_on_dispatch
MoveUp.should_trigger_on_free
```

### Decision Method

```@docs
MoveUp.decide_moveup
```

## Utility Functions

Helper functions for validating move-up decisions:

```@docs
MoveUp.validate_moveup_decision
```

## Implementation Example

Here's a basic example of how to implement a concrete move-up strategy:

```julia
struct MyMoveUpStrategy <: AbstractMoveUpStrategy
    coverage_threshold::Float64
    max_moves::Int
    precomputed_data::Dict{String, Any}
    
    # Constructor
    MyMoveUpStrategy(threshold=0.8, max_moves=3) = new(threshold, max_moves, Dict())
end

function should_trigger_on_dispatch(strategy::MyMoveUpStrategy, sim::JEMSS.Simulation)
    # Trigger move-up when coverage drops below threshold
    current_coverage = calculate_coverage(sim)
    return current_coverage < strategy.coverage_threshold
end

function should_trigger_on_free(strategy::MyMoveUpStrategy, sim::JEMSS.Simulation)
    # Only trigger if there are no queued calls
    return length(sim.callQueue) == 0
end

function decide_moveup(strategy::MyMoveUpStrategy, sim::JEMSS.Simulation, 
                      triggering_ambulance::JEMSS.Ambulance)
    # Your move-up decision logic here
    movable_ambulances = find_movable_ambulances(sim, strategy.max_moves)
    target_stations = find_optimal_stations(sim, movable_ambulances)
    
    return (movable_ambulances, target_stations)
end
```

## Usage in Simulations

To use a move-up strategy in your JEMSS simulation:

```julia
# Create your strategy
strategy = MyMoveUpStrategy(coverage_threshold=0.75, max_moves=5)

# Create simulation instance with the strategy
sim_instance = create_simulation_instance_with_strategy(scenario_data, strategy)

# Run simulation
results = simulate_custom!(sim_instance)
```

## Index

```@index
Pages = ["moveup.md"]
Module = JEMSSWrapper
```