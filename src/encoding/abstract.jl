"""
    AbstractEncoder

Base type for state encoders that transform simulation state into 
numerical representations suitable for neural networks.

All concrete encoders must implement:
- `encode_state(encoder, sim, ambulance_index) -> Vector{Float64}`
"""
abstract type AbstractEncoder end

"""
    encode_state(encoder::AbstractEncoder, sim::JEMSS.Simulation, ambulance_index::Int) -> Vector{Float64}

Transform the current simulation state into a numerical vector representation.

# Arguments
- `encoder`: The encoder implementation
- `sim`: Current simulation state
- `ambulance_index`: Index of the triggering ambulance

# Returns
- `Vector{Float64}`: Encoded state suitable for neural network input
"""
function encode_state(encoder::AbstractEncoder, sim::JEMSS.Simulation, ambulance_index::Int)::Vector{Float64}
    error("encode_state not implemented for $(typeof(encoder))")
end

