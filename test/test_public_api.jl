@testset "Public API Tests" begin
    scenario_name = "auckland"
    config_name = "base.toml"

    @testset "Default load scenario" begin
        @test_throws ArgumentError scenario = load_scenario_from_config(
            "non-existing-scenario",
            config_name
        )

        scenario = load_scenario_from_config(scenario_name, config_name)
        @test !isnothing(scenario)

        sim = create_simulation_instance(scenario)
        @test !isnothing(sim)

        @test_nowarn JEMSS.simulate!(sim)
    end


    test_data_path = joinpath(dirname(@__FILE__), "data")
    ambulances_path = joinpath(test_data_path, "auckland_ambulances.csv")
    calls_path = joinpath(test_data_path, "auckland_call.csv")
   
    @testset "Loading an Scenario with custom calls and ambulances" begin
        @test_throws ArgumentError scenario = load_scenario_from_config(
            scenario_name,
            config_name;
            ambulances_path = "non-existing-ambulances-file",
            calls_path = "non_existing-calls-file"
        ) 

        scenario = load_scenario_from_config(
            scenario_name,
            config_name;
            ambulances_path = ambulances_path,
            calls_path = calls_path
        ) 

        @test scenario.metadata["calls_path"] == calls_path
        @test scenario.metadata["ambulances_path"] == ambulances_path

        sim = create_simulation_instance(scenario)
        
        @test_nowarn JEMSS.simulate!(sim)

    end

    base_scenario = load_scenario_from_config(scenario_name, config_name)
    original_calls_path = base_scenario.metadata["calls_path"]
    original_ambulances_path = base_scenario.metadata["ambulances_path"]
    
    @testset "Update calls and ambulances" begin
        scenario_custom = update_scenario_calls(base_scenario, calls_path)
        scenario_custom = update_scenario_ambulances(scenario_custom, ambulances_path)        

        new_calls_path = scenario_custom.metadata["calls_path"] 
        new_ambulances_path = scenario_custom.metadata["ambulances_path"]
        @test original_calls_path != new_calls_path && new_calls_path == calls_path 
        @test original_ambulances_path != new_ambulances_path && new_ambulances_path == ambulances_path 

        sim = create_simulation_instance(scenario_custom)

        @test_nowarn JEMSS.simulate!(sim)
    end

    @testset "Simulation execution" begin
        sim_01 = create_simulation_instance(base_scenario)
        sim_02 = create_simulation_instance(base_scenario)

        @test_nowarn JEMSS.simulate!(sim_01)
        @test_nowarn simulate_custom!(sim_02)

        @test JEMSS.getAvgCallResponseDuration(sim_01) == JEMSS.getAvgCallResponseDuration(sim_02)
        @test JEMSS.getCallsReachedInTime(sim_01) == JEMSS.getCallsReachedInTime(sim_02)
    end

    @testset "Strategy Interface" begin
        
        # Test 1: AbstractMoveUpStrategy is exported
        @test isdefined(JEMSSWrapper, :AbstractMoveUpStrategy)
        @test AbstractMoveUpStrategy isa Type
        
        # Test 2: Interface methods are exported
        @test isdefined(JEMSSWrapper, :should_trigger_on_dispatch)
        @test isdefined(JEMSSWrapper, :should_trigger_on_free)
        @test isdefined(JEMSSWrapper, :decide_moveup)
        
        # Test 3: Can create concrete strategy
        struct TestStrategy <: AbstractMoveUpStrategy
            value::Int
        end
        
        @test TestStrategy <: AbstractMoveUpStrategy
        test_strat = TestStrategy(42)
        @test test_strat.value == 42
        
        # Test 4: Incomplete implementation throws error
        @test_throws MethodError should_trigger_on_dispatch(test_strat, nothing)
        @test_throws MethodError should_trigger_on_free(test_strat, nothing)
        @test_throws MethodError decide_moveup(test_strat, nothing, nothing)
        
        # Test 5: Complete implementation works
        JEMSSWrapper.should_trigger_on_dispatch(::TestStrategy, sim::JEMSS.Simulation) = true
        JEMSSWrapper.should_trigger_on_free(::TestStrategy, sim::JEMSS.Simulation) = false
        JEMSSWrapper.decide_moveup(::TestStrategy, sim::JEMSS.Simulation, amb::JEMSS.Ambulance) = (JEMSS.Ambulance[], JEMSS.Station[], []) 
        
        sim_test = create_simulation_instance(base_scenario)
        @test should_trigger_on_dispatch(test_strat, sim_test) == true
        @test should_trigger_on_free(test_strat, sim_test) == false
        @test decide_moveup(test_strat, sim_test, sim_test.ambulances[1]) == (JEMSS.Ambulance[], JEMSS.Station[], [])

        # Test 6: Simulate complete simluation execution
        sim_01 = create_simulation_instance(base_scenario)
        sim_02 = create_simulation_instance(base_scenario)
        
        simulate_custom!(sim_01) 
        simulate_custom!(sim_02; moveup_strategy = test_strat)

        @test JEMSS.getAvgCallResponseDuration(sim_01) == JEMSS.getAvgCallResponseDuration(sim_02)
        @test JEMSS.getCallsReachedInTime(sim_01) == JEMSS.getCallsReachedInTime(sim_02)
    end

end