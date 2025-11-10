mutable struct NullStrategy <: AbstractMoveUpStrategy
    encoder::Union{AbstractEncoder, Nothing}
    trigger_on_dispatch::Bool
    trigger_on_free::Bool
    
    NullStrategy(trigger_on_dispatch::Bool = false,
                 trigger_on_free::Bool = true,
                 encoder::Union{AbstractEncoder, Nothing} = nothing) = new(encoder, trigger_on_dispatch, trigger_on_free)
end

JEMSSWrapper.should_trigger_on_dispatch(strategy::NullStrategy, ::JEMSS.Simulation) = strategy.trigger_on_dispatch 
JEMSSWrapper.should_trigger_on_free(strategy::NullStrategy, ::JEMSS.Simulation) = strategy.trigger_on_free

function JEMSSWrapper.decide_moveup(
    strategy::NullStrategy, 
    sim::JEMSS.Simulation, 
    triggering_ambulance::JEMSS.Ambulance
)
    movable_ambulances = JEMSS.Ambulance[triggering_ambulance]
    station = sim.stations[triggering_ambulance.stationIndex]
    target_stations = JEMSS.Station[station]
    strategy_output = get_default_network_output(strategy.encoder, sim, triggering_ambulance)
   
    return movable_ambulances, target_stations, strategy_output
end