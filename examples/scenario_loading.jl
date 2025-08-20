#!/usr/bin/env julia

"""
Scenario Loading Example
========================

Demonstrates how to load scenarios using the new JEMSSWrapper functionality.
This example shows the basic workflow without running actual simulations.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JEMSSWrapper

function demonstrate_scenario_loading()
    println("=== JEMSSWrapper Scenario Loading Demo ===\n")
    
    # Example 1: List available scenarios
    println("1. Listing available scenarios:")
    try
        scenarios = JEMSSWrapper.ScenarioLoader.list_available_scenarios()
        if isempty(scenarios)
            println("   No scenarios found in default directory")
            println("   Note: Create scenarios in the 'scenarios/' directory")
        else
            for scenario in scenarios
                println("   - $scenario")
            end
        end
    catch e
        println("   Error listing scenarios: $e")
    end
    
    println()
    
    # Example 2: Load scenario configuration (without full initialization)
    println("2. Loading scenario configuration:")
    scenario_name = "example_scenario"  # Replace with actual scenario
    
    try
        config = JEMSSWrapper.ScenarioLoader.load_scenario_config(scenario_name)
        println("   ✅ Configuration loaded successfully")
        println("   Scenario: $(config.scenario_name)")
        println("   Calls date: $(config.calls_date)")
        println("   Path: $(config.scenario_path)")
        
        # Show some file paths
        println("   Key files:")
        println("     - Ambulances: $(basename(config.ambulance_file))")
        println("     - Hospitals: $(basename(config.hospitals_file))")
        println("     - Calls: $(basename(config.calls_file))")
        
    catch e
        if isa(e, JEMSSWrapper.ScenarioValidation.ValidationError)
            println("   ❌ Validation error: $(e.message)")
            if !isempty(e.missing_files)
                println("   Missing files:")
                for file in e.missing_files[1:min(3, length(e.missing_files))]
                    println("     - $file")
                end
                if length(e.missing_files) > 3
                    println("     ... and $(length(e.missing_files) - 3) more")
                end
            end
        else
            println("   ❌ Error: $e")
        end
        println("   Note: This is expected if no real scenario data is available")
    end
    
    println()
    
    # Example 3: Demonstrate full scenario loading (if data available)
    println("3. Full scenario loading:")
    try
        scenario_data = JEMSSWrapper.load_scenario(scenario_name, "2019-1-1")
        println("   ✅ Scenario loaded successfully!")
        println(scenario_data)
        
        # Show scenario info
        info = JEMSSWrapper.ScenarioLoader.get_scenario_info(scenario_data)
        println("\n   Scenario details:")
        for (key, value) in info["metadata"]
            if key != "loaded_at"
                println("     $key: $value")
            end
        end
        
    catch e
        if isa(e, JEMSSWrapper.ScenarioValidation.ValidationError)
            println("   ❌ Cannot load scenario: validation failed")
            println("   This is expected without real scenario data")
        else
            println("   ❌ Error loading scenario: $e")
        end
    end
    
    println()
    
    # Example 4: Show how to use different date specifications
    println("4. Date specification examples:")
    date_examples = ["2019", "2019-01", "2019-01-15"]
    
    for date_spec in date_examples
        try
            calls_file = JEMSSWrapper.PathUtils.resolve_calls_file("/example/calls", date_spec)
            println("   $date_spec -> $(basename(dirname(calls_file)))/$(basename(calls_file))")
        catch e
            println("   $date_spec -> Error: $e")
        end
    end
    
    println("\n=== Demo Complete ===")
    println("\nNext steps:")
    println("1. Create a scenario in the 'scenarios/' directory")
    println("2. Use the policy evaluation example to test with real data")
    println("3. Implement custom policies for neuroevolution")
end

if abspath(PROGRAM_FILE) == @__FILE__
    demonstrate_scenario_loading()
end