# =========================================================================
# NeuronalStrategy Tests
# =========================================================================

@testset "NeuronalStrategy - Construction" begin
    encoder = SimpleEncoder()
    network = SimpleNetwork(4, 5)
    
    strategy = JEMSSWrapper.NeuronalStrategy(encoder, network)
    
    @test strategy isa JEMSSWrapper.NeuronalStrategy
    @test strategy.trigger_on_dispatch == false
    @test strategy.trigger_on_free == true
    
    # Custom triggers
    strategy2 = JEMSSWrapper.NeuronalStrategy(
        encoder, network,
        trigger_on_dispatch=true,
        trigger_on_free=false
    )
    
    @test strategy2.trigger_on_dispatch == true
    @test strategy2.trigger_on_free == false
end

@testset "NeuronalStrategy - decide_moveup" begin
    encoder = SimpleEncoder()
    network = SimpleNetwork(4, 5)
    strategy = JEMSSWrapper.NeuronalStrategy(encoder, network)
    
    scenario = load_test_scenario()
    if !isnothing(scenario)
        sim = JEMSSWrapper.create_simulation_instance(scenario)
        movable, targets = JEMSSWrapper.decide_moveup(strategy, sim, sim.ambulances[1])
        
        @test length(movable) == 1
        @test length(targets) == 1
        @test targets[1] isa JEMSS.Station
    end
end

@testset "NeuronalStrategy - With Logger" begin
    encoder = SimpleEncoder()
    network = SimpleNetwork(4, 5)
    logger = JEMSSWrapper.MoveUpLogger(encoder)
    strategy = JEMSSWrapper.NeuronalStrategy(encoder, network, logger=logger)
    
    scenario = load_test_scenario()
    if !isnothing(scenario)
        sim = JEMSSWrapper.create_simulation_instance(scenario)
        JEMSSWrapper.decide_moveup(strategy, sim, sim.ambulances[1])
        
        @test JEMSSWrapper.num_entries(logger) == 1
        
        entry = JEMSSWrapper.get_entries(logger)[1]
        @test entry.strategy_type == "NeuronalStrategy"
        @test length(entry.decisions) == 1
        @test length(entry.strategy_output) == 5
        @test sum(entry.strategy_output) ≈ 1.0
    end
end