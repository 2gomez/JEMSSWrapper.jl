"""
SimulationInitialization
========================

Core simulation initialization functionality adapted from the original modules.
"""
module SimulationInitialization

using ..ScenarioConfig: SimulationConfig
using ..ScenarioValidation: validate_config

export initialize_simulation, create_simulation_copy

"""
    initialize_simulation(config::SimulationConfig)

Initialize a complete simulation from configuration.

# Arguments
- `config::SimulationConfig`: Configuration with file paths

# Returns
- Initialized JEMSS Simulation object
"""
function initialize_simulation(config::SimulationConfig)
    # Validate configuration
    validate_config(config)
    
    # Access JEMSS through the wrapper
    JEMSS = Main.JEMSSWrapper.jemss
    
    # Create basic simulation
    sim = initialize_basic_simulation(config, JEMSS)
    
    # Setup network
    setup_network!(sim, config, JEMSS)
    
    # Setup travel system
    setup_travel_system!(sim, JEMSS)
    
    # Setup routing
    setup_location_routing!(sim, JEMSS)
    
    # Setup statistics
    setup_simulation_statistics!(sim, config.stats_file, JEMSS)
    
    # Finalize initialization
    finalize_simulation_initialization!(sim, JEMSS)
    
    sim.initialised = true
    return sim
end

"""
    initialize_basic_simulation(config::SimulationConfig, JEMSS)

Initialize basic simulation structures.
"""
function initialize_basic_simulation(config::SimulationConfig, JEMSS)
    sim = JEMSS.Simulation()
    
    # Load basic data
    sim.ambulances = JEMSS.readAmbsFile(config.ambulance_file)
    sim.hospitals = JEMSS.readHospitalsFile(config.hospitals_file)
    sim.stations = JEMSS.readStationsFile(config.stations_file)
    (sim.calls, sim.startTime) = JEMSS.readCallsFile(config.calls_file)
    
    # Setup basic properties
    sim.time = 0.0
    sim.numAmbs = length(sim.ambulances)
    sim.numCalls = length(sim.calls)
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
    
    return sim
end

"""
    setup_network!(sim, config::SimulationConfig, JEMSS)

Setup the road network and graph.
"""
function setup_network!(sim, config::SimulationConfig, JEMSS)
    sim.net = JEMSS.Network()
    
    # Setup graph
    sim.net.fGraph.nodes = JEMSS.readNodesFile(config.nodes_file)
    (sim.net.fGraph.arcs, arcTravelTimes) = JEMSS.readArcsFile(config.arcs_file)
    
    JEMSS.initGraph!(sim.net.fGraph)
    
    # Set arc distances if needed
    if any(arc -> isnan(arc.distance), sim.net.fGraph.arcs)
        JEMSS.setArcDistances!(sim.net.fGraph, sim.map)
    end
    
    JEMSS.checkGraph(sim.net.fGraph, sim.map)
    JEMSS.initFNetTravels!(sim.net, arcTravelTimes)
    
    # Setup grid
    nx, ny = calculate_grid_dimensions(sim.net.fGraph.nodes, sim.map)
    sim.grid = JEMSS.Grid(sim.map, nx, ny)
    JEMSS.gridPlaceNodes!(sim.map, sim.grid, sim.net.fGraph.nodes)
    
    # Load r_net_travels if available
    rNetTravelsLoaded = load_r_net_travels(config.r_net_travel_file, JEMSS)
    
    JEMSS.createRGraphFromFGraph!(sim.net)
    JEMSS.checkGraph(sim.net.rGraph, sim.map)
    JEMSS.createRNetTravelsFromFNetTravels!(sim.net; rNetTravelsLoaded=rNetTravelsLoaded)
end

"""
    setup_travel_system!(sim, JEMSS)

Setup travel modes and link to network.
"""
function setup_travel_system!(sim, JEMSS)
    # Validate travel configuration
    @assert(sim.travel.setsStartTimes[1] <= sim.startTime)
    @assert(length(sim.net.fNetTravels) == sim.travel.numModes)
    
    # Link travel modes to network
    for travelMode in sim.travel.modes
        travelMode.fNetTravel = sim.net.fNetTravels[travelMode.index]
        travelMode.rNetTravel = sim.net.rNetTravels[travelMode.index]
    end
    
    # Setup location nearest nodes
    for call in sim.calls
        call.nearestNodeIndex, call.nearestNodeDist = 
            JEMSS.findNearestNode(sim.map, sim.grid, sim.net.fGraph.nodes, call.location)
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
    setup_location_routing!(sim, JEMSS)

Setup routing to hospitals.
"""
function setup_location_routing!(sim, JEMSS)
    numFNodes = length(sim.net.fGraph.nodes)
    
    for fNetTravel in sim.net.fNetTravels
        fNetTravel.fNodeNearestHospitalIndex = Vector{Int}(undef, numFNodes)
        travelMode = sim.travel.modes[fNetTravel.modeIndex]
        
        for node in sim.net.fGraph.nodes
            nearestHospitalIndex = find_nearest_hospital_to_node(node, sim.hospitals, sim.net, travelMode, JEMSS)
            fNetTravel.fNodeNearestHospitalIndex[node.index] = nearestHospitalIndex
        end
    end
end

"""
    setup_simulation_statistics!(sim, stats_file::String, JEMSS)

Setup simulation statistics.
"""
function setup_simulation_statistics!(sim, stats_file::String, JEMSS)
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
    finalize_simulation_initialization!(sim, JEMSS)

Complete simulation initialization.
"""
function finalize_simulation_initialization!(sim, JEMSS)
    # Add first call to event list
    if !isempty(sim.calls)
        JEMSS.addEvent!(sim.eventList, sim.calls[1])
    end
    
    # Initialize station tracking
    for station in sim.stations
        station.numIdleAmbsTotalDuration = JEMSS.OffsetVector(zeros(Float64, sim.numAmbs + 1), 0:sim.numAmbs)
        station.currentNumIdleAmbsSetTime = sim.startTime
    end
    
    # Initialize ambulances
    for ambulance in sim.ambulances
        JEMSS.initAmbulance!(sim, ambulance)
    end
end

"""
    create_simulation_copy(sim)

Create a deep copy of simulation data for multiple runs.
"""
function create_simulation_copy(sim)
    JEMSS = Main.JEMSSWrapper.jemss
    
    sim_copy = JEMSS.Simulation()
    sim_copy.time = 0.0
    sim_copy.startTime = 0.0
    sim_copy.numHospitals = sim.numHospitals
    sim_copy.numStations = sim.numStations
    sim_copy.ambulances = deepcopy(sim.ambulances)
    sim_copy.hospitals = deepcopy(sim.hospitals)
    sim_copy.stations = deepcopy(sim.stations)
    sim_copy.calls = deepcopy(sim.calls)
    sim_copy.net = sim.net # shallow copy
    sim_copy.map = deepcopy(sim.map)
    sim_copy.targetResponseDurations = deepcopy(sim.targetResponseDurations)
    sim_copy.responseTravelPriorities = deepcopy(sim.responseTravelPriorities)
    sim_copy.travel = sim.travel # shallow copy
    sim_copy.grid = deepcopy(sim.grid)
    sim_copy.eventList = Vector{JEMSS.Event}()
    
    sim_copy.addCallToQueue! = JEMSS.addCallToQueueSortPriorityThenTime!
    sim_copy.findAmbToDispatch! = JEMSS.findNearestDispatchableAmb!
    JEMSS.addEvent!(sim_copy.eventList, sim_copy.calls[1])
    
    for station in sim_copy.stations
        station.numIdleAmbsTotalDuration = JEMSS.OffsetVector(zeros(Float64, sim.numAmbs + 1), 0:sim.numAmbs)
        station.currentNumIdleAmbsSetTime = sim.startTime
    end
    sim_copy.initialised = sim.initialised
    
    for ambulance in sim.ambulances
        JEMSS.initAmbulance!(sim_copy, ambulance)
    end
    
    return sim_copy
end

# Helper functions

function calculate_grid_dimensions(nodes, map)
    n = length(nodes)
    xDist = map.xRange * map.xScale
    yDist = map.yRange * map.yScale
    nx = Int(ceil(sqrt(n * xDist / yDist)))
    ny = Int(ceil(sqrt(n * yDist / xDist)))
    return nx, ny
end

function load_r_net_travels(r_net_travel_file::String, JEMSS)
    return isempty(r_net_travel_file) ? JEMSS.NetTravel[] : JEMSS.readRNetTravelsFile(r_net_travel_file)
end

function find_nearest_hospital_to_node(node, hospitals, net, travelMode, JEMSS)
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

end # module SimulationInitialization