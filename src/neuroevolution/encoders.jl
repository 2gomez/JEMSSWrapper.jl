module StateEncoders

using .NeuroevolutionCore: AbstractStateEncoder

export BasicStateEncoder, encode_state
    
"""
    struct BasicStateEncoder <: AbstractStateEncoder

Simple state encoding with essential simulation information.
"""
struct BasicStateEncoder <: AbstractStateEncoder end

function encode_state(encoder::BasicStateEncoder, sim::JEMSS.Simulation)
    # Simple encoding: [current_time, idle_ambulances, calls_waiting]
    features = Float64[]
    
    # Current simulation time
    push!(features, sim.time)
    
    # Count idle ambulances
    idle_count = count(amb -> amb.status == JEMSS.ambIdle, sim.ambulances)
    push!(features, float(idle_count))
    
    # Count waiting calls (simple approximation)
    waiting_calls = max(0, length(sim.calls) - sim.numCallsProcessed)
    push!(features, float(waiting_calls))
    
    return features
end

end # module StateEncoders