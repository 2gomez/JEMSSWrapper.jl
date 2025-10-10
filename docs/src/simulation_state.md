# Simulation State Reference

Complete technical reference for accessing and understanding the simulation state when implementing move-up strategies in JEMSSWrapper.

> **Note**: This page documents the core data structures from [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl) that are accessible in move-up strategies.

## Overview

When implementing a move-up strategy, your `decide_moveup` function receives a `sim::Simulation` object containing the complete state of the emergency medical system:

```julia
function decide_moveup(strategy::MyStrategy, sim, ambulance)
    # Access complete system state
    sim.ambulances    # All ambulances
    sim.stations      # All stations
    sim.hospitals     # All hospitals
    sim.time          # Current simulation time
    
    # Your decision logic...
end
```

---

## Simulation

The main container for all simulation state.

```julia
# Essential fields
sim.time              # Current simulation time (Float, in days)
sim.ambulances        # Vector{Ambulance} - all ambulances
sim.stations          # Vector{Station} - all stations
sim.hospitals         # Vector{Hospital} - all hospitals
sim.calls             # Vector{Call} - all emergency calls

# Convenience accessors
sim.numAmbs           # Int - number of ambulances
sim.numStations       # Int - number of stations
sim.numHospitals      # Int - number of hospitals
sim.numCalls          # Int - number of calls
```

### Advanced Fields

For advanced strategies requiring travel time calculations or coverage analysis:

- `sim.net::Network` - Road network graph
- `sim.travel::Travel` - Travel time and distance calculations
- `sim.grid::Grid` - Spatial grid for coverage
- `sim.demand::Demand` - Demand modeling

> **Complete details**: [Simulation struct in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)

---

## Ambulance

Represents an emergency response vehicle.

### Core Fields

```julia
# Identity
ambulance.index              # Int - unique identifier (1-based)
ambulance.class              # AmbClass - als or bls

# Current state
ambulance.status             # AmbStatus - operational status
ambulance.stationIndex       # Int - home station index
ambulance.callIndex          # Int - assigned call (if any)

# Location
ambulance.currentLoc         # Location - current position
ambulance.destLoc            # Location - destination

# Useful statistics
ambulance.numMoveUps         # Int - total relocations
ambulance.numDispatches      # Int - total dispatches
ambulance.dispatchTime       # Float - when dispatched to current call
```

The `ambulance.currentLoc` is not computed online. Each time you want to known the exact location of the vehicle, it is needed to compute it.

### Ambulance Status

The `status` field indicates what the ambulance is currently doing:

```julia
ambIdleAtStation       # At station, ready for dispatch ✓
ambMobilising          # Preparing to depart
ambGoingToCall         # En route to emergency
ambAtCall              # On scene with patient
ambGoingToHospital     # Transporting patient
ambAtHospital          # At hospital (handover)
ambFreeAfterCall       # Just finished call ✓
ambReturningToStation  # Going back to station
ambMovingUpToStation   # Relocating (move-up)
ambSleeping            # Off duty
```

**For move-up**: Only consider ambulances with status `ambIdleAtStation` or `ambFreeAfterCall`.

### Ambulance Class

```julia
@enum AmbClass begin
    als  # Advanced Life Support (paramedics)
    bls  # Basic Life Support (EMTs)
end
```

> **Complete details**: [Ambulance struct in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)

---

## Station

Represents an ambulance station.

### Core Fields

```julia
# Identity and location
station.index                # Int - unique identifier
station.location             # Location - geographic position
station.capacity             # Int - maximum ambulances

# Real-time state
station.currentNumIdleAmbs   # Int - current idle ambulances
station.currentNumIdleAmbsSetTime  # Float - when last updated

# Network data
station.nearestNodeIndex     # Int - closest road network node
station.nearestNodeDist      # Float - distance to nearest node
```

> **Complete details**: [Station struct in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)

---

## Hospital

Represents a hospital that receives patients.

### Core Fields

```julia
# Identity and location
hospital.index               # Int - unique identifier
hospital.location            # Location - geographic position

# Statistics
hospital.numCalls            # Int - total calls received

# Network data
hospital.nearestNodeIndex    # Int - closest road network node
hospital.nearestNodeDist     # Float - distance to nearest node
```

> **Complete details**: [Hospital struct in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)

---

## Call

Represents an emergency call. While not directly used in `decide_moveup()`, understanding calls helps with demand-aware strategies.

### Core Fields

```julia
call.index                   # Int - unique identifier
call.priority                # Priority - urgency level
call.location                # Location - emergency location
call.arrivalTime             # Float - when call came in
call.dispatchTime            # Float - when ambulance dispatched
call.responseTime            # Float - time to reach scene
```

### Call Priority

```julia
@enum Priority begin
    lowPriority     # Non-urgent
    medPriority     # Moderate urgency
    highPriority    # Critical
end
```

> **Complete details**: [Call struct in JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)

---

## Accessing State in Strategies

JEMSSWrapper provides convenient utility functions to access simulation state without dealing with internal details.

### Single Entity Properties
```julia
# Get any property from a specific entity
property = get_entity_property(sim, collection, id, property_name)

# Examples:
status = get_entity_property(sim, :ambulances, 1, :status)
location = get_entity_property(sim, :ambulances, 1, :location)  # Auto-updates route!
station_loc = get_entity_property(sim, :stations, 5, :location)
hospital_loc = get_entity_property(sim, :hospitals, 2, :location)
```

### All Entities at Once
```julia
# Get a property from all entities in a collection
properties = get_all_entity_properties(sim, collection, property_name)

# Examples:
all_statuses = get_all_entity_properties(sim, :ambulances, :status)
all_locations = get_all_entity_properties(sim, :ambulances, :location)
station_locations = get_all_entity_properties(sim, :stations, :location)
```

### Essential Fields Cheat Sheet

```julia
# Simulation
sim.time              # Current time (Float, days)
sim.ambulances        # All ambulances
sim.stations          # All stations
sim.numAmbs           # Number of ambulances

# Ambulance
amb.index             # Unique ID
amb.status            # AmbStatus enum
amb.stationIndex      # Home station
amb.class             # als or bls
amb.currentLoc        # Current location
amb.destLoc           # Destionation location

# Station
station.index         # Unique ID
station.location      # Position
station.capacity      # Max ambulances
station.currentNumIdleAmbs  # Current idle count

# Hospitals
hospital.index        # Unique ID
hospital.location     # Position
```

## See Also

- **[Strategy Development Guide](@ref)** - Practical guide with examples
- **[JEMSS.jl Repository](https://github.com/uoa-ems-research/JEMSS.jl)** - Original simulator
- **[JEMSS Types](https://github.com/uoa-ems-research/JEMSS.jl/blob/master/src/types/types.jl)** - Complete struct definitions
- **[API Reference](@ref)** - JEMSSWrapper functions
