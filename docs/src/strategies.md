# Strategy Development Guide

Learn how to develop intelligent ambulance relocation strategies using JEMSSWrapper's extensible framework.

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
    return ([], [])  # (ambulances_to_move, target_stations)
end
```

**Test it:**

```julia
scenario = load_scenario_from_config("test", "config.toml")
sim = create_simulation_instance(scenario)
simulate_custom!(sim; moveup_strategy=MyStrategy())
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

Your strategy has full access to the simulation state through the `sim` object:

```julia
sim.ambulances    # Vector of all ambulances
sim.stations      # Vector of all stations  
sim.hospitals     # Vector of all hospitals
sim.time          # Current simulation time
sim.numAmbs       # Number of ambulances (convenience)
sim.numStations   # Number of stations (convenience)
```

> **For complete details** about all available state, enums, and structures, see the [Simulation State Reference](@ref).

---

## Common Mistakes

### ❌ Moving Busy Ambulances

```julia
# WRONG - might move busy ambulances
all_ambs = sim.ambulances
return ([all_ambs[1]], [target_station])

# CORRECT - check status first
idle_ambs = filter(a -> a.status == ambIdleAtStation, sim.ambulances)
if !isempty(idle_ambs)
    return ([idle_ambs[1]], [target_station])
end
```

### ❌ Mismatched Vector Lengths

```julia
# WRONG - 2 ambulances, 1 station
return ([amb1, amb2], [station1])

# CORRECT - matching lengths
return ([amb1, amb2], [station1, station2])
```

### ❌ Incorrect Return Type

```julia
# WRONG - returning nothing
if no_relocations_needed
    return nothing
end

# CORRECT - always return tuple of vectors
if no_relocations_needed
    return ([], [])
end
```

---

## Next Steps

Now that you understand how to write strategies, explore:

- **[Simulation State Reference](@ref)** - Complete details on all available state
- **[Strategy Examples]()** - More real-world implementations
- **[API Reference](@ref)** - Complete function documentation
- **[Benchmarking Guide]()** - Evaluate strategy performance
