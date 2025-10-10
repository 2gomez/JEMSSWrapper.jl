"""
    BasicStateEncoder <: AbstractEncoder

Simple encoder that converts simulation state to a fixed-size Float64 vector.

Encodes only positions (x, y coordinates) of ambulances and stations.

# Encoding scheme:
- Ambulances: [amb1_x, amb1_y, amb2_x, amb2_y, ...]  (2 * n_ambulances values)
- Stations: [sta1_x, sta1_y, sta2_x, sta2_y, ...]    (2 * n_stations values)

# Total size: 2 * (n_ambulances + n_stations)

# Example:
For 10 ambulances and 5 stations:
- Ambulances: 10 * 2 = 20 values
- Stations: 5 * 2 = 10 values
- **Total: 30 values**
"""
struct BasicStateEncoder <: AbstractEncoder
    n_ambulances::Int
    n_stations::Int
end

"""
    BasicStateEncoder(scenario::ScenarioData)

Create encoder from a loaded scenario.
"""
function BasicStateEncoder(scenario)
    n_ambulances = length(scenario.ambulances)
    n_stations = scenario.base_simulation.numStations
    
    return BasicStateEncoder(n_ambulances, n_stations)
end

"""
    encode_state(encoder::BasicStateEncoder, sim::JEMSS.Simulation, ambulance_index::Int)

Encode the current simulation state into a Float64 vector.

# Arguments
- `encoder::BasicStateEncoder`: The encoder with configuration
- `sim::JEMSS.Simulation`: The simulation instance
- `ambulance_index::Int`: Trigger ambulance index (not used in this simple encoder)

# Returns
- `Vector{Float64}`: Encoded state vector of size `input_size(encoder)`
  Format: [amb_locs..., station_locs...]
"""
function encode_state(
    encoder::BasicStateEncoder,
    sim::JEMSS.Simulation,
    ambulance_index::Int
)
    # Preallocate output vector
    encoded = Vector{Float64}(undef, input_size(encoder))
    
    # Get all locations
    ambulance_locations = get_all_entity_properties(sim, :ambulances, :location)
    station_locations = get_all_entity_properties(sim, :stations, :location)
    
    # Convert to flat vectors
    amb_flat = locations_to_flat_vector(ambulance_locations)
    sta_flat = locations_to_flat_vector(station_locations)
    
    # Fill encoded vector
    n_amb_values = 2 * encoder.n_ambulances
    encoded[1:n_amb_values] = amb_flat
    encoded[n_amb_values+1:end] = sta_flat
    
    return encoded
end

"""
    input_size(encoder::BasicStateEncoder)

Get the size of the encoded state vector.

# Returns
- `Int`: Size of the output vector from `encode_state`
"""
function input_size(encoder::BasicStateEncoder)
    # 2 coordinates (x, y) per ambulance and station
    return 2 * (encoder.n_ambulances + encoder.n_stations)
end

"""
    output_size(encoder::BasicStateEncoder)

Get the expected output size (number of stations to choose from).

# Returns
- `Int`: Number of possible target stations
"""
function output_size(encoder::BasicStateEncoder)
    return encoder.n_stations
end