"""
SimulationInitialization
========================

Core Simulation initialization functionality adapted from the original modules.
"""
module SimulationInitialization

using JEMSS
using ..ConfigLoader: SimulationConfig

export initialize_simulation, set_ambulances_data!, create_simulation_copy, initialize_calls


"""
    initialize_calls(filepath::String, num_sets::Int = 1)

Initialize the calls from a CSV file with the calls or from a XML generation call configuration file.
Then the calls are splitted different sets.
"""
function initialize_calls(sim::JEMSS.Simulation, filepath::String, num_sets::Int = 1)
    
    # Load the calls
    if endswith(filepath, ".csv")
        calls, _ = JEMSS.readCallsFile(filepath)
    elseif endswith(filepath, ".xml")
        callGenConfig = JEMSS.readGenConfig(filepath)
        calls = JEMSS.makeCalls(callGenConfig)
    end

    # Find nearest nodes
    for call in calls
        (call.nearestNodeIndex, call.nearestNodeDist) = findNearestNode(sim.map, sim.grid, sim.net.fGraph.nodes, call.location)
    end

    return split_vector(calls, num_sets)
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
    initialize_simulation(config::SimulationConfig)

Initialize a complete simulation from configuration.

# Arguments
- `config::SimulationConfig`: Configuration with file paths

# Returns
- `JEMSS.Simulation`: Initialized JEMSS Simulation object of the Simulation
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

# Helper functions
function calculate_grid_dimensions(nodes, map)
    n = length(nodes)
    xDist = map.xRange * map.xScale
    yDist = map.yRange * map.yScale
    nx = Int(ceil(sqrt(n * xDist / yDist)))
    ny = Int(ceil(sqrt(n * yDist / xDist)))
    return nx, ny
end

function load_r_net_travels(r_net_travel_file::String)
    return isempty(r_net_travel_file) ? JEMSS.NetTravel[] : JEMSS.readRNetTravelsFile(r_net_travel_file)
end

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

end # module SimulationInitialization