mutable struct NullStrategy <: AbstractMoveUpStrategy
    trigger_on_dispatch::Bool
    trigger_on_free::Bool
    
    NullStrategy(trigger_on_dispatch::Bool = false,
                 trigger_on_free::Bool = true) = new(trigger_on_dispatch, trigger_on_free)
end

JEMSSWrapper.should_trigger_on_dispatch(strategy::NullStrategy, ::JEMSS.Simulation) = strategy.trigger_on_dispatch 
JEMSSWrapper.should_trigger_on_free(strategy::NullStrategy, ::JEMSS.Simulation) = strategy.trigger_on_free

function JEMSSWrapper.decide_moveup(
    strategy::NullStrategy, 
    sim::JEMSS.Simulation, 
    triggering_ambulance::JEMSS.Ambulance
)
    movable_ambulances = JEMSS.Ambulance[]
    target_stations = JEMSS.Station[]
        
    strategy_output = zeros(Float64, sim.numStations)
    strategy_output[triggering_ambulance.stationIndex] = 1.0
   
    return movable_ambulances, target_stations, strategy_output
end