# Strategy Development Guide

Learn how to develop ambulance relocation strategies using JEMSSWrapper's extensible framework.

---

## Table of Contents

- [Undestanding Dynamic Relocation](#understanding-dynamic-relocation)
- [How Strategies Work in JEMSSWrapper](#how-strategies-work-in-jemsswrapper)
- [The Strategy Interface](#the-strategy-interface)
- [Working with Simulation State](#working-with-simulation-state)
---

## Understanding Dynamic Relocation

### What is Dynamic Ambulance Relocation?

Dynamic ambulance relocation (or **move-up**) is the strategic repositioning of available ambulances in response to changes in system state, typically when a unit is dispatched or completes a mission.

### The Core Problem

When an ambulance is dispatched, coverage in its origin area degrades, potentially leaving populations vulnerable to future emergencies. However, every relocation has costs:

- **Tangible costs**: Fuel, travel time, operational expenses
- **Intangible costs**: Staff fatigue, reduced availability during movement

### The Decision Challenge

Optimal relocation strategies must balance:

1. **Expected benefit** of improved coverage
2. **Associated costs** of moving ambulances
3. **Probability** of future demands
4. **Expected time** until busy units return to service

Unlike multi-period relocation that plans hours ahead, dynamic relocation must make **instantaneous decisions** in response to real-time events with inherent uncertainty.

---

## How Strategies Work in JEMSSWrapper

Strategies control two key aspects:

1. **When** to consider relocations (trigger conditions)
2. **Which** ambulances to move and **where** to send them

### The Strategy Interface

Every strategy implements three methods:

```julia
using JEMSSWrapper

struct MyStrategy <: AbstractMoveUpStrategy end

# Trigger on dispatch events?
JEMSSWrapper.should_trigger_on_dispatch(::MyStrategy, sim) = true

# Trigger on free events?
JEMSSWrapper.should_trigger_on_free(::MyStrategy, sim) = false

# Decide relocations
function JEMSSWrapper.decide_moveup(::MyStrategy, sim, amb)
    return ([], [], [])  # (ambulances_to_move, target_stations, metadata_decision)
end
```

**Test it:**

```julia
scenario = load_scenario_from_config("auckland", "config.toml")
sim = simulate_scenario!(sim; moveup_strategy=MyStrategy())
```

---

## Strategy Basic Example

Respond when ambulances become free by filling coverage gaps:

```julia
struct FillEmptyStations <: AbstractMoveUpStrategy end

should_trigger_on_dispatch(::FillEmptyStations, sim) = false
should_trigger_on_free(::FillEmptyStations, sim) = true

function decide_moveup(::FillEmptyStations, sim, freed_amb)
    # Find first empty station
    for station in sim.stations
        ambs_here = count(
            a -> a.status == ambulanceFree && a.station == station,
            sim.ambulances
        )
        if ambs_here == 0
            return ([freed_amb], [station])
        end
    end
    
    return ([], [])  # All stations covered
end
```

---

## Working with Simulation State

JEMSSWrapper provides two main functions to extract information from a running simulation:

### `get_entity_property`
Retrieves a specific property from a single entity. Handles special cases automatically (e.g., ambulance locations that require route updates).
```julia
# Get ambulance status
status = get_entity_property(sim, :ambulances, 1, :status)

# Get station location
location = get_entity_property(sim, :stations, 2, :location)
```

### `get_all_entity_properties`
Retrieves the same property from all entities in a collection. Uses optimized batch operations when available.
```julia
# Get all ambulance statuses
statuses = get_all_entity_properties(sim, :ambulances, :status)

# Get all hospital locations
locations = get_all_entity_properties(sim, :hospitals, :location)
```

Both functions work with the main entity collections: `:ambulances`, `:stations`, `:hospitals`, and `:calls`.

> **For complete details** about all available state, enums, structures and how to extract information from them see the [Simulation State Reference](@ref).

---

## See also 

Now that you understand how to write strategies, explore:

- **[Simulation State Reference](@ref)** - Complete details on all available state
- **[Neural Network Strategy](@ref)** - Relocation strategy with neural networks 
- **[API Reference](@ref)** - Complete function documentation
