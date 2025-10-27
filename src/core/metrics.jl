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

"""
    SimulationMetrics

Container for all metrics from a simulation run.
"""
struct SimulationMetrics
    avg_response_time::Float64
    survival_rate::Float64
    percentile::Float64
    max_response_time::Float64
    utilization::Float64
    num_relocations::Int
    total_distance::Float64

    survival_threshold::Float64
    response_percentile::Float64
end

"""
    extract_all_metrics(sim::JEMSS.Simulation; survival_threshold::Float64 = 8.0,
                        percentile::Float64 = 90.0) -> SimulationMetrics

Extract all metrics from a simulation into a structured object.
"""
function extract_all_metrics(sim::JEMSS.Simulation; survival_threshold::Float64 = 8.0, 
                             percentile::Float64 = 90.0)
    return SimulationMetrics(
        get_avg_response_time(sim),
        get_survival_rate(sim, threshold=survival_threshold),
        get_percentile_response_time(sim, percentile=percentile),
        get_max_response_time(sim),
        get_ambulance_utilization(sim),
        get_num_relocations(sim),
        get_total_distance_traveled(sim),
        survival_threshold,
        percentile
    )
end

"""
    Base.show(io::IO, metrics::SimulationMetrics)

Pretty print simulation metrics.
"""
function Base.show(io::IO, metrics::SimulationMetrics)
    println(io, "SimulationMetrics:")
    println(io, "  Avg Response Time: $(round(metrics.avg_response_time, digits=2)) min")
    println(io, "  Survival Rate ($(survival_threshold)min): $(round(metrics.survival_rate * 100, digits=1))%")
    println(io, "  $(response_percentile)th Percentile: $(round(metrics.percentile, digits=2)) min")
    println(io, "  Max Response Time: $(round(metrics.max_response_time, digits=2)) min")
    println(io, "  Utilization: $(round(metrics.utilization * 100, digits=1))%")
    println(io, "  Relocations: $(metrics.num_relocations)")
    println(io, "  Total Distance: $(round(metrics.total_distance, digits=2))")
end

"""
    get_metric(sim::JEMSS.Simulation, metric::Symbol; kwargs...) -> Union{Float64, Int, Vector{Float64}}

Central dispatcher function to extract any simulation metric by name.

This serves as a single point of control for all metric extraction, making it easier to:
- Change metric implementations in one place
- Add logging or validation
- Handle errors consistently
- Document all available metrics

# Arguments
- `sim::JEMSS.Simulation`: Completed simulation instance
- `metric::Symbol`: Name of the metric to extract
- `kwargs...`: Metric-specific parameters (e.g., `threshold`, `percentile`)

# Available Metrics
- `:avg_response_time` - Average response time (minutes)
- `:response_times` - Vector of all response times
- `:survival_rate` - Fraction under threshold (kwargs: `threshold=8.0`)
- `:percentile_response_time` - Nth percentile (kwargs: `percentile=90.0`)
- `:max_response_time` - Maximum response time
- `:ambulance_utilization` - Average busy fraction [0,1]
- `:num_relocations` - Total move-up relocations
- `:total_distance` - Total distance traveled
- `:num_calls_processed` - Number of processed calls

# Returns
- Metric value (type depends on metric)

# Throws
- `ArgumentError`: If metric name is not recognized

# Examples
```julia
# Basic usage
avg_time = get_metric(sim, :avg_response_time)
survival = get_metric(sim, :survival_rate, threshold=10.0)
p95 = get_metric(sim, :percentile_response_time, percentile=95.0)

# Get all times for custom analysis
times = get_metric(sim, :response_times)
median_time = median(times)

# Error handling
try
    value = get_metric(sim, :invalid_metric)
catch e
    println("Metric not found: \$e")
end
```

# Performance Note
For extracting multiple metrics, consider using `get_simulation_metrics()` instead,
which computes all metrics efficiently in fewer passes over the data.
"""
function get_metric(sim::JEMSS.Simulation, metric::Symbol; kwargs...)
    if metric == :avg_response_time
        return get_avg_response_time(sim)
        
    elseif metric == :response_times
        return get_response_times(sim)
        
    elseif metric == :survival_rate
        threshold = get(kwargs, :threshold, 8.0)
        return get_survival_rate(sim; threshold=threshold)
        
    elseif metric == :percentile_response_time
        percentile = get(kwargs, :percentile, 90.0)
        return get_percentile_response_time(sim; percentile=percentile)
        
    elseif metric == :max_response_time
        return get_max_response_time(sim)
        
    elseif metric == :ambulance_utilization
        return get_ambulance_utilization(sim)
        
    elseif metric == :num_relocations
        return get_num_relocations(sim)
        
    elseif metric == :total_distance
        return get_total_distance_traveled(sim)
        
    elseif metric == :num_calls_processed
        return length(get_response_times(sim))
        
    else
        throw(ArgumentError("Unknown metric: $metric. Available metrics: " *
                          ":avg_response_time, :response_times, :survival_rate, " *
                          ":percentile_response_time, :max_response_time, " *
                          ":ambulance_utilization, :num_relocations, :total_distance, " *
                          ":num_calls_processed"))
    end
end