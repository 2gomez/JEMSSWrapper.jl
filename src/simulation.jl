"""
    simulate_custom!(sim::JEMSS.Simulation;
                    moveup_strategy::Union{Nothing, AbstractMoveUpStrategy} = nothing,
                    logger::Union{Nothing, MoveUpLogger} = nothing,
                    time::Real = Inf, 
                    duration::Real = Inf, 
                    numEvents::Real = Inf,
                    doPrint::Bool = false, 
                    printingInterval::Real = 1.0)

Run a simulation with optional custom move-up strategy.

Executes the simulation loop, processing events until completion or specified limits.
When `moveup_strategy` is provided, uses custom relocation logic; otherwise behaves
identically to standard JEMSS simulation.

# Arguments
- `sim::JEMSS.Simulation`: Simulation instance to run
- `moveup_strategy::Union{Nothing, AbstractMoveUpStrategy}`: Custom strategy (optional)
- `logger::Union{Nothing, MoveUpLogger}`: Logger of the move up decisions (optional)
- `time::Real`: Stop at this simulation time (default: Inf)
- `duration::Real`: Run for this duration (default: Inf)
- `numEvents::Real`: Stop after this many events (default: Inf)
- `doPrint::Bool`: Print progress during simulation (default: false)
- `printingInterval::Real`: Time between progress prints (default: 1.0)

# Examples
```julia
scenario = load_scenario_from_config("auckland", "base.toml")
sim = create_simulation_instance(scenario; seed=42)

# Run with custom strategy
strategy = MyStrategy(threshold=0.5)
simulate_custom!(sim; moveup_strategy=strategy)

# Get results
avg_response = JEMSS.getAvgCallResponseDuration(sim)
```
"""
function simulate_custom!(sim::JEMSS.Simulation;
                         moveup_strategy::Union{Nothing, AbstractMoveUpStrategy} = nothing,
                         logger::Union{Nothing, MoveUpLogger} = nothing,
                         time::Real = Inf, 
                         duration::Real = Inf, 
                         numEvents::Real = Inf,
                         doPrint::Bool = false, 
                         printingInterval::Real = 1.0)

    @assert(time == Inf || duration == Inf, "can only set one of: time, duration")
    @assert(time >= sim.time)
    @assert(duration >= 0)
    @assert(numEvents >= 0)
    @assert(printingInterval >= 1e-2, "printing too often can slow the simulation")

    duration != Inf && (time = sim.time + duration) # set end time based on duration

    # for printing progress
    startTime = Base.time()
    doPrint || (printingInterval = Inf)
    nextPrintTime = startTime + printingInterval
    eventCount = 0
    printProgress() = doPrint && print(@sprintf("\rsim time: %-9.2f sim duration: %-9.2f events simulated: %-9d real duration: %.2f seconds", sim.time, sim.time - sim.startTime, eventCount, Base.time() - startTime))

    # initialize strategy
    if !isnothing(moveup_strategy)
        initialize_strategy(moveup_strategy, sim)
    end

    # simulate
    stats = sim.stats # shorthand
    while !sim.complete && sim.eventList[end].time <= time && eventCount < numEvents
        if stats.doCapture && stats.nextCaptureTime <= sim.eventList[end].time
            JEMSS.captureSimStats!(sim, stats.nextCaptureTime)
        end

        simulate_next_event_custom!(sim, moveup_strategy, logger)
        eventCount += 1

        if doPrint && Base.time() >= nextPrintTime
            printProgress()
            nextPrintTime += printingInterval
        end
    end

    printProgress()
    doPrint && println()

    if stats.doCapture && sim.complete
        JEMSS.captureSimStats!(sim, sim.endTime)
        JEMSS.populateSimStats!(sim)
    end

    return sim.complete
end

# =============================================================================
# INTERNAL SIMULATION FUNCTIONS
# =============================================================================

"""
    simulate_next_event_custom!(sim::JEMSS.Simulation, 
                               moveup_strategy::Union{Nothing, AbstractMoveUpStrategy},
                               logger::Union{Nothing, MoveUpLogger})

Custom version of simulateNextEvent! with move-up strategy support.
"""
function simulate_next_event_custom!(sim::JEMSS.Simulation,
                                    moveup_strategy::Union{Nothing, AbstractMoveUpStrategy},
                                    logger::Union{Nothing, MoveUpLogger})
    # get next event, update event index and sim time
    event = JEMSS.getNextEvent!(sim.eventList)
    if event.form == JEMSS.nullEvent
        error()
    end
    sim.used = true
    sim.eventIndex += 1
    event.index = sim.eventIndex
    sim.time = event.time

    if sim.resim.use
        JEMSS.resimCheckCurrentEvent!(sim, event)
    elseif sim.writeOutput
        JEMSS.writeEventToFile!(sim, event)
    end

    simulate_event_custom!(sim, event, moveup_strategy, logger)

    if length(sim.eventList) == 0
        # simulation complete
        @assert(sim.endTime == JEMSS.nullTime)
        @assert(sim.complete == false)
        sim.endTime = sim.time
        sim.complete = true
        for amb in sim.ambulances
            JEMSS.setAmbStatus!(sim, amb, amb.status, sim.time) # to account for duration spent with final status
        end
    end
end

"""
    simulate_event_custom!(sim::JEMSS.Simulation, event::JEMSS.Event, 
                          moveup_strategy::Union{Nothing, AbstractMoveUpStrategy},
                          logger::Union{Nothing, MoveUpLogger})

Custom version of simulateEvent! with move-up strategy support.
"""
function simulate_event_custom!(sim::JEMSS.Simulation, event::JEMSS.Event, 
                                moveup_strategy::Union{Nothing, AbstractMoveUpStrategy},
                                logger::Union{Nothing, MoveUpLogger})
    @assert(sim.time == event.time)

    # Find event simulation function to match event form.
    form = event.form # shorthand
    if form == JEMSS.ambGoesToSleep
        JEMSS.simulateEventAmbGoesToSleep!(sim, event)
    elseif form == JEMSS.ambWakesUp
        JEMSS.simulateEventAmbWakesUp!(sim, event)
    elseif form == JEMSS.callArrives
        JEMSS.simulateEventCallArrives!(sim, event)
    elseif form == JEMSS.considerDispatch
        JEMSS.simulateEventConsiderDispatch!(sim, event)
    elseif form == JEMSS.ambDispatched
        simulate_event_amb_dispatched_custom!(sim, event, moveup_strategy)
    elseif form == JEMSS.ambMobilised
        JEMSS.simulateEventAmbMobilised!(sim, event)
    elseif form == JEMSS.ambReachesCall
        JEMSS.simulateEventAmbReachesCall!(sim, event)
    elseif form == JEMSS.ambGoesToHospital
        JEMSS.simulateEventAmbGoesToHospital!(sim, event)
    elseif form == JEMSS.ambReachesHospital
        JEMSS.simulateEventAmbReachesHospital!(sim, event)
    elseif form == JEMSS.ambBecomesFree
        simulate_event_amb_becomes_free_custom!(sim, event, moveup_strategy)
    elseif form == JEMSS.ambReturnsToStation
        JEMSS.simulateEventAmbReturnsToStation!(sim, event)
    elseif form == JEMSS.ambReachesStation
        JEMSS.simulateEventAmbReachesStation!(sim, event)
    elseif form == JEMSS.considerMoveUp
        simulate_event_consider_moveup_custom!(sim, event, moveup_strategy, logger)
    elseif form == JEMSS.ambMoveUpToStation
        JEMSS.simulateEventAmbMoveUpToStation!(sim, event)
    else
        error("Unknown event: ", form, ".")
    end
end

# =============================================================================
# CUSTOM EVENT HANDLERS
# =============================================================================

"""
    simulate_event_amb_dispatched_custom!(sim, event, moveup_strategy)

Custom handler for ambulance dispatch events that may trigger move-up consideration.
"""
function simulate_event_amb_dispatched_custom!(sim::JEMSS.Simulation, event::JEMSS.Event, moveup_strategy::Union{Nothing, AbstractMoveUpStrategy})
    # First, execute the original dispatch logic
    @assert(event.form == JEMSS.ambDispatched)
    ambulance = sim.ambulances[event.ambIndex]
    status = ambulance.status # shorthand
    @assert(JEMSS.isFree(status) || in(status, (JEMSS.ambMobilising, JEMSS.ambGoingToCall)))
    call = sim.calls[event.callIndex]
    @assert(in(call.status, (JEMSS.callScreening, JEMSS.callQueued, JEMSS.callWaitingForAmb))) # callWaitingForAmb if call bumped

    ambulance.callIndex = call.index
    ambulance.dispatchTime = sim.time
    mobiliseAmbulance = sim.mobilisationDelay.use && in(ambulance.status, (JEMSS.ambIdleAtStation, JEMSS.ambMobilising))
    if mobiliseAmbulance
        JEMSS.setAmbStatus!(sim, ambulance, JEMSS.ambMobilising, sim.time)
    else
        JEMSS.setAmbStatus!(sim, ambulance, JEMSS.ambGoingToCall, sim.time)
        JEMSS.changeRoute!(sim, ambulance.route, sim.responseTravelPriorities[call.priority], sim.time, call.location, call.nearestNodeIndex)
    end

    JEMSS.setCallStatus!(call, JEMSS.callWaitingForAmb, sim.time)
    call.ambIndex = event.ambIndex
    ambLoc = JEMSS.getRouteCurrentLocation!(sim.net, ambulance.route, sim.time)
    copy!(call.ambDispatchLoc, ambLoc)
    call.ambStatusBeforeDispatch = ambulance.prevStatus

    # stats
    if ambulance.prevStatus == JEMSS.ambIdleAtStation
        JEMSS.updateStationStats!(sim.stations[ambulance.stationIndex]; numIdleAmbsChange=-1, time=sim.time)
    end
    if sim.stats.recordDispatchStartLocCounts
        ambulance.dispatchStartLocCounts[ambLoc] = get(ambulance.dispatchStartLocCounts, ambLoc, 0) + 1
    end

    if mobiliseAmbulance
        mobilisationDelay = 0.0 # init
        if ambulance.prevStatus == JEMSS.ambMobilising
            # ambulance.mobilisation time unchanged
            @assert(ambulance.mobilisationTime != JEMSS.nullTime)
        else
            @assert(ambulance.prevStatus == JEMSS.ambIdleAtStation)
            ambulance.mobilisationTime = sim.time + rand(sim.mobilisationDelay.distrRng)
        end
        @assert(ambulance.mobilisationTime >= sim.time)
        JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.ambMobilised, time=ambulance.mobilisationTime, ambulance=ambulance, call=call)
    else
        JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.ambReachesCall, time=ambulance.route.endTime, ambulance=ambulance, call=call)
    end

    # Custom move-up consideration logic
    should_consider_moveup = should_trigger_moveup_on_dispatch(sim, moveup_strategy)
    if should_consider_moveup
        JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.considerMoveUp, time=sim.time, ambulance=ambulance, addEventToAmb=false)
    end
end

"""
    simulate_event_amb_becomes_free_custom!(sim, event, moveup_strategy)

Custom handler for ambulance becomes free events that may trigger move-up consideration.
"""
function simulate_event_amb_becomes_free_custom!(sim::JEMSS.Simulation, event::JEMSS.Event, moveup_strategy::Union{Nothing, AbstractMoveUpStrategy})
    # First, execute the original becomes free logic
    @assert(event.form == JEMSS.ambBecomesFree)
    ambulance = sim.ambulances[event.ambIndex]
    @assert(in(ambulance.status, (JEMSS.ambAtCall, JEMSS.ambAtHospital)))
    call = sim.calls[event.callIndex]
    @assert(in(call.status, (JEMSS.callOnSceneTreatment, JEMSS.callAtHospital)))

    # remove call, processing is finished
    delete!(sim.currentCalls, call)
    JEMSS.setCallStatus!(call, JEMSS.callProcessed, sim.time)

    JEMSS.setAmbStatus!(sim, ambulance, JEMSS.ambFreeAfterCall, sim.time)
    ambulance.callIndex = JEMSS.nullIndex

    # if queued call exists, respond
    # otherwise return to station
    if length(sim.queuedCallList) > 0
        call = JEMSS.getNextCall!(sim.queuedCallList)
        @assert(call !== nothing)

        # dispatch ambulance
        JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.ambDispatched, time=sim.time, ambulance=ambulance, call=call)
    else
        # return to station (can be cancelled by move up)
        JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.ambReturnsToStation, time=sim.time, ambulance=ambulance, station=sim.stations[ambulance.stationIndex])

        # Custom move-up consideration logic
        should_consider_moveup = should_trigger_moveup_on_free(sim, moveup_strategy)
        if should_consider_moveup
            JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.considerMoveUp, time=sim.time, ambulance=ambulance, addEventToAmb=false)
        end
    end
end

"""
    simulate_event_consider_moveup_custom!(sim, event, moveup_strategy)

Custom handler for move-up consideration events.
"""
function simulate_event_consider_moveup_custom!(sim::JEMSS.Simulation, event::JEMSS.Event, 
                                               moveup_strategy::Union{Nothing, AbstractMoveUpStrategy},
                                               logger::Union{Nothing, MoveUpLogger})
    @assert(event.form == JEMSS.considerMoveUp)
    ambulance = sim.ambulances[event.ambIndex] # ambulance that triggered consideration of move up
    @assert(event.callIndex == JEMSS.nullIndex)

    if moveup_strategy === nothing
        # No custom strategy - use original JEMSS logic (if enabled)
        if sim.moveUpData.useMoveUp
            # Call original JEMSS move-up logic
            JEMSS.simulateEventConsiderMoveUp!(sim, event)
        end
        # If move-up is disabled, do nothing (event is consumed)
    else
        # Use custom move-up strategy
        execute_moveup_strategy!(sim, event, ambulance, moveup_strategy, logger)
    end
end

# =============================================================================
# MOVE-UP STRATEGY FUNCTIONS
# =============================================================================

"""
    should_trigger_moveup_on_dispatch(sim, moveup_strategy)

Determine if move-up should be considered when an ambulance is dispatched.
"""
function should_trigger_moveup_on_dispatch(sim::JEMSS.Simulation, moveup_strategy::Union{Nothing, AbstractMoveUpStrategy})
    if moveup_strategy === nothing
        # Use original JEMSS logic
        return sim.moveUpData.useMoveUp && 
               in(sim.moveUpData.moveUpModule, (JEMSS.compTableModule, JEMSS.ddsmModule, JEMSS.multiCompTableModule, 
                                               JEMSS.zhangIpModule, JEMSS.temp0Module, JEMSS.temp1Module, JEMSS.temp2Module))
    else
        # Custom strategy determines triggering
        return should_trigger_on_dispatch(moveup_strategy, sim)
    end
end

"""
    should_trigger_moveup_on_free(sim, moveup_strategy)

Determine if move-up should be considered when an ambulance becomes free.
"""
function should_trigger_moveup_on_free(sim::JEMSS.Simulation, moveup_strategy::Union{Nothing, AbstractMoveUpStrategy})
    if moveup_strategy === nothing
        # Use original JEMSS logic
        return sim.moveUpData.useMoveUp && 
               in(sim.moveUpData.moveUpModule, (JEMSS.compTableModule, JEMSS.dmexclpModule, JEMSS.multiCompTableModule, 
                                               JEMSS.priorityListModule, JEMSS.zhangIpModule, JEMSS.temp0Module, 
                                               JEMSS.temp1Module, JEMSS.temp2Module))
    else
        # Custom strategy determines triggering
        return should_trigger_on_free(moveup_strategy, sim)
    end
end

"""
    execute_moveup_strategy!(sim, event, ambulance, strategy, logger)

Execute the custom move-up strategy.
"""
function execute_moveup_strategy!(sim::JEMSS.Simulation, event::JEMSS.Event, ambulance::JEMSS.Ambulance, 
                                 strategy::AbstractMoveUpStrategy, logger::Union{Nothing, MoveUpLogger})
    # Get move-up decisions from strategy
    (movableAmbs, ambStations, strategy_output) = decide_moveup(strategy, sim, ambulance)
    
    log_moveup!(logger, sim, ambulance, strategy, movableAmbs, ambStations, strategy_output)
    
    # Execute the moves (same as original JEMSS logic)
    for i in eachindex(movableAmbs)
        amb = movableAmbs[i]
        station = ambStations[i]

        # move up ambulance if ambulance station has changed
        if amb.stationIndex != station.index

            if JEMSS.isGoingToStation(amb.status) # amb.event.form == ambReachesStation
                # delete station arrival event for this ambulance
                JEMSS.deleteEvent!(sim.eventList, amb.event)
            elseif amb.status == JEMSS.ambFreeAfterCall && amb.event.form == JEMSS.ambReturnsToStation
                JEMSS.deleteEvent!(sim.eventList, amb.event)
            end

            JEMSS.addEvent!(sim.eventList; parentEvent=event, form=JEMSS.ambMoveUpToStation, time=sim.time, ambulance=amb, station=station)
        end
    end
end

"""
    log_moveup!(logger::Union{Nothing, MoveUpLogger}, 
                    sim::JEMSS.Simulation, ambulance::JEMSS.Ambulance, 
                    strategy::AbstractMoveUpStrategy, movableAmbs::Vector{JEMSS.Ambulance}, 
                    ambStations::Vector{JEMSS.Station}, strategy_output::Vector{Float64})

If the logger is not nothing, creates and add an entry of the move up decision in de logger registry.
"""
function log_moveup!(logger::Union{Nothing, MoveUpLogger}, 
                    sim::JEMSS.Simulation, ambulance::JEMSS.Ambulance, 
                    strategy::AbstractMoveUpStrategy, movableAmbs::Vector{JEMSS.Ambulance}, 
                    ambStations::Vector{JEMSS.Station}, strategy_output::Vector{Float64})
    if !isnothing(logger)
        encoded_state = encode_state(logger.encoder, sim, ambulance.index)
        
        log_entry = create_log_entry(
            strategy, 
            sim, 
            ambulance,
            encoded_state,
            strategy_output,
            movableAmbs,
            ambStations
        )
        
        add_entry!(logger, log_entry)
    end
end

"""
    simulate_scenario(scenario::ScenarioData;
                     moveup_strategy::Union{Nothing, AbstractMoveUpStrategy} = nothing,
                     logger::Union{Nothing, MoveUpLogger} = nothing,
                     time::Real = Inf, 
                     duration::Real = Inf, 
                     numEvents::Real = Inf,
                     doPrint::Bool = false, 
                     printingInterval::Real = 1.0)

"""
function simulate_scenario(scenario::ScenarioData;
                          moveup_strategy::Union{Nothing, AbstractMoveUpStrategy} = nothing,
                          logger::Union{Nothing, MoveUpLogger} = nothing,
                          time::Real = Inf, 
                          duration::Real = Inf, 
                          numEvents::Real = Inf,
                          doPrint::Bool = false,
                          printingInterval::Real = 1.0)::JEMSS.Simulation
    sim = create_simulation_instance(scenario)

    simulate_custom!(sim; moveup_strategy, logger, time, duration, numEvents, doPrint, printingInterval)
    
    return sim
end