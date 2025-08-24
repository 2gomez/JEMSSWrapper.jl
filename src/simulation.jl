"""
Simulation
==========

Unified simulation management including initialization and replication.
Consolidates functionality from initialization.jl and replication.jl.
"""
module Simulation

using JEMSS
using ..Types: SimulationConfig, ScenarioData

export initialize_simulation, set_ambulances_data!, initialize_calls, create_simulation_instances

# =============================================================================
# SIMULATION INITIALIZATION FUNCTIONS
# =============================================================================

"""
    initialize_simulation(config::SimulationConfig)

Initialize a complete simulation from configuration.
"""
function initialize_simulation(config::SimulationConfig)    
    # Create basic simulation
    sim = initialize_basic_simulation(config)
    
    # Setup network
    setup_network!(sim, config)
    
    # Setup travel system
    setup_travel_system!(sim)
    
    # Setup routing
    setup_location_routing!(sim)
    
    # Setup statistics
    setup_simulation_statistics!(sim, config.stats_file)
    
    sim.initialised = true
    
    return sim
end

"""
    set_ambulances_data!(sim::JEMSS.Simulation, ambulances_path::String)

Set the ambulances data in a simulation object.
"""
function set_ambulances_data!(sim::JEMSS.Simulation, ambulances_path::String)
    ambulances = JEMSS.readAmbsFile(ambulances_path)
    sim.ambulances = ambulances
    sim.numAmbs = length(ambulances)
end

"""
    initialize_calls(sim::JEMSS.Simulation, filepath::String, num_sets::Int = 1)

Initialize calls from CSV or XML file and split into sets.
"""
function initialize_calls(sim::JEMSS.Simulation, filepath::String, num_sets::Int = 1)
    # Load the calls
    if endswith(filepath, ".csv")
        calls, _ = JEMSS.readCallsFile(filepath)
    elseif endswith(filepath, ".xml")
        callGenConfig = JEMSS.readGenConfig(filepath)
        calls = JEMSS.makeCalls(callGenConfig)
    else
        throw(ArgumentError("Unsupported file format. Use .csv or .xml"))
    end

    # Find nearest nodes
    for call in calls
        (call.nearestNodeIndex, call.nearestNodeDist) = JEMSS.findNearestNode(sim.map, sim.grid, sim.net.fGraph.nodes, call.location)
    end

    return split_vector(calls, num_sets)
end

# =============================================================================
# SIMULATION REPLICATION FUNCTIONS
# =============================================================================

"""
    create_simulation_instances(scenario::ScenarioData)

Create simulation instances for each call set in the scenario.
"""
function create_simulation_instances(scenario::ScenarioData)
    base_sim = scenario.base_simulation
    call_sets = scenario.call_sets
    
    instances = Vector{JEMSS.Simulation}(undef, length(call_sets))
    
    for (i, calls) in enumerate(call_sets)
        sim_copy = copy_base_simulation(base_sim)
        add_calls!(sim_copy, calls)
        instances[i] = sim_copy
    end

    return instances
end

# =============================================================================
# INTERNAL/HELPER FUNCTIONS
# =============================================================================

"""
    initialize_basic_simulation(config::SimulationConfig)

Initialize basic simulation structures.
"""
function initialize_basic_simulation(config::SimulationConfig)
    sim = JEMSS.Simulation()
    
    # Load basic data
    sim.hospitals = JEMSS.readHospitalsFile(config.hospitals_file)
    sim.stations = JEMSS.readStationsFile(config.stations_file)

    # Setup basic properties
    sim.time = 0.0
    sim.startTime = 0.0
    sim.numHospitals = length(sim.hospitals)
    sim.numStations = length(sim.stations)
    sim.eventList = Vector{JEMSS.Event}()
    
    # Setup map and priorities
    sim.map = JEMSS.readMapFile(config.map_file)
    (sim.targetResponseDurations, sim.responseTravelPriorities) = JEMSS.readPrioritiesFile(config.priorities_file)
    sim.travel = JEMSS.readTravelFile(config.travel_file)
    
    # Setup basic behavior
    sim.addCallToQueue! = JEMSS.addCallToQueueSortPriorityThenTime!
    sim.findAmbToDispatch! = JEMSS.findNearestDispatchableAmb!
    sim.moveUpData.useMoveUp = false
    sim.moveUpData.moveUpModule = JEMSS.nullMoveUpModule

    return sim
end

"""
    setup_network!(sim, config::SimulationConfig)

Setup the road network and graph.
"""
function setup_network!(sim, config::SimulationConfig)
    sim.net = JEMSS.Network()
    
    # Setup graph
    sim.net.fGraph.nodes = JEMSS.readNodesFile(config.nodes_file)
    (sim.net.fGraph.arcs, arcTravelTimes) = JEMSS.readArcsFile(config.arcs_file)
    rNetTravelsLoaded = load_r_net_travels(config.r_net_travel_file)
    
    nx, ny = calculate_grid_dimensions(sim.net.fGraph.nodes, sim.map)
    sim.grid = JEMSS.Grid(sim.map, nx, ny)
    JEMSS.gridPlaceNodes!(sim.map, sim.grid, sim.net.fGraph.nodes)

    JEMSS.initGraph!(sim.net.fGraph)
    
    # Set arc distances if needed
    if any(arc -> isnan(arc.distance), sim.net.fGraph.arcs)
        JEMSS.setArcDistances!(sim.net.fGraph, sim.map)
    end
    
    JEMSS.checkGraph(sim.net.fGraph, sim.map)
    JEMSS.initFNetTravels!(sim.net, arcTravelTimes)
    JEMSS.createRGraphFromFGraph!(sim.net)
    JEMSS.checkGraph(sim.net.rGraph, sim.map)
    JEMSS.createRNetTravelsFromFNetTravels!(sim.net; rNetTravelsLoaded=rNetTravelsLoaded)
end

"""
    setup_travel_system!(sim)

Setup travel modes and link to network.
"""
function setup_travel_system!(sim)
    # Validate travel configuration
    @assert(sim.travel.setsStartTimes[1] <= sim.startTime)
    @assert(length(sim.net.fNetTravels) == sim.travel.numModes)
    
    # Link travel modes to network
    for travelMode in sim.travel.modes
        travelMode.fNetTravel = sim.net.fNetTravels[travelMode.index]
        travelMode.rNetTravel = sim.net.rNetTravels[travelMode.index]
    end
       
    for hospital in sim.hospitals
        hospital.nearestNodeIndex, hospital.nearestNodeDist = 
            JEMSS.findNearestNode(sim.map, sim.grid, sim.net.fGraph.nodes, hospital.location)
    end
    
    for station in sim.stations
        station.nearestNodeIndex, station.nearestNodeDist = 
            JEMSS.findNearestNode(sim.map, sim.grid, sim.net.fGraph.nodes, station.location)
    end
    
    # Setup common nodes
    hospitalNodes = [h.nearestNodeIndex for h in sim.hospitals]
    stationNodes = [s.nearestNodeIndex for s in sim.stations]
    commonFNodes = sort(unique(vcat(hospitalNodes, stationNodes)))
    JEMSS.setCommonFNodes!(sim.net, commonFNodes)
end

"""
    setup_location_routing!(sim)

Setup routing to hospitals.
"""
function setup_location_routing!(sim)
    numFNodes = length(sim.net.fGraph.nodes)
    
    for fNetTravel in sim.net.fNetTravels
        fNetTravel.fNodeNearestHospitalIndex = Vector{Int}(undef, numFNodes)
        travelMode = sim.travel.modes[fNetTravel.modeIndex]
        
        for node in sim.net.fGraph.nodes
            nearestHospitalIndex = find_nearest_hospital_to_node(node, sim.hospitals, sim.net, travelMode)
            fNetTravel.fNodeNearestHospitalIndex[node.index] = nearestHospitalIndex
        end
    end
end

"""
    setup_simulation_statistics!(sim, stats_file::String)

Setup simulation statistics.
"""
function setup_simulation_statistics!(sim, stats_file::String)
    stats = sim.stats
    stats.doCapture = true
    
    config_dict = JEMSS.readStatsControlFile(stats_file)
    
    # Apply configuration
    stat_fields = (:periodDurationsIter, :warmUpDuration, :recordResponseDurationHist, 
                   :responseDurationHistBinWidth)
    
    for field_name in stat_fields
        field_key = string(field_name)
        if haskey(config_dict, field_key)
            setfield!(stats, field_name, config_dict[field_key])
        end
    end
    
    warmup_duration = stats.warmUpDuration > 0 ? stats.warmUpDuration : first(stats.periodDurationsIter)
    stats.nextCaptureTime = sim.startTime + warmup_duration
end

"""
    copy_base_simulation(sim::JEMSS.Simulation)

Create a deep copy of a base simulation for replication.
"""
function copy_base_simulation(sim::JEMSS.Simulation)
    sim_copy = JEMSS.Simulation()
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
    
    # Reset station statistics
    for station in sim_copy.stations
        station.numIdleAmbsTotalDuration = JEMSS.OffsetVector(zeros(JEMSS.Float, sim.numAmbs + 1), 0:sim.numAmbs)
        station.currentNumIdleAmbsSetTime = sim.startTime
    end
    
    sim_copy.addCallToQueue! = sim.addCallToQueue!
    sim_copy.findAmbToDispatch! = sim.findAmbToDispatch!

    sim_copy.eventList = Vector{JEMSS.Event}()
    
    # Initialize ambulances
    for ambulance in sim_copy.ambulances
        JEMSS.initAmbulance!(sim_copy, ambulance)
    end

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

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

"""
    calculate_grid_dimensions(nodes, map)

Calculate optimal grid dimensions for node placement.
"""
function calculate_grid_dimensions(nodes, map)
    n = length(nodes)
    xDist = map.xRange * map.xScale
    yDist = map.yRange * map.yScale
    nx = Int(ceil(sqrt(n * xDist / yDist)))
    ny = Int(ceil(sqrt(n * yDist / xDist)))
    return nx, ny
end

"""
    load_r_net_travels(r_net_travel_file::String)

Load R-network travels if file exists, otherwise return empty array.
"""
function load_r_net_travels(r_net_travel_file::String)
    return isempty(r_net_travel_file) ? JEMSS.NetTravel[] : JEMSS.readRNetTravelsFile(r_net_travel_file)
end

"""
    find_nearest_hospital_to_node(node, hospitals, net, travelMode)

Find the nearest hospital to a given node using travel time.
"""
function find_nearest_hospital_to_node(node, hospitals, net, travelMode)
    minTime = Inf
    nearestHospitalIndex = JEMSS.nullIndex
    
    for hospital in hospitals
        travelTime = JEMSS.shortestPathTravelTime(net, travelMode.index, 
                                                 node.index, hospital.nearestNodeIndex)
        travelTime += JEMSS.offRoadTravelTime(travelMode, hospital.nearestNodeDist)
        
        if travelTime < minTime
            minTime = travelTime
            nearestHospitalIndex = hospital.index
        end
    end
    
    return nearestHospitalIndex
end

"""
    split_vector(vector::Vector, num_parts::Int)

Split a vector into roughly equal parts.
"""
function split_vector(vector::Vector, num_parts::Int)
    @assert num_parts > 0 "Number of parts must be positive"
    
    length_part = length(vector) ÷ num_parts
    remainder = length(vector) % num_parts
    
    parts = Vector{Vector}(undef, num_parts)
    start_index = 1
    
    for i in 1:num_parts
        current_length = length_part + (i <= remainder ? 1 : 0)
        parts[i] = vector[start_index:start_index+current_length-1]
        start_index += current_length
    end
    
    return parts
end

end # module Simulation