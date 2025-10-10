"""
Metrics extraction from JEMSS simulations.

This module provides standardized metric extraction for optimization.
"""

# ============================================================================
# Metric Extraction Functions
# ============================================================================

"""
    get_avg_response_time(sim::JEMSS.Simulation) -> Float64

Get average response time across all calls (in minutes).
Lower is better.
"""
function get_avg_response_time(sim::JEMSS.Simulation)
    return JEMSS.getAvgCallResponseDuration(sim)
end

"""
    get_response_times(sim::JEMSS.Simulation) -> Vector{Float64}

Get response times for all calls (in minutes).
"""
function get_response_times(sim::JEMSS.Simulation)
    times = Float64[]
    for call in sim.calls
        if call.status == JEMSS.callProcessed
            response_time = call.dispatchDelay + call.onSceneDuration + call.transportDuration
            push!(times, response_time)
        end
    end
    return times
end

"""
    get_survival_rate(sim::JEMSS.Simulation; threshold::Float64 = 8.0) -> Float64

Fraction of calls responded to within threshold (default: 8 minutes).
Higher is better. Range: [0, 1]
"""
function get_survival_rate(sim::JEMSS.Simulation; threshold::Float64 = 8.0)
    response_times = get_response_times(sim)
    isempty(response_times) && return 0.0
    return mean(response_times .< threshold)
end

"""
    get_percentile_response_time(sim::JEMSS.Simulation; percentile::Float64 = 90.0) -> Float64

Get the Nth percentile response time (default: 90th).
Lower is better.
"""
function get_percentile_response_time(sim::JEMSS.Simulation; percentile::Float64 = 90.0)
    response_times = get_response_times(sim)
    isempty(response_times) && return Inf
    return quantile(response_times, percentile / 100.0)
end

"""
    get_max_response_time(sim::JEMSS.Simulation) -> Float64

Get maximum response time across all calls.
Lower is better.
"""
function get_max_response_time(sim::JEMSS.Simulation)
    response_times = get_response_times(sim)
    isempty(response_times) && return Inf
    return maximum(response_times)
end

"""
    get_ambulance_utilization(sim::JEMSS.Simulation) -> Float64

Average fraction of time ambulances are busy.
Range: [0, 1]. Moderate values (0.6-0.8) are typically optimal.
"""
function get_ambulance_utilization(sim::JEMSS.Simulation)
    total_busy_time = 0.0
    total_available_time = 0.0
    
    for ambulance in sim.ambulances
        # Calculate busy time for this ambulance
        busy_time = 0.0
        for event in ambulance.events
            if event.eventType in [JEMSS.ambGoToCall, JEMSS.ambAtCall, JEMSS.ambGoToHospital]
                busy_time += event.duration
            end
        end
        
        total_busy_time += busy_time
        total_available_time += sim.endTime - sim.startTime
    end
    
    return total_busy_time / total_available_time
end

"""
    get_num_relocations(sim::JEMSS.Simulation) -> Int

Total number of move-up relocations performed.
"""
function get_num_relocations(sim::JEMSS.Simulation)
    count = 0
    for ambulance in sim.ambulances
        for event in ambulance.events
            if event.eventType == JEMSS.ambMoveUp
                count += 1
            end
        end
    end
    return count
end

"""
    get_total_distance_traveled(sim::JEMSS.Simulation) -> Float64

Total distance traveled by all ambulances (in simulation units).
"""
function get_total_distance_traveled(sim::JEMSS.Simulation)
    total_distance = 0.0
    
    for ambulance in sim.ambulances
        for event in ambulance.events
            if hasfield(typeof(event), :distance)
                total_distance += event.distance
            end
        end
    end
    
    return total_distance
end

# ============================================================================
# Composite Metrics
# ============================================================================

"""
    get_weighted_objective(sim::JEMSS.Simulation; 
                          response_weight::Float64 = 1.0,
                          survival_weight::Float64 = 0.0,
                          utilization_weight::Float64 = 0.0) -> Float64

Compute a weighted combination of multiple metrics.

# Arguments
- `response_weight`: Weight for avg response time (minimize)
- `survival_weight`: Weight for survival rate (maximize)
- `utilization_weight`: Weight for utilization balance (target ~0.7)

# Returns
Combined objective value (lower is better for optimization)
"""
function get_weighted_objective(sim::JEMSS.Simulation;
                               response_weight::Float64 = 1.0,
                               survival_weight::Float64 = 0.0,
                               utilization_weight::Float64 = 0.0)
    objective = 0.0
    
    # Response time component (minimize)
    if response_weight > 0
        objective += response_weight * get_avg_response_time(sim)
    end
    
    # Survival rate component (maximize -> minimize negative)
    if survival_weight > 0
        objective -= survival_weight * get_survival_rate(sim)
    end
    
    # Utilization penalty (penalize deviation from ideal ~0.7)
    if utilization_weight > 0
        util = get_ambulance_utilization(sim)
        ideal_util = 0.7
        util_penalty = abs(util - ideal_util)
        objective += utilization_weight * util_penalty
    end
    
    return objective
end

# ============================================================================
# Metric Summary
# ============================================================================

"""
    SimulationMetrics

Container for all metrics from a simulation run.
"""
struct SimulationMetrics
    avg_response_time::Float64
    survival_rate::Float64
    percentile_90::Float64
    max_response_time::Float64
    utilization::Float64
    num_relocations::Int
    total_distance::Float64
end

"""
    extract_all_metrics(sim::JEMSS.Simulation; survival_threshold::Float64 = 8.0) -> SimulationMetrics

Extract all metrics from a simulation into a structured object.
"""
function extract_all_metrics(sim::JEMSS.Simulation; survival_threshold::Float64 = 8.0)
    return SimulationMetrics(
        get_avg_response_time(sim),
        get_survival_rate(sim, threshold=survival_threshold),
        get_percentile_response_time(sim, percentile=90.0),
        get_max_response_time(sim),
        get_ambulance_utilization(sim),
        get_num_relocations(sim),
        get_total_distance_traveled(sim)
    )
end

"""
    Base.show(io::IO, metrics::SimulationMetrics)

Pretty print simulation metrics.
"""
function Base.show(io::IO, metrics::SimulationMetrics)
    println(io, "SimulationMetrics:")
    println(io, "  Avg Response Time: $(round(metrics.avg_response_time, digits=2)) min")
    println(io, "  Survival Rate (8min): $(round(metrics.survival_rate * 100, digits=1))%")
    println(io, "  90th Percentile: $(round(metrics.percentile_90, digits=2)) min")
    println(io, "  Max Response Time: $(round(metrics.max_response_time, digits=2)) min")
    println(io, "  Utilization: $(round(metrics.utilization * 100, digits=1))%")
    println(io, "  Relocations: $(metrics.num_relocations)")
    println(io, "  Total Distance: $(round(metrics.total_distance, digits=2))")
end