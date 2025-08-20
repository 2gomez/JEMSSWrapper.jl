"""
EvaluationRunner
================

Basic simulation evaluation system for Phase 1.
Runs simulations with policies and extracts basic metrics.
"""
module EvaluationRunner

using ..ScenarioConfig: SimulationConfig
using ..SimulationInitialization: initialize_simulation, create_simulation_copy
using ..PolicyInterface: MoveUpPolicy, apply_policy!

export evaluate_policy, run_single_simulation, SimulationResult

"""
    struct SimulationResult

Basic result structure for a single simulation run.
"""
struct SimulationResult
    policy_name::String
    total_calls::Int
    completed_calls::Int
    mean_response_time::Float64
    mean_transport_time::Float64
    simulation_time::Float64
    success::Bool
    error_message::String
end

"""
    SimulationResult(policy_name::String)

Create a failed simulation result.
"""
function SimulationResult(policy_name::String, error_msg::String)
    return SimulationResult(policy_name, 0, 0, NaN, NaN, NaN, false, error_msg)
end

"""
    evaluate_policy(config::SimulationConfig, policy::MoveUpPolicy; num_replications::Int = 1)

Evaluate a policy on a scenario with multiple replications.

# Arguments
- `config::SimulationConfig`: Scenario configuration
- `policy::MoveUpPolicy`: Policy to evaluate
- `num_replications::Int`: Number of simulation runs

# Returns
- `Vector{SimulationResult}`: Results from all replications
"""
function evaluate_policy(config::SimulationConfig, policy::MoveUpPolicy; num_replications::Int = 1)
    results = SimulationResult[]
    
    try
        # Initialize base simulation once
        base_sim = initialize_simulation(config)
        
        for rep in 1:num_replications
            try
                # Create a copy for this replication
                sim = create_simulation_copy(base_sim)
                
                # Run simulation with policy
                result = run_single_simulation(sim, policy, rep)
                push!(results, result)
                
            catch e
                policy_name = string(typeof(policy))
                error_msg = "Replication $rep failed: $(string(e))"
                push!(results, SimulationResult(policy_name, error_msg))
                @warn error_msg
            end
        end
        
    catch e
        policy_name = string(typeof(policy))
        error_msg = "Failed to initialize simulation: $(string(e))"
        push!(results, SimulationResult(policy_name, error_msg))
        @error error_msg
    end
    
    return results
end

"""
    run_single_simulation(sim, policy::MoveUpPolicy, replication::Int = 1)

Run a single simulation with the given policy.

# Arguments
- `sim`: JEMSS Simulation object
- `policy::MoveUpPolicy`: Policy to apply
- `replication::Int`: Replication number (for identification)

# Returns
- `SimulationResult`: Result of the simulation
"""
function run_single_simulation(sim, policy::MoveUpPolicy, replication::Int = 1)
    JEMSS = Main.JEMSSWrapper.jemss
    
    policy_name = get_policy_name(policy)
    
    try
        # Apply the policy
        apply_policy!(sim, policy)
        
        # Run the simulation
        start_time = time()
        JEMSS.simulate!(sim)
        simulation_duration = time() - start_time
        
        # Extract basic metrics
        metrics = extract_basic_metrics(sim)
        
        return SimulationResult(
            "$(policy_name)_rep$(replication)",
            metrics.total_calls,
            metrics.completed_calls,
            metrics.mean_response_time,
            metrics.mean_transport_time,
            simulation_duration,
            true,
            ""
        )
        
    catch e
        error_msg = "Simulation failed: $(string(e))"
        @warn error_msg
        return SimulationResult("$(policy_name)_rep$(replication)", error_msg)
    end
end

"""
    extract_basic_metrics(sim)

Extract basic performance metrics from a completed simulation.

# Arguments
- `sim`: Completed JEMSS Simulation object

# Returns
- `NamedTuple`: Basic metrics (total_calls, completed_calls, mean_response_time, mean_transport_time)
"""
function extract_basic_metrics(sim)
    # Count calls
    total_calls = length(sim.calls)
    completed_calls = count(call -> !isnan(call.departureTime), sim.calls)
    
    # Calculate response times (arrival time - dispatch time)
    response_times = Float64[]
    transport_times = Float64[]
    
    for call in sim.calls
        if !isnan(call.arrivalTime) && !isnan(call.dispatchTime)
            response_time = call.arrivalTime - call.dispatchTime
            push!(response_times, response_time)
        end
        
        if !isnan(call.departureTime) && !isnan(call.arrivalTime)
            transport_time = call.departureTime - call.arrivalTime
            push!(transport_times, transport_time)
        end
    end
    
    mean_response_time = isempty(response_times) ? NaN : sum(response_times) / length(response_times)
    mean_transport_time = isempty(transport_times) ? NaN : sum(transport_times) / length(transport_times)
    
    return (
        total_calls = total_calls,
        completed_calls = completed_calls,
        mean_response_time = mean_response_time,
        mean_transport_time = mean_transport_time
    )
end

"""
    get_policy_name(policy::MoveUpPolicy)

Get a descriptive name for any policy type.
"""
function get_policy_name(policy::MoveUpPolicy)
    # Try to call the policy-specific method, fallback to type name
    try
        return Main.JEMSSWrapper.PolicyInterface.get_policy_name(policy)
    catch
        return string(typeof(policy))
    end
end

"""
    print_results(results::Vector{SimulationResult})

Print simulation results in a readable format.
"""
function print_results(results::Vector{SimulationResult})
    println("Simulation Results:")
    println("==================")
    
    successful_results = filter(r -> r.success, results)
    failed_results = filter(r -> !r.success, results)
    
    if !isempty(successful_results)
        println("Successful runs: $(length(successful_results))")
        
        for result in successful_results
            println("\n$(result.policy_name):")
            println("  Total calls: $(result.total_calls)")
            println("  Completed calls: $(result.completed_calls)")
            println("  Mean response time: $(round(result.mean_response_time, digits=2)) time units")
            println("  Mean transport time: $(round(result.mean_transport_time, digits=2)) time units")
            println("  Simulation duration: $(round(result.simulation_time, digits=2)) seconds")
        end
    end
    
    if !isempty(failed_results)
        println("\nFailed runs: $(length(failed_results))")
        for result in failed_results
            println("  $(result.policy_name): $(result.error_message)")
        end
    end
end

end # module EvaluationRunner