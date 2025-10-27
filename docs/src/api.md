# API Reference

This page documents all public functions, types, and interfaces in JEMSSWrapper.jl.

## Table of Contents

- [Scenario Management](#scenario-management) - Load and configure scenarios
- [Simulation Execution](#simulation-execution) - Run simulations with custom strategies
- [Metrics System](#metrics-system) - Extract and analyze simulation metrics
- [Strategy Interface](#strategy-interface) - Implement custom move-up strategies
- [Encoding Interface](#encoding-interface) - State encoding for ML applications
- [Logging System](#logging-system) - Track move-up decisions
- [State Access Utilities](#state-access) - Query simulation state
- [Built-in Strategies](#built-in-strategies) - Ready-to-use implementations
- [Core Data Types](#data-types) - Core structures
- [JEMSS Access](#jemss-access) - Direct access to JEMSS framework

---

## Scenario Management

Load simulation scenarios from configuration files and modify them programmatically.
```@docs
load_scenario_from_config
```

### Modifying Scenarios
```@docs
update_scenario_calls
update_scenario_ambulances
```

---

## Simulation Execution

Execute simulations with custom or built-in strategies.
```@docs
simulate_scenario
```

---

## Metrics System

Extract and analyze performance metrics from simulation results.
```@docs
extract_all_metrics
get_metric
```

---

## Strategy Interface

Implement custom ambulance relocation policies by inheriting from `AbstractMoveUpStrategy` and implementing the required methods. 

### Base Type
```@docs
AbstractMoveUpStrategy
```

### Required Interface Methods
```@docs
should_trigger_on_dispatch
should_trigger_on_free
decide_moveup
initialize_strategy
```

---

## Neuronal Strategy 

### Encoder 
```@docs
AbstractEncoder
encode_state
```

### Neural Network 
```@docs
AbstractNeuralNetwork
forward
```

### Strategy
```@docs
NeuronalStrategy
```

---

## Logging System

Track and analyze move-up decisions during simulations.
```@docs
MoveUpLogger
get_entries
clear_log!
to_dataframe
```

---

## State Access

Utilities for querying the current state of simulation entities. These functions are designed to be used within custom move-up strategies, for post-simulation analysis, or for state encoding in machine learning applications.
```@docs
get_entity_property
get_all_entity_properties
```

---

## Data Types

Core data structures used throughout JEMSSWrapper.
```@docs
ScenarioData
```