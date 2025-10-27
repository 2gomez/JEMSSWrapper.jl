# Simulation State Reference

Complete technical reference for accessing and understanding the simulation state when implementing move-up strategies in JEMSSWrapper.

> **Note**: This page documents the core data structures from [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl) that are accessible in move-up strategies.

---

## Table of Contents

- [Overview](#overview)
- [Simulation Structure](#simulation-structure)
- [Entities and Attributes](#entities-and-attributes)
- [Enumerations](#enumerations)
- [Accessing State Information](#accessing-state-information)
- [Advanced Access](#advanced-access)

---

## Overview

When implementing a move-up strategy, your `decide_moveup` function receives a `sim::Simulation` object containing the complete state of the emergency medical system. This state can be accessed using the utility functions described below, which handle special cases and optimizations automatically.
```julia
function decide_moveup(strategy::MyStrategy, sim, ambulance)
    # Use get_entity_property and get_all_entity_properties
    # to safely access simulation state
    
    # Your decision logic...
end
```

---

## Simulation Structure

JEMSS works with a `Simulation` object that contains all the simulation state:
```julia
mutable struct Simulation
    # Time
    startTime::Float
    time::Float
    endTime::Float

    # World
    net::Network
    travel::Travel
    map::Map
    grid::Grid

    # Main entities 
    ambulances::Vector{Ambulance}
    calls::Vector{Call}
    hospitals::Vector{Hospital}
    stations::Vector{Station}

    # Convenience:
    numAmbs::Int
    numCalls::Int
    numHospitals::Int
    numStations::Int

    ...

    # Other important fields 
    mobilisationDelay::MobilisationDelay
    demand::Demand
    demandCoverage::DemandCoverage
    stats::SimStats

    ...

    Simulation() = new(nullTime, nullTime, nullTime, ...)
end
```

> **Complete struct**: [Simulation struct in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)

---

## Entities and Attributes

| Entity | Attribute | Type | Description |
|--------|-----------|------|-------------|
| **Ambulance** | `index` | Int | Unique ambulance identifier |
| | `status` | AmbStatus | Operational state (see Ambulance States) |
| | `stationIndex` | Int | Assigned base station ID |
| | `callIndex` | Int | Currently assigned call ID (if applicable) |
| | `class` | AmbClass | Ambulance type (see Ambulance Classes) |
| | `route.startLoc` | Location | Route start location |
| | `route.endLoc` | Location | Route destination location |
| | `route.startTime` | Float | Route start time (days) |
| | `route.endTime` | Float | Route end time (days) |
| | `route.priority` | Priority | Travel priority level (see Priority Levels) |
| **Call** | `index` | Int | Unique call identifier |
| | `location` | Location | Emergency location (lat/lon coordinates) |
| | `priority` | Priority | Priority level (see Priority Levels) |
| | `transport` | Bool | Whether hospital transport is required |
| | `hospitalIndex` | Int | Destination hospital ID (if applicable) |
| **Station** | `index` | Int | Unique identifier |
| | `location` | Location | Station location (lat/lon coordinates) |
| | `capacity` | Int | Maximum ambulance capacity |
| **Hospital** | `index` | Int | Unique identifier |
| | `location` | Location | Hospital location (lat/lon coordinates) |
| **Global State** | `time` | Float | Current simulation time (days from start) |
| | `startTime` | Float | Simulation start time |
| | `endTime` | Float | Simulation end time |

> **Note:** 
> - `Location` objects contain `x` (longitude) and `y` (latitude) coordinates in decimal degrees.
> - Ambulance route information is only valid when actively traveling (states 3, 5, 8, 9).
> - From an ambulance's `route`, you can extract its current position and estimated time of arrival (ETA) to destination.
> - When idle at a station, ambulance location corresponds to `stations[stationIndex].location`.
> - Use `get_entity_property(sim, :ambulances, id, :location)` for automatic position calculation.

---

## Enumerations

JEMSS defines several enumeration types to represent categorical states and properties in the simulation. These enumerations provide type-safe identifiers for ambulance classes, priority levels, and operational states.

> **Complete definitions**: [defs.jl in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/defs.jl)


### Ambulance Classes

| Value | Description |
|-------|-------------|
| `als` | Advanced Life Support - Paramedics with advanced medical capabilities |
| `bls` | Basic Life Support - Emergency Medical Technicians with basic care |

### Priority Levels

| Value | Level | Description |
|-------|-------|-------------|
| `lowPriority` | 3 | Non-urgent cases |
| `medPriority` | 2 | Moderate urgency |
| `highPriority` | 1 | Critical, life-threatening emergencies |


### Ambulance States

| Value | ID | Description |
|-------|-----|-------------|
| `ambNullStatus` | 0 | Null/undefined state |
| `ambIdleAtStation` | 1 | At station, available for dispatch |
| `ambMobilising` | 2 | Preparing to depart |
| `ambGoingToCall` | 3 | En route to emergency |
| `ambAtCall` | 4 | On scene attending to patient |
| `ambGoingToHospital` | 5 | Transporting patient to hospital |
| `ambAtHospital` | 6 | At hospital (patient transfer) |
| `ambFreeAfterCall` | 7 | Just finished call, ready for next assignment |
| `ambReturningToStation` | 8 | Returning to base station |
| `ambMovingUpToStation` | 9 | Relocating to another station (move-up) |
| `ambSleeping` | 10 | Out of service |

### Call States

| Value | ID | Description |
|-------|-----|-------------|
| `callNullStatus` | 0 | Null/undefined state |
| `callScreening` | 1 | Under initial evaluation |
| `callQueued` | 2 | In queue, waiting for assignment |
| `callWaitingForAmb` | 3 | Assigned, waiting for ambulance arrival |
| `callOnSceneTreatment` | 4 | Ambulance on scene, treating patient |
| `callGoingToHospital` | 5 | Patient being transported |
| `callAtHospital` | 6 | Patient transfer at hospital |
| `callProcessed` | 7 | Incident completed and closed |

---

## Accessing State Information

JEMSSWrapper provides two main utility functions to access simulation state safely and efficiently, handling special cases automatically.

### `get_entity_property` - Single Entity Access

Retrieves a specific property from one entity. This is the recommended way to access entity data as it handles special cases automatically.
```julia
get_entity_property(sim, collection, id, property_name)
```

**Arguments:**
- `sim::Simulation`: The simulation instance
- `collection::Symbol`: Entity type (`:ambulances`, `:stations`, `:hospitals`, `:calls`)
- `id::Int`: Entity identifier (1-indexed)
- `property_name::Symbol`: Property to retrieve

**Basic Examples:**
```julia
# Ambulance properties
status = get_entity_property(sim, :ambulances, 1, :status)
class = get_entity_property(sim, :ambulances, 1, :class)
station = get_entity_property(sim, :ambulances, 1, :stationIndex)

# Station properties
location = get_entity_property(sim, :stations, 5, :location)
capacity = get_entity_property(sim, :stations, 5, :capacity)

# Hospital properties
hospital_loc = get_entity_property(sim, :hospitals, 2, :location)

# Call properties
priority = get_entity_property(sim, :calls, 10, :priority)
transport = get_entity_property(sim, :calls, 10, :transport)
```

**Special Ambulance Properties:**

For ambulances, three computed properties have special handling:
```julia
# Current location (automatically updates route state)
location = get_entity_property(sim, :ambulances, 1, :location)

# Destination location (route.endLoc)
destination = get_entity_property(sim, :ambulances, 1, :destination)

# Estimated time of arrival in days (negative if overdue)
eta = get_entity_property(sim, :ambulances, 1, :eta)
```

### `get_all_entity_properties` - Batch Access

Retrieves the same property from all entities in a collection. Uses optimized batch operations for ambulance special properties.
```julia
get_all_entity_properties(sim, collection, property_name)
```

**Arguments:**
- `sim::Simulation`: The simulation instance
- `collection::Symbol`: Entity type (`:ambulances`, `:stations`, `:hospitals`, `:calls`)
- `property_name::Symbol`: Property to retrieve

**Returns:** Vector containing the property value for each entity.

**Examples:**
```julia
# All ambulance statuses
statuses = get_all_entity_properties(sim, :ambulances, :status)

# All ambulance locations (batch route updates)
locations = get_all_entity_properties(sim, :ambulances, :location)

# All ambulance destinations
destinations = get_all_entity_properties(sim, :ambulances, :destination)

# All ambulance ETAs
etas = get_all_entity_properties(sim, :ambulances, :eta)

# All station locations
station_locs = get_all_entity_properties(sim, :stations, :location)

# All call priorities
priorities = get_all_entity_properties(sim, :calls, :priority)
```

### Usage in Move-Up Strategies

These functions are particularly useful when implementing custom strategies:
```julia
function decide_moveup(strategy::MyStrategy, sim, ambulance)
    # Get all ambulance locations efficiently
    all_locations = get_all_entity_properties(sim, :ambulances, :location)
    
    # Get specific ambulance destination
    my_destination = get_entity_property(sim, :ambulances, ambulance.index, :destination)
    
    # Check ETAs for all ambulances
    all_etas = get_all_entity_properties(sim, :ambulances, :eta)
    
    # Get all station locations
    station_locs = get_all_entity_properties(sim, :stations, :location)
    
    # Your decision logic here...
    return target_station_index
end
```

---

## Advanced Access

While `get_entity_property` and `get_all_entity_properties` cover most common use cases, advanced strategies can access other simulation components directly. This includes time information (`sim.time`, `sim.startTime`, `sim.endTime`), spatial data structures (`sim.net`, `sim.travel`, `sim.map`, `sim.grid`), entity counts (`sim.numAmbs`, `sim.numStations`, etc.), and other components like `sim.mobilisationDelay`, `sim.demand`, and `sim.stats`. Direct access is useful for strategies requiring network analysis, spatial computations, or custom metrics beyond basic entity properties.

> **For implementation details** of these data structures, refer to the [JEMSS.jl source code](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl).

---

## See Also

- **[Strategy Development Guide](@ref)** - Practical guide with examples
- **[JEMSS.jl Repository](https://github.com/uoa-ems-research/JEMSS.jl)** - Original simulator
- **[API Reference](@ref)** - JEMSSWrapper functions
