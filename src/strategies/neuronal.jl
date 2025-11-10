"""
    AbstractNeuralNetwork

Base type for neural network architectures used in decision making.

All concrete networks must implement:
- `forward(network, input) -> Vector{Float32}`
"""
abstract type AbstractNeuralNetwork end

"""
    forward(network::AbstractNeuralNetwork, input::Vector{Float32}) -> Vector{Float32}

Perform forward pass through the neural network.

# Arguments
- `network`: The neural network
- `input`: Input vector

# Returns
- `Vector{Float32}`: Network output (typically action probabilities or station scores)
"""
function forward(network::AbstractNeuralNetwork, input::Vector{Float32})
    error("forward not implemented for $(typeof(network))")
end

"""
    NeuronalStrategy <: AbstractMoveUpStrategy

Neural network-based strategy for ambulance relocation.
Works with any combination of encoder and neural network.

# Fields
- `encoder::AbstractEncoder`: State encoder
- `network::AbstractNeuralNetwork`: Neural network for decision making
- `trigger_on_dispatch::Bool`: Whether to trigger on ambulance dispatch
- `trigger_on_free::Bool`: Whether to trigger when ambulance becomes free
"""
mutable struct NeuronalStrategy <: AbstractMoveUpStrategy
    encoder::AbstractEncoder
    network::AbstractNeuralNetwork
    trigger_on_dispatch::Bool
    trigger_on_free::Bool
    
    function NeuronalStrategy(
        encoder::AbstractEncoder, 
        network::AbstractNeuralNetwork;
        trigger_on_dispatch::Bool = false,
        trigger_on_free::Bool = true
    )
        new(encoder, network, trigger_on_dispatch, trigger_on_free)
    end
end

function should_trigger_on_dispatch(strategy::NeuronalStrategy, sim::JEMSS.Simulation)
    return strategy.trigger_on_dispatch
end

function should_trigger_on_free(strategy::NeuronalStrategy, sim::JEMSS.Simulation)
    return strategy.trigger_on_free
end

function decide_moveup(
    strategy::NeuronalStrategy, 
    sim::JEMSS.Simulation, 
    triggering_ambulance::JEMSS.Ambulance
)
    ambulance_index = triggering_ambulance.index
    
    # Encode current state (will be reused for logging if logger exists)
    encoded_state = encode_state(strategy.encoder, sim, ambulance_index)
    
    # Get network decision
    network_output = forward(strategy.network, encoded_state)
    
    # Select best station (highest score)
    station_index = decode_decision(strategy.encoder, network_output)
    
    # Prepare result
    movable_ambulances = [sim.ambulances[ambulance_index]]
    target_stations = [sim.stations[station_index]]
   
    return movable_ambulances, target_stations, network_output
end