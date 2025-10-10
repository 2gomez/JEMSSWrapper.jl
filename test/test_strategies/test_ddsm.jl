@testset "DDSMStrategy - Construction" begin
    strategy = JEMSSWrapper.DDSMStrategy()
    
    @test strategy isa JEMSSWrapper.DDSMStrategy
    @test strategy.cover_fraction_target_t1 == 0.5
    @test strategy.travel_time_cost == 50.0
    @test strategy.trigger_on_dispatch == false
    @test strategy.trigger_on_free == true
    @test strategy.initialized == false
end

@testset "DDSMStrategy - Parameter Validation" begin
    # Invalid parameters
    @test_throws AssertionError JEMSSWrapper.DDSMStrategy(cover_fraction_target_t1=1.5)
    @test_throws AssertionError JEMSSWrapper.DDSMStrategy(solver=:invalid)
    @test_throws AssertionError JEMSSWrapper.DDSMStrategy(bin_tolerance=0.2)
end

@testset "DDSMStrategy - Custom Config" begin
    strategy = JEMSSWrapper.DDSMStrategy(
        cover_fraction_target_t1=0.7,
        travel_time_cost=100.0,
        solver=:glpk
    )
    
    @test strategy.cover_fraction_target_t1 == 0.7
    @test strategy.travel_time_cost == 100.0
    @test strategy.solver == :glpk
end

@testset "DDSMStrategy - With Simulation" begin
    scenario = load_test_scenario()
    
    if isnothing(scenario)
        @test_skip "Scenario not available for DDSM test"
    else
        sim = JEMSSWrapper.create_simulation_instance(scenario)
        strategy = JEMSSWrapper.DDSMStrategy(solver=:cbc)
        
        # Initialize strategy (required for DDSM)
        @test strategy.initialized == false
        JEMSSWrapper.initialize_strategy(strategy, sim)
        @test strategy.initialized == true
        @test length(strategy.cover_times) == 2
        
        # Execute move-up decision
        movable, targets = JEMSSWrapper.decide_moveup(strategy, sim, sim.ambulances[1])
        
        # Verify basic results
        @test movable isa Vector{JEMSS.Ambulance}
        @test targets isa Vector{JEMSS.Station}
        @test length(movable) == length(targets)
    end
end

@testset "DDSMStrategy - With Logger" begin
    scenario = load_test_scenario()
    
    if !isnothing(scenario)
        sim = JEMSSWrapper.create_simulation_instance(scenario)
        
        encoder = SimpleEncoder()
        logger = JEMSSWrapper.MoveUpLogger(encoder)
        strategy = JEMSSWrapper.DDSMStrategy(solver=:cbc, logger=logger)
        
        JEMSSWrapper.initialize_strategy(strategy, sim)
        JEMSSWrapper.decide_moveup(strategy, sim, sim.ambulances[1])
        
        # Verify logging worked
        @test JEMSSWrapper.num_entries(logger) == 1
        entry = JEMSSWrapper.get_entries(logger)[1]
        @test entry.strategy_type == "DDSMStrategy"
    end
end
