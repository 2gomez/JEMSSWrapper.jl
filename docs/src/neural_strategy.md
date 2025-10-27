# Neural Network Strategy

## Overview

The `NeuronalStrategy` materializes the integration of neural networks as decision-making policies $\pi_\theta$, where $\theta$ represents the network weights. This strategy serves as the foundation for all neuroevolution algorithms implemented in JEMSSWrapper.

The architecture combines two fundamental components through composition:

```julia
mutable struct NeuronalStrategy <: AbstractMoveUpStrategy
    encoder::AbstractEncoder           # Implements function E
    network::AbstractNeuralNetwork     # Implements function f_θ
    trigger_on_dispatch::Bool          # Activation on dispatch
    trigger_on_free::Bool              # Activation on free
end
```

---

## Key Concepts

### State Encoding

Neural networks require numerical input. The encoder transforms the simulation state into a vector:

$$\mathbf{x}_t = E(s_t)$$

where $E$ is the encoder function, $s_t$ is the current state, and $\mathbf{x}_t \in \mathbb{R}^d$ is the encoded representation.

### Network Output

The neural network processes the encoded state and outputs scores for each station:

$$\mathbf{z}_t = f_\theta(\mathbf{x}_t)$$

where $f_\theta$ is the neural network and $\mathbf{z}_t \in \mathbb{R}^M$ contains scores for all $M$ stations.

### Action Selection

The strategy selects the station with the highest score:

$$j^* = \argmax_{j \in \{1,\ldots,M\}} z_{t,j}$$

This determines which station the ambulance should relocate to.

---

## Architecture Design

This architecture completely decouples:
- **State representation** (encoder $E$) 
- **Decision policy** (network $f_\theta$)

This separation allows combining different encoders with different neural network architectures, providing maximum flexibility for experimentation.

---

## Usage Example

### Basic Setup

```julia
using JEMSSWrapper

# Load scenario
scenario = load_scenario_from_config("path/to/config.toml")

# Create encoder (assuming you have a custom encoder)
encoder = MyCustomEncoder(
    num_stations=length(scenario.stations),
    encoding_dim=64
)

# Create neural network (assuming you have a custom network)
network = MyNeuralNetwork(
    input_dim=64,
    output_dim=length(scenario.stations)
)

# Create neuronal strategy
strategy = NeuronalStrategy(
    encoder, 
    network;
    trigger_on_dispatch=false,
    trigger_on_free=true
)

# Run simulation
results = simulate_scenario(scenario, strategy)
```

### Custom Encoder Example

```julia
# Define custom encoder
struct MyEncoder <: AbstractEncoder
    num_stations::Int
    encoding_dim::Int
end

# Implement required method
function encode_state(
    encoder::MyEncoder, 
    sim::JEMSS.Simulation, 
    ambulance_index::Int
)::Vector{Float64}
    # Extract relevant information
    ambulance = sim.ambulances[ambulance_index]
    
    # Build encoded state vector
    encoded = Float64[]
    
    # Add ambulance features
    push!(encoded, ambulance.station.index / encoder.num_stations)
    push!(encoded, length(sim.calls) / 100.0)
    
    # Add station occupancy features
    for station in sim.stations
        available = count(a -> a.status == ambulanceIdle && 
                             a.station.index == station.index, 
                           sim.ambulances)
        push!(encoded, available / length(sim.ambulances))
    end
    
    # Pad or truncate to encoding_dim
    while length(encoded) < encoder.encoding_dim
        push!(encoded, 0.0)
    end
    
    return encoded[1:encoder.encoding_dim]
end
```

### Custom Neural Network Example

```julia
# Define custom network
struct SimpleFFN <: AbstractNeuralNetwork
    weights::Matrix{Float64}
    bias::Vector{Float64}
end

# Implement required method
function forward(
    network::SimpleFFN, 
    input::Vector{Float64}
)::Vector{Float64}
    # Simple feedforward computation
    output = network.weights * input .+ network.bias
    return output
end
```

---

## Integration with Neuroevolution

The `NeuronalStrategy` is designed to work seamlessly with neuroevolution algorithms. The strategy's mutable nature allows algorithms to:

1. **Modify network weights** during evolution
2. **Evaluate fitness** through simulation
3. **Select and reproduce** successful policies

Example workflow with a genetic algorithm:

```julia
# Initialize population of strategies
population = [
    NeuronalStrategy(encoder, create_random_network())
    for _ in 1:population_size
]

# Evolution loop
for generation in 1:num_generations
    # Evaluate fitness
    fitness = [evaluate(strategy, scenario) for strategy in population]
    
    # Select parents
    parents = selection(population, fitness)
    
    # Create offspring
    offspring = crossover_and_mutate(parents)
    
    # Replace population
    population = offspring
end

# Use best strategy
best_strategy = population[argmax(fitness)]
final_results = simulate_scenario(scenario, best_strategy)
```

---

## See Also

- **[Strategy Development Guide](@ref)** - General strategy development guide
- **[Simulation State Reference](@ref)** - Complete details on all available state 
- **[API Reference](@ref)** - Complete function documentation