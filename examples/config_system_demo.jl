#!/usr/bin/env julia

"""
Configuration System Examples
=============================

Demonstrates the new TOML-based configuration system for JEMSSWrapper.
Shows various ways to load scenarios with flexible file specifications.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JEMSSWrapper

function demonstrate_config_system()
    println("=== JEMSSWrapper TOML Configuration System Demo ===\n")
    
    scenario_name = "auckland"
    
    # Example 1: Generate a default config file
    println("1. Generating default configuration file...")
    try
        config_path = JEMSSWrapper.generate_default_config(scenario_name, "base")
        println("   ✅ Generated: $config_path")
        
        # Show the generated content
        println("   Preview of generated config:")
        content = read(config_path, String)
        lines = split(content, '\n')[1:15]  # Show first 15 lines
        for line in lines
            println("     $line")
        end
        println("     ... (truncated)")
        
    catch e
        println("   ⚠️  Could not generate config: $e")
    end
    
    println()
    
    # Example 2: List available configs
    println("2. Listing available configurations...")
    try
        configs = JEMSSWrapper.list_scenario_configs(scenario_name)
        if isempty(configs)
            println("   No configs found - this is expected without setup")
        else
            for config in configs
                println("   - $config")
            end
        end
    catch e
        println("   ⚠️  Error listing configs: $e")
    end
    
    println()
    
    # Example 3: Load scenario with config (basic)
    println("3. Loading scenario with TOML config...")
    try
        scenario = JEMSSWrapper.load_scenario_from_config(scenario_name, "base")
        println("   ✅ Scenario loaded successfully!")
        println("   Config: $(basename(scenario.metadata["config_file"]))")
        println("   Calls: $(scenario.metadata["calls_date"])")
        
    catch e
        println("   ⚠️  Could not load scenario: $e")
        println("   This is expected without real scenario data")
    end
    
    println()
    
    # Example 4: Load with calls date override
    println("4. Loading with calls date override...")
    show_example_call("base", calls_date="2019-01-15")
    
    println()
    
    # Example 5: Load with file overrides
    println("5. Loading with file overrides...")
    overrides = Dict(
        "ambulances" => "ambulances/variant1.csv",
        "hospitals" => "hospitals/variant1.csv"
    )
    show_example_call("base", overrides=overrides)
    
    println()
    
    # Example 6: Load with direct calls file
    println("6. Loading with direct calls file...")
    show_example_call("base", calls_file="calls/special/custom_scenario.csv")
    
    println()
    
    # Example 7: Load from direct config file path
    println("7. Loading from direct config file path...")
    try
        config_path = "/path/to/custom/config.toml"
        println("   JEMSSWrapper.load_scenario_from_config_file(\"$config_path\")")
        println("   (Would load if file existed)")
    catch e
        println("   Example call shown - would work with real config file")
    end
    
    println()
    
    # Example 8: Policy evaluation workflow
    println("8. Complete workflow example...")
    demonstrate_complete_workflow()
    
    println("\n=== Configuration System Demo Complete ===")
    print_summary()
end

function show_example_call(config_name::String; kwargs...)
    call_str = "JEMSSWrapper.load_scenario_from_config(\"auckland\", \"$config_name\""
    
    if haskey(kwargs, :calls_date)
        call_str *= "; calls_date=\"$(kwargs[:calls_date])\""
    end
    
    if haskey(kwargs, :calls_file)
        call_str *= "; calls_file=\"$(kwargs[:calls_file])\""
    end
    
    if haskey(kwargs, :overrides)
        call_str *= "; overrides=$( kwargs[:overrides])"
    end
    
    call_str *= ")"
    
    println("   $call_str")
    println("   (Would load if scenario data existed)")
end

function demonstrate_complete_workflow()
    println("   Complete neuroevolution workflow:")
    println()
    
    workflow_code = """
    # 1. Load scenario once with specific config
    scenario = JEMSSWrapper.load_scenario_from_config("auckland", "base"; 
                                                     calls_date="2019-01-15")
    
    # 2. Create different policies to evaluate
    policies = [
        JEMSSWrapper.create_standard_policy("standard"),
        JEMSSWrapper.create_standard_policy("dmexclp"),
        # Future: NeuralMoveUpPolicy(neural_network_function)
    ]
    
    # 3. Evaluate each policy
    all_results = []
    for policy in policies
        results = JEMSSWrapper.evaluate_policy(scenario, policy; num_replications=5)
        push!(all_results, results...)
    end
    
    # 4. Extract fitness metrics for neuroevolution
    fitness_scores = [mean([r.mean_response_time for r in results if r.success]) 
                     for results in all_results]
    """
    
    for line in split(workflow_code, '\n')
        if !isempty(strip(line))
            println("   $line")
        end
    end
end

function print_summary()
    println("\n📋 Configuration System Summary:")
    println("================================")
    
    println("\n🎯 Key Benefits:")
    println("• Flexible file specification without hardcoded paths")
    println("• Multiple configurations per scenario")
    println("• Easy file overrides for experiments")
    println("• Backward compatibility with existing API")
    println("• Self-documenting TOML format with comments")
    
    println("\n📁 File Structure:")
    println("scenarios/")
    println("└── auckland/")
    println("    ├── configs/")
    println("    │   ├── base.toml          # Standard configuration")
    println("    │   ├── variant1.toml      # Alternative setup")
    println("    │   └── experiment.toml    # Experiment-specific")
    println("    └── data/")
    println("        ├── ambulances/")
    println("        ├── hospitals/")
    println("        └── calls/")
    
    println("\n🔄 Migration Path:")
    println("1. Current API still works: load_scenario(\"auckland\", \"2019-01-15\")")
    println("2. Generate configs: generate_default_config(\"auckland\", \"base\")")
    println("3. Use new API: load_scenario_from_config(\"auckland\", \"base\")")
    println("4. Gradually migrate to config-first approach")
    
    println("\n🚀 Next Steps:")
    println("• Create your scenario configs using generate_default_config()")
    println("• Test with load_scenario_from_config()")
    println("• Use overrides for experimental variations")
    println("• Integrate with neural network policies in Phase 2")
end

if abspath(PROGRAM_FILE) == @__FILE__
    demonstrate_config_system()
end