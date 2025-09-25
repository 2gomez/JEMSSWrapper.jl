"""
Replication
==========

Extended replication utilities including strategy replication support.
"""

module Replication

using JEMSS
using ..Types: ScenarioData
using ..MoveUp: AbstractMoveUpStrategy

#export create_simulation_instance, create_simulation_instance_with_strategy, 
#       initialize_strategy_with_scenario, reset_simulation!
export create_simulation_instance


"""
    create_simulation_instance(scenario::ScenarioData)

Create simulation instance with the calls and ambulances.
"""
function create_simulation_instance(scenario::ScenarioData)
    base_sim = scenario.base_simulation
    calls = scenario.calls
    ambulances = scenario.ambulances

    sim = copy_base_simulation(base_sim)
    add_calls!(sim, calls)
    add_ambulances!(sim, ambulances)

    return sim
end

# """
#     create_simulation_instance_with_strategy(scenario::ScenarioData, 
#                                            base_strategy::AbstractMoveUpStrategy,
#                                            new_params::Dict{String, Any} = Dict{String, Any}())
# 
# Create a simulation instance with a replicated and optionally modified strategy.
# 
# This function is designed for parameter sweeps and experiments where you want to:
# 1. Reuse expensive strategy initialization (distance matrices, trained models, etc.)
# 2. Test different parameter combinations efficiently
# 3. Run multiple replications with the same base strategy
# 
# # Arguments
# - `scenario::ScenarioData`: The scenario data containing base simulation, calls, and ambulances
# - `base_strategy::AbstractMoveUpStrategy`: The initialized base strategy to replicate
# - `new_params::Dict{String, Any}`: Optional parameter updates to apply to the replicated strategy
# 
# # Returns
# - `Tuple{JEMSS.Simulation, AbstractMoveUpStrategy}`: New simulation instance and replicated strategy
# 
# # Example
# ```julia
# # Initialize base strategy once (expensive)
# base_strategy = MyMLStrategy(learning_rate=0.01)
# initialize_strategy!(base_strategy, scenario.base_simulation)
# 
# # Run parameter sweep efficiently  
# for lr in [0.001, 0.01, 0.1]
#     sim, strategy = create_simulation_instance_with_strategy(
#         scenario, 
#         base_strategy, 
#         Dict("learning_rate" => lr)
#     )
#     
#     results = simulate_custom!(sim, moveup_strategy=strategy)
# end
# ```
# """
# function create_simulation_instance_with_strategy(scenario::ScenarioData, 
#                                                  base_strategy::AbstractMoveUpStrategy,
#                                                  new_params::Dict{String, Any} = Dict{String, Any}())
#     # 1. Create new simulation instance
#     sim = create_simulation_instance(scenario)
#     
#     # 2. Copy strategy (preserves initialization state)
#     strategy = copy_strategy(base_strategy)
#     
#     # 3. Update parameters if provided
#     if !isempty(new_params)
#         update_parameters!(strategy, new_params)
#     end
#     
#     return sim, strategy
# end
# 
# # """
#     initialize_strategy_with_scenario(strategy::AbstractMoveUpStrategy, scenario::ScenarioData)
# 
# Initialize a strategy using the base simulation from a scenario.
# 
# This is a convenience function that initializes a strategy with the base simulation
# from a ScenarioData object. Useful for setting up strategies before running multiple
# replications.
# 
# # Arguments
# - `strategy::AbstractMoveUpStrategy`: The strategy to initialize (modified in-place)
# - `scenario::ScenarioData`: The scenario containing the base simulation
# 
# # Example
# ```julia
# strategy = MyMLStrategy(learning_rate=0.01)
# initialize_strategy_with_scenario(strategy, scenario)
# 
# # Now strategy is ready for multiple replications
# for i in 1:num_replications
#     sim, strat = create_simulation_instance_with_strategy(scenario, strategy)
#     results = simulate_custom!(sim, moveup_strategy=strat)
# end
# ```
# """
# function initialize_strategy_with_scenario(strategy::AbstractMoveUpStrategy, scenario::ScenarioData)
#     initialize_strategy!(strategy, scenario.base_simulation)
#     return nothing
# end
# 
# # =============================================================================
# INTERNAL/HELPER FUNCTIONS (UNCHANGED)
# =============================================================================

"""
    copy_base_simulation(sim::JEMSS.Simulation)

Create a deep copy of a base simulation for replication.
"""
function copy_base_simulation(sim::JEMSS.Simulation)
    sim_copy = JEMSS.Simulation()
    sim_copy.time = 0.0
    sim_copy.startTime = 0.0
    sim_copy.numHospitals = sim.numHospitals
    sim_copy.numStations = sim.numStations
    sim_copy.hospitals = deepcopy(sim.hospitals)
    sim_copy.stations = deepcopy(sim.stations)
    sim_copy.net = sim.net # shallow copy, this is the heavy part of the object
    sim_copy.map = deepcopy(sim.map)
    sim_copy.targetResponseDurations = deepcopy(sim.targetResponseDurations)
    sim_copy.responseTravelPriorities = deepcopy(sim.responseTravelPriorities)
    sim_copy.travel = sim.travel # shallow copy, this is the heavy part of the object
    sim_copy.grid = deepcopy(sim.grid)
        
    sim_copy.addCallToQueue! = sim.addCallToQueue!
    sim_copy.findAmbToDispatch! = sim.findAmbToDispatch!

    sim_copy.eventList = Vector{JEMSS.Event}()
    
    sim_copy.initialised = sim.initialised
    return sim_copy
end

# """
#     reset_simulation!(sim::JEMSS.Simulation, scenario::ScenarioData) 
# 
# Reset the simulation instance with the initial calls and ambulance positions.
# """
# function reset_simulation!(sim::JEMSS.Simulation, scenario::ScenarioData)
#     # Reset solo los campos que definitivamente necesitan ser reseteados
#     sim.time = 0.0
#     sim.startTime = 0.0
#     sim.endTime = nullTime
# 
#     sim.hospitals = deepcopy(scenario.base_simulation.hospitals)
#     sim.stations = deepcopy(scenario.base_simulation.stations)
#     
#     # Limpiar entidades dinámicas
#     empty!(sim.ambulances)
#     empty!(sim.calls)
#     empty!(sim.eventList)
#     empty!(sim.queuedCallList)
#     empty!(sim.currentCalls)
#     empty!(sim.previousCalls)
#     
#     # Reset contadores y flags críticos
#     sim.numAmbs = 0
#     sim.numCalls = 0
#     sim.eventIndex = 0
#     sim.used = false
#     sim.complete = false
#     
#     # Reset estadísticas
#     sim.stats = JEMSS.SimStats()
#     
#     # Añadir nuevos datos
#     add_calls!(sim, scenario.calls)
#     add_ambulances!(sim, scenario.ambulances)
# end
# 
"""
    add_calls!(sim::JEMSS.Simulation, calls::Vector{JEMSS.Call})

Add a vector of calls to the simulation.
"""
function add_calls!(sim::JEMSS.Simulation, calls::Vector{JEMSS.Call})
    sim.calls = deepcopy(calls)
    sim.numCalls = length(calls)
    JEMSS.addEvent!(sim.eventList, sim.calls[1])
end

"""
    add_ambulances!(sim::JEMSS.Simulation, ambulances::Vector{JEMSS.Ambulance})

Set the ambulances data in a simulation object.
"""
function add_ambulances!(sim::JEMSS.Simulation, ambulances::Vector{JEMSS.Ambulance})
    sim.ambulances = deepcopy(ambulances)
    sim.numAmbs = length(ambulances)

    # Initialize ambulances adding the wakeup event
    for ambulance in sim.ambulances
        JEMSS.initAmbulance!(sim, ambulance)
    end

    # Reset station statistics
    for station in sim.stations
        station.numIdleAmbsTotalDuration = JEMSS.OffsetVector(zeros(JEMSS.Float, sim.numAmbs + 1), 0:sim.numAmbs)
        station.currentNumIdleAmbsSetTime = sim.startTime
    end
end

end # module Replication