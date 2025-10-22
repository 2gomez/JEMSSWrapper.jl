# =============================================================================
# MAIN INITIALIZATION FUNCTIONS
# =============================================================================

"""
    initialize_simulation(config::ScenarioConfig)

Initialize a complete simulation from configuration.
"""
function initialize_simulation(config::ScenarioConfig)    
    sim = initialize_basic_simulation(config)
    
    setup_network!(sim, config)
    
    setup_travel_system!(sim)
    
    setup_location_routing!(sim)
    
    setup_simulation_statistics!(sim, config.stats_file)
    
    sim.initialised = true
    
    return sim
end

"""
    initialize_calls(sim::JEMSS.Simulation, filepath::String)

Initialize calls from CSV or XML file and split into sets.
"""
function initialize_calls(sim::JEMSS.Simulation, filepath::String)
    # Load calls
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
        call.hospitalIndex = JEMSS.nearestHospitalToCall!(sim, call, lowPriority)
    end

    return calls
end

"""
    initialize_ambulances(filepath::String)

Load ambulances from a CSV file.
"""
function initialize_ambulances(filepath::String)
    return JEMSS.readAmbsFile(filepath)
end

# =============================================================================
# INTERNAL FUNCTIONS
# =============================================================================

"""
    initialize_basic_simulation(config::ScenarioConfig)

Initialize basic simulation structures.
"""
function initialize_basic_simulation(config::ScenarioConfig)
    sim = JEMSS.Simulation()
    
    # Load basic data and properties
    sim.hospitals = JEMSS.readHospitalsFile(config.hospitals_file)
    sim.stations = JEMSS.readStationsFile(config.stations_file)
    sim.time = 0.0
    sim.startTime = 0.0
    sim.numHospitals = length(sim.hospitals)
    sim.numStations = length(sim.stations)
    sim.eventList = Vector{JEMSS.Event}()
    
    # Setup map and priorities
    sim.map = JEMSS.readMapFile(config.map_file)
    (sim.targetResponseDurations, sim.responseTravelPriorities) = JEMSS.readPrioritiesFile(config.priorities_file)
    sim.travel = JEMSS.readTravelFile(config.travel_file)
    
    # Setup demand
    if !isempty(config.demand_coverage_file)
        sim.demandCoverage = JEMSS.readDemandCoverageFile(config.demand_coverage_file)
    end
    
    sim.inputFiles = Dict{String,File}()
    demand_file = JEMSS.File()
    demand_file.path = config.demand_file
    sim.inputFiles["demand"] = demand_file 
    demand_coverage_file = JEMSS.File()
    demand_coverage_file.path= config.demand_coverage_file
    sim.inputFiles["demandCoverage"] = demand_coverage_file 

    # Setup basic behavior
    sim.addCallToQueue! = JEMSS.addCallToQueueSortPriorityThenTime!
    sim.findAmbToDispatch! = JEMSS.findNearestDispatchableAmb!
    sim.moveUpData.useMoveUp = false
    sim.moveUpData.moveUpModule = JEMSS.nullMoveUpModule

    return sim
end

"""
    setup_network!(sim, config::ScenarioConfig)

Setup the road network and graph.
"""
function setup_network!(sim, config::ScenarioConfig)
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
    if rNetTravelsLoaded != []
        JEMSS.createRNetTravelsFromFNetTravels!(sim.net; rNetTravelsLoaded=rNetTravelsLoaded)
    else
        JEMSS.createRNetTravelsFromFNetTravels!(sim.net)
        JEMSS.writeRNetTravelsFile(config.r_net_travel_file, sim.net.rNetTravels)
    end
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
       
    # Setup hospitals and stations map locations
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

# =============================================================================
# UTILITY INITIALIZATION FUNCTIONS
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
    return isempty(r_net_travel_file) || !isfile(r_net_travel_file) ? JEMSS.NetTravel[] : JEMSS.readRNetTravelsFile(r_net_travel_file)
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