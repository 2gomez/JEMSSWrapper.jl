"""
Replication
==========

Extended replication utilities including strategy replication support.
"""

module Replication

using JEMSS
using ..Types: ScenarioData
using ..MoveUp: AbstractMoveUpStrategy

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