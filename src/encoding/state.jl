"""
    get_entity_property(sim::JEMSS.Simulation, collection::Symbol, id::Int, property::Symbol)

Get a specific property from a single entity in a simulation.

This is the core generic accessor for simulation entities. It handles special cases
automatically (e.g., ambulance locations that require route updates) and provides 
unified access to any entity property.

# Arguments
- `sim::JEMSS.Simulation`: The simulation instance
- `collection::Symbol`: Entity collection name (`:ambulances`, `:stations`, `:hospitals`, `:calls`)
- `id::Int`: Entity ID (1-indexed)
- `property::Symbol`: Property to retrieve (`:status`, `:class`, `:location`, `:destination`, `:eta`, etc.)

# Returns
The value of the requested property for the specified entity.

# Special Behavior
- **Ambulance locations**: Automatically updates route state before returning location
- **Ambulance destinations**: Returns the end location of the current route
- **Ambulance ETA**: Returns time remaining until destination (negative if overdue)
- **Other properties**: Direct property access without side effects

# Throws
- `AssertionError`: If the entity ID is out of bounds for the collection

# Examples
```julia
# Get ambulance properties
status = get_entity_property(sim, :ambulances, 1, :status)
class = get_entity_property(sim, :ambulances, 1, :class)
location = get_entity_property(sim, :ambulances, 1, :location)      # Updates route
destination = get_entity_property(sim, :ambulances, 1, :destination)
eta = get_entity_property(sim, :ambulances, 1, :eta)

# Get station/hospital locations
station_loc = get_entity_property(sim, :stations, 2, :location)
hospital_loc = get_entity_property(sim, :hospitals, 1, :location)

# Get call properties
priority = get_entity_property(sim, :calls, 5, :priority)
```
"""
function get_entity_property(sim::JEMSS.Simulation, collection::Symbol, id::Int, property::Symbol)
    # Special handling for ambulance-specific computed properties
    if collection == :ambulances
        if property == :location
            return get_ambulance_location!(sim, id)
        elseif property == :destination
            return get_ambulance_destination(sim, id)
        elseif property == :eta
            return get_ambulance_eta(sim, id)
        end
    end
    
    # Default: direct property access
    entities = getproperty(sim, collection)
    @assert 1 ≤ id ≤ length(entities) "Invalid $collection ID: $id (max: $(length(entities)))"
    return getproperty(entities[id], property)
end

"""
    get_all_entity_properties(sim::JEMSS.Simulation, collection::Symbol, property::Symbol)

Get a specific property from all entities in a collection.

This is a convenience function that applies [`get_entity_property`](@ref) to all entities
in the specified collection. For ambulance-specific properties (`:location`, `:destination`, `:eta`),
it uses optimized batch functions.

# Arguments
- `sim::JEMSS.Simulation`: The simulation instance
- `collection::Symbol`: Entity collection name (`:ambulances`, `:stations`, `:hospitals`, `:calls`)
- `property::Symbol`: Property to retrieve

# Returns
- `Vector`: Array containing the property value for each entity in the collection

# Performance Notes
- Uses specialized batch functions for ambulance locations, destinations, and ETAs
- For other properties, uses vectorized property access

# Examples
```julia
# Get all ambulance properties
statuses = get_all_entity_properties(sim, :ambulances, :status)
locations = get_all_entity_properties(sim, :ambulances, :location)      # Batch route updates
destinations = get_all_entity_properties(sim, :ambulances, :destination)
etas = get_all_entity_properties(sim, :ambulances, :eta)

# Get all station/hospital locations
station_locs = get_all_entity_properties(sim, :stations, :location)
hospital_locs = get_all_entity_properties(sim, :hospitals, :location)

# Get all call priorities
priorities = get_all_entity_properties(sim, :calls, :priority)
```
"""
function get_all_entity_properties(sim::JEMSS.Simulation, collection::Symbol, property::Symbol)
    # Special handling for ambulance-specific computed properties
    if collection == :ambulances
        if property == :location
            return get_ambulances_locations!(sim)
        elseif property == :destination
            return get_ambulances_destinations(sim)
        elseif property == :eta
            return get_ambulances_eta(sim)
        end
    end
    
    # Default: vectorized property access
    entities = getproperty(sim, collection)
    return [getproperty(entity, property) for entity in entities]
end

"""
    get_ambulance_location!(sim::JEMSS.Simulation, ambulance_id::Int)

Get current location of an ambulance (updates route state).

Called automatically by get_entity_property when accessing ambulance location.
"""
function get_ambulance_location!(sim::JEMSS.Simulation, ambulance_id::Int)::JEMSS.Location
    @assert 1 ≤ ambulance_id ≤ sim.numAmbs "Invalid ambulance ID: $ambulance_id"
    return JEMSS.getRouteCurrentLocation!(sim.net, sim.ambulances[ambulance_id].route, sim.time)
end
"""
    get_ambulances_locations!(sim::JEMSS.Simulation)

Get current locations of all ambulances.
"""
function get_ambulances_locations!(sim::JEMSS.Simulation)::Vector{JEMSS.Location}
    return [get_ambulance_location!(sim, i) for i in 1:sim.numAmbs]
end

"""
    get_ambulance_destination(sim::JEMSS.Simulation, ambulance_id::Int) -> JEMSS.Location

Get the destination location for a specific ambulance.
"""
function get_ambulance_destination(sim::JEMSS.Simulation, ambulance_id::Int)::JEMSS.Location
    @assert 1 ≤ ambulance_id ≤ sim.numAmbs "Invalid ambulance ID: $ambulance_id"
    return sim.ambulances[ambulance_id].route.endLoc
end

"""
    get_ambulances_destinations(sim::JEMSS.Simulation) -> Vector{JEMSS.Location}

Get destination locations for all ambulances in the simulation.
"""
function get_ambulances_destinations(sim::JEMSS.Simulation)::Vector{JEMSS.Location}
    return [get_ambulance_destination(sim, i) for i in 1:sim.numAmbs]
end

"""
    get_ambulance_eta(sim::JEMSS.Simulation, ambulance_id::Int) -> Float64

Get the estimated time until the ambulance reaches its destination.
Returns negative value if past scheduled arrival time.
"""
function get_ambulance_eta(sim::JEMSS.Simulation, ambulance_id::Int)::Float64
    return sim.ambulances[ambulance_id].route.endTime - sim.time
end

"""
    get_ambulances_eta(sim::JEMSS.Simulation) -> Vector{Float64}

Get the estimated times of arrival for all ambulances.
"""
function get_ambulances_eta(sim::JEMSS.Simulation)::Vector{Float64}
    return [get_ambulance_eta(sim, i) for i in 1:sim.numAmbs]
end
