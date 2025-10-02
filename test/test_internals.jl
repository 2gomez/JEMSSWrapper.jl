@testset "Internal Tests" begin
    
    @testset "Config file validation" begin
        @test_throws ArgumentError create_config_from_toml(
            "nonexistent.toml",
            "/some/path"
        )
    end

    @testset "Required files validation" begin
        mktempdir() do tmpdir
            config_path = joinpath(tmpdir, "config.toml")
            models_dir = joinpath(tmpdir, "models")
            mkdir(models_dir)
            
            touch(joinpath(models_dir, "hospitals.csv"))
            touch(joinpath(models_dir, "stations.csv"))
            touch(joinpath(models_dir, "nodes.csv"))
            touch(joinpath(models_dir, "arcs.csv"))
            touch(joinpath(models_dir, "r_net_travels.jls"))
            touch(joinpath(models_dir, "map.csv"))
            touch(joinpath(models_dir, "travel.csv"))
            touch(joinpath(models_dir, "priorities.csv"))
            touch(joinpath(models_dir, "stats.csv"))
            touch(joinpath(models_dir, "ambulances.csv"))
            touch(joinpath(models_dir, "calls.csv"))
            
            write(config_path, """
                [metadata]
                name = "test_scenario"
                
                [files]
                hospitals = "hospitals.csv"
                stations = "stations.csv"
                nodes = "nodes.csv"
                arcs = "arcs.csv"
                r_net_travels = "r_net_travels.jls"
                map = "map.csv"
                travel = "travel.csv"
                priorities = "priorities.csv"
                stats = "stats.csv"
                
                [defaults]
                ambulances = "ambulances.csv"
                calls = "calls.csv"
            """)
            
            config = create_config_from_toml(config_path, tmpdir)
            @test config.config_name == "test_scenario"
            @test isfile(config.hospitals_file)
        end
    end

    @testset "Initialization and replication of a Simulation" begin
        scenario_name = "auckland"
        scenario_path = joinpath(SCENARIOS_DIR, scenario_name)
        config_path = joinpath(scenario_path, "configs", "base.toml")
        
        if !isdir(scenario_path)
            @test_skip "Scenario directory not found: $scenario_path"
            return
        end
        
        config = create_config_from_toml(config_path, scenario_path)
        
        sim = initialize_basic_simulation(config) 
        @test !isnothing(sim)
        
        setup_network!(sim, config)
        setup_travel_system!(sim)
        setup_location_routing!(sim)
        setup_simulation_statistics!(sim, config.stats_file)
        
        calls = initialize_calls(sim, config.default_calls_file) 
        ambulances = initialize_ambulances(config.default_ambulances_file)
        @test !isnothing(calls)
        @test !isnothing(ambulances)

        sim_copy = copy_base_simulation(sim)
        @test !isnothing(sim_copy)
        
        add_calls!(sim_copy, calls)
        add_calls!(sim, calls)
        add_ambulances!(sim_copy, ambulances)
        add_ambulances!(sim, ambulances)
        
        sim_copy.initialised = true
        sim.initialised = true
        
        @test_nowarn simulate!(sim_copy) 
        @test_nowarn simulate!(sim)
    end
    
end