"""
SimulationReplication
========================

Core Simulation initialization functionality adapted from the original modules.
"""
module SimulationReplication

using JEMSS
using ..ScenarioLoader: Scenario

export create_simulation_instances

"""
    create_simulation_instances(scenario::Scenario)

Given an scenario, with its base simulation and the sets of calls. Create the instances of
simulation for each call set.

# Arguments
- `scenario::Scenario` Object with the base simulation and the sets of calls

# Returns
- `Vector{JEMSS.Simulation}`: Vector of simulations with the sets of calls
"""
function create_simulation_instances(scenario::Scenario)
    base_sim = scenario.base_sim
    calls_sets = scenario.calls_sets
    
    instances = Vector{JEMSS.Simulation}(undef, length(calls_sets))
    
    for (i, calls) in enumerate(calls_sets)
        sim_copy = copy_base_simulation(base_sim)
        add_calls!(sim_copy, calls)
        instances[i] = sim_copy
    end

    return instances
end

"""
    copy_base_simulation(sim::JEMSS.Simulation)

Creates a copy of a base simulation.
"""
function copy_base_simulation(sim::JEMSS.Simulation)
    sim_copy = Simulation()
    sim_copy.time = 0.0
    sim_copy.startTime = 0.0
    sim_copy.numAmbs = sim.numAmbs
    sim_copy.numHospitals = sim.numHospitals
    sim_copy.numStations = sim.numStations
    sim_copy.ambulances = deepcopy(sim.ambulances)
    sim_copy.hospitals = deepcopy(sim.hospitals)
    sim_copy.stations = deepcopy(sim.stations)
    sim_copy.net = sim.net # shallow copy, this is the heavy part of the object
    sim_copy.map = deepcopy(sim.map)
    sim_copy.targetResponseDurations = deepcopy(sim.targetResponseDurations)
    sim_copy.responseTravelPriorities = deepcopy(sim.responseTravelPriorities)
    sim_copy.travel = sim.travel # shallow copy, this is the heavy part of the object
    sim_copy.grid = deepcopy(sim.grid)
    for station in sim_copy.stations
        station.numIdleAmbsTotalDuration = JEMSS.OffsetVector(zeros(JEMSS.Float, sim.numAmbs + 1), 0:sim.numAmbs)
        station.currentNumIdleAmbsSetTime = sim.startTime
    end
    sim_copy.addCallToQueue! = sim.addCallToQueue!
    sim_copy.findAmbToDispatch! = sim.findAmbToDispatch!

    sim_copy.eventList = Vector{Event}()
    for ambulance in sim_copy.ambulances
        JEMSS.initAmbulance!(sim_copy, ambulance)
    end

    sim_copy.initialised = sim.initialised
    return sim_copy
end

"""
    add_calls!(sim)

Add a vector of calls to the simulation.
"""
function add_calls!(sim::JEMSS.Simulation, calls::Vector{JEMSS.Call})
    sim.calls = deepcopy(calls)
    sim.numCalls = length(calls)
    JEMSS.addEvent!(sim.eventList, sim.calls[1])
end

end # end module SimulationReplication