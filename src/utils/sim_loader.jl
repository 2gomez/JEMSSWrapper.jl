using JEMSS
using Random
using PythonCall

struct WrappedSimulator
    simulator::Simulation
    calls::Vector{Vector{Call}}
end

function read_static_simulation_data(hospitals_file::String, stations_file::String, nodes_file::String, arcs_file::String, r_net_travel_file::String, map_file::String, priorities_file::String, travel_file::String, stats_file::String)
    
    sim = Simulation()
    sim.hospitals = readHospitalsFile(hospitals_file)
    sim.stations = readStationsFile(stations_file)

    sim.time = 0.0
    sim.startTime = 0.0

    sim.numHospitals = length(sim.hospitals)
    sim.numStations = length(sim.stations)

    # read network data
    sim.net = Network()
    net = sim.net # shorthand
    fGraph = net.fGraph # shorthand
    fGraph.nodes = readNodesFile(nodes_file)
    (fGraph.arcs, arcTravelTimes) = readArcsFile(arcs_file)

    # read rNetTravels from file, if saved
    
    if r_net_travel_file != ""
        rNetTravelsLoaded = readRNetTravelsFile(r_net_travel_file)
    else
        rNetTravelsLoaded = NetTravel[]
    end

    # read misc
    sim.map = readMapFile(map_file)
    map = sim.map # shorthand

    (sim.targetResponseDurations, sim.responseTravelPriorities) = readPrioritiesFile(priorities_file)
    sim.travel = readTravelFile(travel_file)
    
    # hard-coded grid size
    # grid rects will be roughly square, with one node per square on average
    n = length(fGraph.nodes)
    xDist = map.xRange * map.xScale
    yDist = map.yRange * map.yScale
    nx = Int(ceil(sqrt(n * xDist / yDist)))
    ny = Int(ceil(sqrt(n * yDist / xDist)))

    sim.grid = Grid(map, nx, ny)
    grid = sim.grid # shorthand
    JEMSS.gridPlaceNodes!(map, grid, fGraph.nodes)

    ##################
    # network

    JEMSS.initGraph!(fGraph)

    if any(arc -> isnan(arc.distance), fGraph.arcs)
        setArcDistances!(fGraph, map)
    end

    JEMSS.checkGraph(fGraph, map)

    JEMSS.initFNetTravels!(net, arcTravelTimes)

    JEMSS.createRGraphFromFGraph!(net)

    JEMSS.checkGraph(net.rGraph, map)

    JEMSS.createRNetTravelsFromFNetTravels!(net; rNetTravelsLoaded=rNetTravelsLoaded)
    

    ##################
    # travel

    travel = sim.travel # shorthand
    @assert(travel.setsStartTimes[1] <= sim.startTime)
    @assert(length(net.fNetTravels) == travel.numModes)
    for travelMode in travel.modes
        travelMode.fNetTravel = net.fNetTravels[travelMode.index]
        travelMode.rNetTravel = net.rNetTravels[travelMode.index]
    end

    for h in sim.hospitals
        (h.nearestNodeIndex, h.nearestNodeDist) = findNearestNode(map, grid, fGraph.nodes, h.location)
    end
    for s in sim.stations
        (s.nearestNodeIndex, s.nearestNodeDist) = findNearestNode(map, grid, fGraph.nodes, s.location)
    end


    sim.eventList = Vector{Event}()

    commonFNodes = sort(unique(vcat([h.nearestNodeIndex for h in sim.hospitals], [s.nearestNodeIndex for s in sim.stations])))
    JEMSS.setCommonFNodes!(net, commonFNodes)

    # find the nearest hospital to travel to from each node in fGraph
    numFNodes = length(fGraph.nodes) # shorthand
    for fNetTravel in net.fNetTravels
        fNetTravel.fNodeNearestHospitalIndex = Vector{Int}(undef, numFNodes)
        travelModeIndex = fNetTravel.modeIndex # shorthand
        travelMode = travel.modes[travelModeIndex] # shorthand
        for node in fGraph.nodes
            # find nearest hospital to node
            minTime = Inf
            nearestHospitalIndex = nullIndex
            for hospital in sim.hospitals
                travelTime = shortestPathTravelTime(net, travelModeIndex, node.index, hospital.nearestNodeIndex)
                travelTime += offRoadTravelTime(travelMode, hospital.nearestNodeDist)
                if travelTime < minTime
                    minTime = travelTime
                    nearestHospitalIndex = hospital.index
                end
            end
            fNetTravel.fNodeNearestHospitalIndex[node.index] = nearestHospitalIndex
        end
    end

    sim.addCallToQueue! = JEMSS.addCallToQueueSortPriorityThenTime!
    sim.findAmbToDispatch! = JEMSS.findNearestDispatchableAmb!
   

    # move up
    mud = sim.moveUpData # shorthand

    mud.useMoveUp = false
    mud.moveUpModule = nullMoveUpModule
    
    ##################
    # misc

    stats = sim.stats
    stats.doCapture = true
    dict = readStatsControlFile(stats_file)
    for fname in (:periodDurationsIter, :warmUpDuration, :recordResponseDurationHist, :responseDurationHistBinWidth)
        setfield!(stats, fname, dict[string(fname)])
    end
    stats.nextCaptureTime = sim.startTime + (stats.warmUpDuration > 0 ? stats.warmUpDuration : first(stats.periodDurationsIter))

    sim.initialised = true # at this point, the simulation could be run

    return sim
end

function copy_static_simulation_data(sim::Simulation)
    sim_copy = Simulation()
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
    sim_copy.eventList = Vector{Event}()
    for station in sim_copy.stations
        station.currentNumIdleAmbsSetTime = sim.startTime
    end
    sim_copy.initialised = sim.initialised
    return sim_copy
end

function set_ambulance_data!(simulation::Simulation, samu_locations::Vector{Bool}=nothing)

    simulation.numAmbs = (isnothing(samu_locations) ? 0 : sum(samu_locations)) 
    simulation.ambulances = Vector{Ambulance}(undef, simulation.numAmbs)
    j = 1
    if !isnothing(samu_locations)
        for (i, samu) in enumerate(samu_locations)
            if samu
                amb = Ambulance()
                amb.class = AmbClass(1)
                amb.stationIndex = i
                amb.index = j
                simulation.ambulances[j] = amb
                j += 1
            end
        end
    end
end

function set_calls_data!(sim::Simulation, calls::Vector{Call})
    sim.numReps = 1
    callSets = [deepcopy(calls)]
    setSimReps!(sim, callSets)
    sim.calls = callSets[1] # set sim.calls for first replication
    sim.numCalls = length(sim.calls)
    for c in sim.calls
        (c.nearestNodeIndex, c.nearestNodeDist) = findNearestNode(sim.map, sim.grid, sim.net.fGraph.nodes, c.location)
    end

    sim.addCallToQueue! = JEMSS.addCallToQueueSortPriorityThenTime!
    sim.findAmbToDispatch! = JEMSS.findNearestDispatchableAmb!

    JEMSS.addEvent!(sim.eventList, sim.calls[1])

    for station in sim.stations
        station.numIdleAmbsTotalDuration = JEMSS.OffsetVector(zeros(Float, sim.numAmbs + 1), 0:sim.numAmbs)
        station.currentNumIdleAmbsSetTime = sim.startTime
    end

    for a in sim.ambulances
        JEMSS.initAmbulance!(sim, a)
        # currently, this sets ambulances to wake up at start of sim, since wake up and sleep events are not in ambulances file yet
    end
end

function get_calls_response_duration(simulator::Simulation)
    total_response_duration = Dict( 1=> 0.0, 2=> 0.0, 3 => 0.0)
    total_calls_per_type = Dict( 1=> 0, 2=> 0, 3 => 0)
    for call in simulator.calls
        total_calls_per_type[Int(call.priority)] = total_calls_per_type[Int(call.priority)] + 1
        if (call.status != callProcessed)
            total_response_duration[Int(call.priority)] = total_response_duration[Int(call.priority)] + 100.0 
        else
            total_response_duration[Int(call.priority)] = total_response_duration[Int(call.priority)] + call.responseDuration 
        end
    end
    return total_calls_per_type, total_response_duration
end

function test_static_configuration_single_day_stations(simulator::Simulation, calls::Vector{Call}, station1::Int)
    solution = [false for _ in 1:simulator.numStations] # set all stations to false
    solution[station1] = true

    total_calls, total_time = test_static_configuration_single_day(simulator, calls, solution)
    fitness = total_time[1] / total_calls[1] # response duration for priority 1 calls
    return fitness
end

function test_static_configuration_single_day_stations(simulator::Simulation, calls::Vector{Call}, station1::Int, station2::Int)
    solution = [false for _ in 1:simulator.numStations] # set all stations to false
    solution[station1] = true
    solution[station2] = true
    
    total_calls, total_time  = test_static_configuration_single_day(simulator, calls, solution)
    fitness = total_time[1] / total_calls[1] # response duration for priority 1 calls
    return fitness
end

function calculate_importance_stations_selected(simulator::Simulation, calls_set::PyList, stations::PyList)
    stations = pyconvert(Vector{Int}, stations)
    calls_set = pyconvert(Vector{Vector{Call}}, calls_set)
    
    base_solution = [false for _ in 1:simulator.numStations] # set all stations to false
    for i in stations
        base_solution[i+1] = true
    end

    times = Vector{Float64}(undef, length(stations))
    for i in eachindex(stations)
        copied_solution = deepcopy(base_solution)
        copied_solution[stations[i]+1] = false
        total_calls, total_time = test_static_configuration(simulator, calls_set, copied_solution)
        times[i] = total_time[1] / total_calls[1] # response duration for priority 1 calls
    end

    return times
end


function calculate_synergies(simulator::Simulation, calls_set::PyList, selected_stations::PyList)
    selected_stations = pyconvert(Vector{Int}, selected_stations)
    #calls = pyconvert(Vector{Call}, calls)

    fitnesses = Vector{Task}(undef, length(selected_stations))
    
    @sync for i in eachindex(selected_stations)
        fitnesses[i] = Threads.@spawn test_static_configuration_single_day_stations(simulator, calls, selected_stations[i]+1)
    end

    configs_to_test = [(i,j) for i in 1:length(selected_stations) for j in (i+1):length(selected_stations)]
    
    results = Vector{Task}(undef, length(configs_to_test))
    
    @sync for (k, (i,j)) in enumerate(configs_to_test)
        results[k] = Threads.@spawn test_static_configuration_single_day_stations(simulator, calls, selected_stations[i]+1, selected_stations[j]+1)
    end

    matrix = zeros(simulator.numStations, simulator.numStations)
    for (k,(i,j)) in enumerate(configs_to_test)
        station_idx = selected_stations[i]+1
        station_jdx = selected_stations[j]+1
        combined_fitness = fetch(results[k])
        matrix[station_idx,station_jdx] = fetch(fitnesses[i]) - combined_fitness
        matrix[station_jdx,station_idx] = fetch(fitnesses[j]) - combined_fitness
        #println("Synergy between stations $i and $j: $(matrix[i,j]) and individual fitnesses $(fetch(fitnesses[i])) and $(fetch(fitnesses[j])), the combined fitness is $(combined_fitness)")
    end

    return matrix

end

function test_static_configuration_single_day(original_sim_object::Simulation, calls::Vector{Call}, samu_locations::Vector{Bool}=nothing)
    sim_copy = copy_static_simulation_data(original_sim_object)
    set_ambulance_data!(sim_copy, samu_locations)
    set_calls_data!(sim_copy, calls)
    simulate!(sim_copy)
    return get_calls_response_duration(sim_copy)
end

function test_static_configuration(original_sim_object::Simulation, calls_set::PyList, samu_locations::PyList{Any}=nothing)
    calls_set = pyconvert(Vector{Vector{Call}}, calls_set)
    if !isnothing(samu_locations)
        samu_locations = pyconvert(Vector{Bool}, samu_locations)
    end

    results = Vector{Task}(undef, length(calls_set))
    @sync for (i, calls) in enumerate(calls_set)
        results[i] = Threads.@spawn test_static_configuration_single_day(original_sim_object, calls, samu_locations)
    end

    total_response_duration = Dict( 1=> 0.0, 2=> 0.0, 3 => 0.0)
    total_calls_per_type = Dict( 1=> 0, 2=> 0, 3 => 0)

    for result in results
        calls_per_type, response_duration = fetch(result)
        for k in keys(total_calls_per_type)
            total_calls_per_type[k] += calls_per_type[k]
            total_response_duration[k] += response_duration[k]
        end
    end 
    return total_calls_per_type, total_response_duration
end

function test_static_configuration(original_sim_object::Simulation, calls_set::Vector{Vector{Call}}, samu_locations::Vector{Bool})
    
    results = Vector{Task}(undef, length(calls_set))
    @sync for (i, calls) in enumerate(calls_set)
        results[i] = Threads.@spawn test_static_configuration_single_day(original_sim_object, calls, samu_locations)
    end

    total_response_duration = Dict( 1=> 0.0, 2=> 0.0, 3 => 0.0)
    total_calls_per_type = Dict( 1=> 0, 2=> 0, 3 => 0)

    for result in results
        calls_per_type, response_duration = fetch(result)
        for k in keys(total_calls_per_type)
            total_calls_per_type[k] += calls_per_type[k]
            total_response_duration[k] += response_duration[k]
        end
    end 
    return total_calls_per_type, total_response_duration
end

