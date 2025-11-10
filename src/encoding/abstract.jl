"""
    AbstractEncoder

Base type for state encoders that transform simulation state into 
numerical representations suitable for neural networks.

All concrete encoders must implement:
- `encode_state(encoder, sim, ambulance_index) -> Vector{Float32}`
"""
abstract type AbstractEncoder end

"""
    encode_state(encoder::AbstractEncoder, sim::JEMSS.Simulation, ambulance_index::Int) -> Vector{Float32}

Transform the current simulation state into a numerical vector representation.

# Arguments
- `encoder`: The encoder implementation
- `sim`: Current simulation state
- `ambulance_index`: Index of the triggering ambulance

# Returns
- `Vector{Float32}`: Encoded state suitable for neural network input
"""
function encode_state(encoder::AbstractEncoder, sim::JEMSS.Simulation, ambulance_index::Int)::Vector{Float32}
    error("encode_state not implemented for $(typeof(encoder))")
end

"""
    decode_decision(encoder::GeocentricEncoder, sim::Simulation, 
                   ambulance_index::Int, network_output::Vector{Float64})::Int

Given the network output coordinates, return the index of the closest station.

# Arguments
- `encoder`: Encoder used (geocentric or egocentric)
- `sim`: Current simulation state
- `ambulance_index`: Index of the ambulance to relocate
- `network_output`: Network output ∈ [-1,1]² (normalized coordinates)

# Returns
- Station index corresponding to the closest station to the predicted coordinates
"""
function decode_decision(
    encoder::AbstractEncoder, 
    sim::JEMSS.Simulation,
    ambulance_index::Int, 
    network_output::Vector{Float64}
)::Int
    error("decode_decision not implemented for $(typeof(encoder))")
end

"""
    get_default_network_output(encoder::AbstractEncoder, sim::JEMSS.Simulation, 
                               ambulance::JEMSS.Ambulance) -> Vector{Float32}

Return the network output that would send the ambulance to its home station.

# Arguments
- `encoder`: The encoder implementation
- `sim`: Current simulation state
- `ambulance`: The ambulance to be relocated

# Returns
- `Vector{Float32}`: One-hot encoded vector indicating the home station
"""
function get_default_network_output(encoder::AbstractEncoder, sim::JEMSS.Simulation, 
                                    ambulance::JEMSS.Ambulance)::Vector{Float32}
    error("get_default_network_output not implemented for $(typeof(encoder))")
end