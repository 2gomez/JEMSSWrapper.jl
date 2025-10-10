# API Reference

This page documents all public functions, types, and interfaces in JEMSSWrapper.jl.

## Quick Navigation

- [Scenario Management](@ref) - Load and configure scenarios
- [Simulation Execution](@ref) - Run simulations
- [Strategy Interface](@ref) - Implement custom strategies
- [State Access](@ref) - Query simulation state
- [Data Types](@ref) - Core structures

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

Create simulation instances and run them with custom strategies.

```@docs
create_simulation_instance
simulate_custom!
```

---

## Strategy Interface

Implement custom ambulance relocation policies by inheriting from `AbstractMoveUpStrategy` and implementing the required methods.  See the [Strategy Development Guide](@ref) for tutorials and examples.

### Base Type

```@docs
AbstractMoveUpStrategy
```

### Required Interface

```@docs
should_trigger_on_dispatch
should_trigger_on_free
decide_moveup
```

## State Access

Utilities for querying the current state of simulation entities. These functions are designed
to be used within custom move-up strategies, for post-simulation analysis, or for state encoding
in machine learning applications.

```@docs
get_entity_property
get_all_entity_properties
```

---

## Data Types

```@docs
ScenarioData
```