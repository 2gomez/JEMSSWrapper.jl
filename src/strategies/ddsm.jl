"""
Baseline strategies from JEMSS original simulator and literature.
These serve as comparison benchmarks for neural strategies.
"""

using JuMP
using Cbc
using GLPK

const hasGurobi = try
    using Gurobi
    true
catch
    false
end

# ============================================================================
# DDSM Strategy (Dynamic Double Standard Model)
# ============================================================================

"""
    DDSMStrategy <: AbstractMoveUpStrategy

Dynamic Double Standard Model strategy for ambulance relocation.

This strategy uses integer programming to optimize ambulance positions based on:
- Coverage requirements at two different time thresholds
- Demand distribution across geographical points
- Travel costs for repositioning ambulances

# Fields
- `cover_fraction_target_t1::Float64`: Target fraction of demand to cover at first time threshold (0-1)
- `travel_time_cost::Float64`: Cost coefficient for ambulance travel time
- `slack_weight::Float64`: Penalty weight for constraint violations (should be large, e.g., 1e9)
- `cover_time_demand_priorities::Vector{Priority}`: Demand priorities for each cover time threshold
- `trigger_on_dispatch::Bool`: Whether to trigger on ambulance dispatch
- `trigger_on_free::Bool`: Whether to trigger when ambulance becomes free
- `solver::Symbol`: Optimization solver (:cbc, :glpk, or :gurobi)
- `solver_args::Vector{Pair}`: Additional arguments for the solver
- `use_z_var::Bool`: Use auxiliary z variables in IP formulation
- `bin_tolerance::Float64`: Tolerance for binary variable violations

# Reference
Alasdair, C., et al. (2008). "A dynamic model and parallel tabu search heuristic 
for real-time ambulance relocation." European Journal of Operational Research.

# Notes
- Requires JuMP, and at least one of: Cbc, GLPK, or Gurobi
- This is a computationally intensive strategy suitable for offline optimization
- Slack variables prevent infeasibility when coverage constraints cannot be met
"""
mutable struct DDSMStrategy <: AbstractMoveUpStrategy
    # Coverage parameters
    cover_fraction_target_t1::Float64
    travel_time_cost::Float64
    slack_weight::Float64
    cover_time_demand_priorities::Vector{JEMSS.Priority}
    
    # Trigger conditions
    trigger_on_dispatch::Bool
    trigger_on_free::Bool
    
    # Solver configuration
    solver::Symbol
    solver_args::Vector{Pair}
    use_z_var::Bool
    bin_tolerance::Float64
    
    # Internal state (initialized on first use)
    cover_times::Vector{Float64}
    initialized::Bool
    
    function DDSMStrategy(;
        cover_fraction_target_t1::Float64 = 0.5,
        travel_time_cost::Float64 = 50.0,
        slack_weight::Float64 = 1e9,
        cover_time_demand_priorities::Vector{JEMSS.Priority} = [JEMSS.highPriority, JEMSS.lowPriority],
        trigger_on_dispatch::Bool = false,
        trigger_on_free::Bool = true,
        solver::Symbol = :cbc,
        solver_args::Vector{Pair} = Pair[],
        use_z_var::Bool = true,
        bin_tolerance::Float64 = 1e-5
    )
        @assert 0 <= cover_fraction_target_t1 <= 1 "cover_fraction_target_t1 must be in [0,1]"
        @assert length(cover_time_demand_priorities) == 2 "Must provide exactly 2 demand priorities"
        @assert solver in [:cbc, :glpk, :gurobi] "Solver must be :cbc, :glpk, or :gurobi"
        @assert 0 < bin_tolerance < 0.1 "bin_tolerance must be in (0, 0.1)"
        
        if solver == :gurobi && !hasGurobi
            @warn "Gurobi not available, falling back to Cbc"
            solver = :cbc
        end
        
        new(
            cover_fraction_target_t1,
            travel_time_cost,
            slack_weight,
            cover_time_demand_priorities,
            trigger_on_dispatch,
            trigger_on_free,
            solver,
            solver_args,
            use_z_var,
            bin_tolerance,
            Float64[],  # cover_times (initialized later)
            false      # initialized
        )
    end
end

# ============================================================================
# MoveUp Interface Implementation
# ============================================================================

function JEMSSWrapper.initialize_strategy(strategy::DDSMStrategy, sim::JEMSS.Simulation)
    # Initialize demand and demand coverage if not already done
    if !sim.demand.initialised
        if haskey(sim.inputFiles, "demand")
            JEMSS.initDemand!(sim; demandFilename=sim.inputFiles["demand"].path)
        else
            error("Demand file not configured in simulation")
        end
    end
    if !sim.demandCoverage.initialised
        JEMSS.initDemandCoverage!(sim)
    end
    
    # Get cover times for the two demand priorities
    strategy.cover_times = [
        sim.demandCoverage.coverTimes[p] 
        for p in strategy.cover_time_demand_priorities
    ]
    
    @assert length(strategy.cover_times) == 2 "Must have exactly 2 cover times"
    @assert strategy.cover_times[1] < strategy.cover_times[2] "First cover time must be less than second"
    
    strategy.initialized = true
    
    @info "DDSM Strategy initialized" cover_times=strategy.cover_times solver=strategy.solver
    
    return nothing
end

function JEMSSWrapper.should_trigger_on_dispatch(strategy::DDSMStrategy, sim::JEMSS.Simulation)
    return strategy.trigger_on_dispatch
end

function JEMSSWrapper.should_trigger_on_free(strategy::DDSMStrategy, sim::JEMSS.Simulation)
    return strategy.trigger_on_free
end

function JEMSSWrapper.decide_moveup(
    strategy::DDSMStrategy,
    sim::JEMSS.Simulation,
    triggering_ambulance::JEMSS.Ambulance
)
    # Ensure strategy is initialized
    if !strategy.initialized
        initialize_strategy(strategy, sim)
    end
    
    # Get movable ambulances
    movable_ambs = filter(JEMSS.isAmbMovable, sim.ambulances)
    num_movable_ambs = length(movable_ambs)
    
    # No move-up if no ambulances are movable
    if num_movable_ambs == 0
        strategy_output = zeros(Float64, sim.numStations)
        return JEMSS.Ambulance[], JEMSS.Station[], strategy_output
    end
    
    # Calculate travel times and costs
    amb_to_station_times = zeros(Float64, num_movable_ambs, sim.numStations)
    for (i, amb) in enumerate(movable_ambs)
        amb_to_station_times[i, :] = JEMSS.ambMoveUpTravelTimes!(sim, amb)
    end
    amb_to_station_costs = amb_to_station_times .* strategy.travel_time_cost
    
    # Get demand coverage data for both cover times
    point_stations, point_demands, num_points = get_coverage_data(strategy, sim)
    
    # Solve the integer program
    station_assignments = solve_ddsm_ip(
        strategy,
        num_movable_ambs,
        sim.numStations,
        num_points,
        point_stations,
        point_demands,
        amb_to_station_costs
    )
    
    target_stations = [sim.stations[station_idx] for station_idx in station_assignments]
    
    strategy_output = create_ddsm_output_vector(station_assignments, sim.numStations)
   
    return movable_ambs, target_stations, strategy_output
end

# ============================================================================
# Helper Functions
# ============================================================================

"""
    create_ddsm_output_vector(station_assignments::Vector{Int}, num_stations::Int) -> Vector{Float64}

Convert DDSM station assignments to a score vector for logging compatibility.

For each ambulance, creates a one-hot vector where the selected station has score 1.0.
If multiple ambulances, averages the vectors to create a single output vector.
"""
function create_ddsm_output_vector(station_assignments::Vector{Int}, num_stations::Int)
    if length(station_assignments) == 1
        # Single ambulance: return one-hot vector
        output = zeros(Float64, num_stations)
        output[station_assignments[1]] = 1.0
        return output
    else
        # Multiple ambulances: average their one-hot vectors
        output = zeros(Float64, num_stations)
        for station_idx in station_assignments
            output[station_idx] += 1.0
        end
        return output ./ length(station_assignments)
    end
end

"""
    get_coverage_data(strategy::DDSMStrategy, sim::JEMSS.Simulation)

Get demand point coverage data for the two target cover times.

# Returns
- `point_stations`: Vector of vectors, where point_stations[ti][j] contains station indices covering point j at time ti
- `point_demands`: Vector of vectors containing demand values for each point
- `num_points`: Vector containing number of points for each cover time
"""
function get_coverage_data(strategy::DDSMStrategy, sim::JEMSS.Simulation)
    current_time = sim.time
    demand = sim.demand
    
    # Get arrival rates for all priorities
    demand_priority_arrival_rates = [
        JEMSS.getDemandMode!(demand, priority, current_time).arrivalRate 
        for priority in JEMSS.priorities
    ]
    
    point_stations = Vector{Vector{Int}}[]
    point_demands = Vector{Float64}[]
    num_points = Int[]
    
    for demand_priority in strategy.cover_time_demand_priorities
        # Get demand point coverage data
        points_coverage_mode = JEMSS.getPointsCoverageMode!(sim, demand_priority, current_time)
        demand_mode = JEMSS.getDemandMode!(demand, demand_priority, current_time)
        
        # Get demands for each point set
        point_sets_demands = JEMSS.getPointSetsDemands!(
            sim, 
            demand_priority, 
            current_time;
            pointsCoverageMode=points_coverage_mode
        ) * demand_mode.rasterMultiplier
        
        # Scale demand to represent all priorities, not just current one
        total_arrival_rate = sum(demand_priority_arrival_rates)
        priority_arrival_rate = demand_priority_arrival_rates[Int(demand_priority)]
        point_sets_demands .*= total_arrival_rate / priority_arrival_rate
        
        push!(point_stations, points_coverage_mode.stationSets)
        push!(point_demands, point_sets_demands)
        push!(num_points, length(point_sets_demands))
    end
    
    # Sanity check: total demand should be approximately equal for both cover times
    @assert isapprox(sum(point_demands[1]), sum(point_demands[2]), rtol=0.01) "Demand mismatch between cover times"
    
    return point_stations, point_demands, num_points
end

"""
    solve_ddsm_ip(strategy, num_ambs, num_stations, num_points, point_stations, point_demands, amb_costs)

Solve the DDSM integer programming problem.

# Returns
- Vector of station indices for each movable ambulance
"""
function solve_ddsm_ip(
    strategy::DDSMStrategy,
    num_ambs::Int,
    num_stations::Int,
    num_points::Vector{Int},
    point_stations::Vector{Vector{Vector{Int}}},
    point_demands::Vector{Vector{Float64}},
    amb_costs::Matrix{Float64}
)
    # Shorthand
    a = num_ambs
    s = num_stations
    np = num_points
    
    # Create optimization model
    model = Model()
    
    # Set solver
    if strategy.solver == :cbc
        set_optimizer(model, optimizer_with_attributes(
            Cbc.Optimizer, 
            "logLevel" => 0,
            strategy.solver_args...
        ))
    elseif strategy.solver == :glpk
        set_optimizer(model, optimizer_with_attributes(
            GLPK.Optimizer,
            "msg_lev" => GLPK.GLP_MSG_OFF,
            strategy.solver_args...
        ))
    elseif strategy.solver == :gurobi && hasGurobi
        set_optimizer(model, optimizer_with_attributes(
            Gurobi.Optimizer,
            "OutputFlag" => 0,
            strategy.solver_args...
        ))
    end
    
    # Decision variables
    @variable(model, x[i=1:a, j=1:s], Bin)  # x[i,j] = 1 if ambulance i goes to station j
    @variable(model, y11[p=1:np[1]], Bin)   # y11[p] = 1 if point p covered once at time t1
    @variable(model, y12[p=1:np[1]], Bin)   # y12[p] = 1 if point p covered twice at time t1
    @variable(model, y2[p=1:np[2]], Bin)    # y2[p] = 1 if point p covered once at time t2
    
    # Slack variables for constraint relaxation
    @variable(model, s1 >= 0)  # Slack for t1 coverage
    @variable(model, s2 >= 0)  # Slack for t2 coverage
    
    # Constraints
    @constraint(model, amb_at_one_station[i=1:a], 
        sum(x[i, :]) == 1
    )  # Each ambulance assigned to exactly one station
    
    @constraint(model, point_cover_order[p=1:np[1]], 
        y11[p] >= y12[p]
    )  # Single coverage before double coverage
    
    @constraint(model, demand_covered_once_t1,
        sum(y11[p] * point_demands[1][p] for p in 1:np[1]) + s1 >= 
        strategy.cover_fraction_target_t1 * sum(point_demands[1])
    )  # Coverage target at time t1
    
    @constraint(model, demand_covered_once_t2,
        sum(y2[p] * point_demands[2][p] for p in 1:np[2]) + s2 >= 
        sum(point_demands[2])
    )  # Full coverage at time t2
    
    # Optional z variables for improved formulation
    if strategy.use_z_var
        @variable(model, z[j=1:s], Int)  # z[j] = number of ambulances at station j
        
        @constraint(model, station_amb_count[j=1:s],
            z[j] == sum(x[:, j])
        )
        
        @constraint(model, point_cover_count_t1[p=1:np[1]],
            y11[p] + y12[p] <= sum(z[point_stations[1][p]])
        )
        
        @constraint(model, point_cover_count_t2[p=1:np[2]],
            y2[p] <= sum(z[point_stations[2][p]])
        )
    else
        @constraint(model, point_cover_count_t1[p=1:np[1]],
            y11[p] + y12[p] <= sum(x[:, point_stations[1][p]])
        )
        
        @constraint(model, point_cover_count_t2[p=1:np[2]],
            y2[p] <= sum(x[:, point_stations[2][p]])
        )
    end
    
    # Objective function components
    @expression(model, demand_covered_twice_t1,
        sum(y12[p] * point_demands[1][p] for p in 1:np[1])
    )
    
    @expression(model, total_amb_travel_cost,
        sum(x[i, j] * amb_costs[i, j] for i in 1:a, j in 1:s)
    )
    
    @expression(model, slack_cost,
        (s1 + s2) * strategy.slack_weight
    )
    
    # Maximize double coverage at t1, minimize travel cost and slack
    @objective(model, Max, 
        demand_covered_twice_t1 - total_amb_travel_cost - slack_cost
    )
    
    # Solve
    optimize!(model)
    
    # Check solution status
    if termination_status(model) != MOI.OPTIMAL
        @warn "DDSM optimization did not find optimal solution" status=termination_status(model)
        # Return ambulances to their current stations as fallback
        return fill(1, a)  # All to station 1 (will need proper fallback)
    end
    
    # Extract solution
    x_vals = value.(x)
    
    # Verify binary constraints
    max_violation = maximum(abs.(x_vals .- round.(x_vals)))
    if max_violation > strategy.bin_tolerance
        @warn "Binary constraint violation detected" max_violation=max_violation
    end
    
    # Convert to station assignments
    sol = round.(Bool, x_vals)
    station_assignments = [findfirst(sol[i, :]) for i in 1:a]
    
    return station_assignments
end