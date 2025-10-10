################################################
# Core generic accessor with special handling
################################################

"""
    get_entity_property(sim::JEMSS.Simulation, collection::Symbol, id::Int, property::Symbol)

Get a specific property from a single entity in a simulation.

This is the core generic accessor for simulation entities. It handles special cases
automatically (e.g., ambulance locations that require route updates) and provides
unified access to any entity property.

# Arguments
- `sim::JEMSS.Simulation`: The simulation instance
- `collection::Symbol`: Entity collection name from `JEMSS.Simulation` (`:ambulances`, `:stations`, `:hospitals`)
- `id::Int`: Entity ID (1-indexed)
- `property::Symbol`: Property to retrieve (`:status`, `:class`, `:location`, etc.)

# Returns
The value of the requested property for the specified entity.

# Special Behavior
- **Ambulance locations**: Automatically updates route state before returning location
- **Other properties**: Direct property access without side effects

# Throws
- `AssertionError`: If the entity ID is out of bounds for the collection

# Examples
```julia
# Get ambulance properties
status = get_entity_property(sim, :ambulances, 1, :status)
class = get_entity_property(sim, :ambulances, 1, :class)
location = get_entity_property(sim, :ambulances, 1, :location)  # Updates route

# Get station location
station_loc = get_entity_property(sim, :stations, 2, :location)

# Get hospital location
hospital_loc = get_entity_property(sim, :hospitals, 1, :location)

# Get all ambulance statuses (using comprehension)
all_statuses = [get_entity_property(sim, :ambulances, i, :status) for i in 1:sim.numAmbs]
```
"""
function get_entity_property(sim::JEMSS.Simulation, collection::Symbol, id::Int, property::Symbol)
    # Special case: ambulance location needs route update
    if collection == :ambulances && property == :location
        return get_ambulance_location!(sim, id)
    end 
    # General case: direct property access
    entities = getproperty(sim, collection)
    @assert 1 ≤ id ≤ length(entities) "Invalid $collection ID: $id (max: $(length(entities)))"
    return getproperty(entities[id], property)
end

"""
    get_all_entity_properties(sim::JEMSS.Simulation, collection::Symbol, property::Symbol)

Get a specific property from all entities in a collection.

This is a convenience function that applies [`get_entity_property`](@ref) to all entities
in the specified collection, automatically determining the collection size.

# Arguments
- `sim::JEMSS.Simulation`: The simulation instance
- `collection::Symbol`: Entity collection name from `JEMSS.Simulation` object (`:ambulances`, `:stations`, `:hospitals`)
- `property::Symbol`: Property to retrieve (`:status`, `:class`, `:location`, etc.)

# Returns
- `Vector`: Array containing the property value for each entity in the collection

# Examples
```julia
# Get status of all ambulances
statuses = get_all_entity_properties(sim, :ambulances, :status)

# Get locations of all ambulances (automatically updates routes)
locations = get_all_entity_properties(sim, :ambulances, :location)

# Get locations of all stations
station_locs = get_all_entity_properties(sim, :stations, :location)

# Get locations of all hospitals
hospital_locs = get_all_entity_properties(sim, :hospitals, :location)

# Get classes of all ambulances
classes = get_all_entity_properties(sim, :ambulances, :class)
```
"""
function get_all_entity_properties(sim::JEMSS.Simulation, collection::Symbol, property::Symbol)
    entities = getproperty(sim, collection)
    count = length(entities)
    return [get_entity_property(sim, collection, i, property) for i in 1:count]
end

################################################
# Helper functions 
################################################

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
    locations_to_flat_vector(locs::Vector{Location})

Convert vector of Location objects to flat vector [x1, y1, x2, y2, ...].

# Arguments
- `locs::Vector{Location}`: Vector of Location objects

# Returns
- `Vector{Float64}`: Flat vector of coordinates
"""
function locations_to_flat_vector(locs::Vector{Location})
    result = Vector{Float64}(undef, 2 * length(locs))
    for (i, loc) in enumerate(locs)
        result[2i - 1] = loc.x
        result[2i] = loc.y
    end
    return result
end