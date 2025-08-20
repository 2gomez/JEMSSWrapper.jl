#!/usr/bin/env julia

"""
Policy Evaluation Example
=========================

Demonstrates how to evaluate policies using the JEMSSWrapper.
Shows the complete workflow from loading scenarios to running evaluations.
"""

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using JEMSSWrapper

function demonstrate_policy_evaluation()
    println("=== JEMSSWrapper Policy Evaluation Demo ===\n")
    
    # Configuration
    scenario_name = "example_scenario"
    calls_date = "2019-1-1"
    num_replications = 2
    
    println("Configuration:")
    println("  Scenario: $scenario_name")
    println("  Calls date: $calls_date")
    println("  Replications: $num_replications")
    println()
    
    # Step 1: Load scenario
    println("Step 1: Loading scenario...")
    try
        scenario_data = JEMSSWrapper.load_scenario(scenario_name, calls_date)
        println("✅ Scenario loaded successfully!")
        println(scenario_data)
        println()
        
        # Step 2: Create policies to evaluate
        println("Step 2: Creating policies...")
        policies = [
            JEMSSWrapper.create_standard_policy("standard"),
            JEMSSWrapper.create_standard_policy("dmexclp")
        ]
        
        for (i, policy) in enumerate(policies)
            println("  Policy $i: $(JEMSSWrapper.PolicyInterface.get_policy_name(policy))")
        end
        println()
        
        # Step 3: Evaluate each policy
        println("Step 3: Evaluating policies...")
        all_results = []
        
        for (i, policy) in enumerate(policies)
            policy_name = JEMSSWrapper.PolicyInterface.get_policy_name(policy)
            println("  Evaluating policy: $policy_name")
            
            try
                results = JEMSSWrapper.evaluate_policy(scenario_data, policy; 
                                                     num_replications=num_replications)
                push!(all_results, results...)
                
                # Show quick summary
                successful = count(r -> r.success, results)
                println("    ✅ Completed: $successful/$num_replications replications")
                
                if successful > 0
                    successful_results = filter(r -> r.success, results)
                    avg_response = sum(r -> r.mean_response_time, successful_results) / successful
                    println("    Average response time: $(round(avg_response, digits=2)) time units")
                end
                
            catch e
                println("    ❌ Evaluation failed: $e")
            end
            println()
        end
        
        # Step 4: Print detailed results
        if !isempty(all_results)
            println("Step 4: Detailed Results")
            println("=" ^ 40)
            JEMSSWrapper.EvaluationRunner.print_results(all_results)
        end
        
    catch e
        if isa(e, JEMSSWrapper.ScenarioValidation.ValidationError)
            println("❌ Cannot load scenario: validation failed")
            println("This is expected without real scenario data")
            println("\nTo run this example with real data:")
            println("1. Create a scenario directory in 'scenarios/$scenario_name'")
            println("2. Populate it with the required data files")
            println("3. Run this example again")
        else
            println("❌ Error: $e")
        end
    end
    
    println("\n=== Demo Complete ===")
    println("\nThis example shows the basic workflow for policy evaluation.")
    println("In a real neuroevolution setup, you would:")
    println("1. Load the scenario once")
    println("2. Create neural network policies")
    println("3. Evaluate many policies in parallel")
    println("4. Use the results for fitness evaluation")
end

function demo_policy_creation()
    println("\n=== Policy Creation Examples ===")
    
    # Standard policies
    println("Standard policies:")
    standard_policies = [
        JEMSSWrapper.create_standard_policy("standard"),
        JEMSSWrapper.create_standard_policy("dmexclp")
    ]
    
    for policy in standard_policies
        name = JEMSSWrapper.PolicyInterface.get_policy_name(policy)
        println("  - $name")
    end
    
    # Show how to create policy with parameters
    println("\nPolicy with parameters:")
    dmexclp_policy = JEMSSWrapper.StandardMoveUpPolicy("dmexclp")
    dmexclp_policy.parameters["busyFraction"] = 0.3
    println("  - DMEXCLP with busyFraction=0.3")
    
    println("\nIn future phases, you'll be able to create:")
    println("  - NeuralMoveUpPolicy(neural_network_function)")
    println("  - CustomMoveUpPolicy(decision_function)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    demonstrate_policy_evaluation()
    demo_policy_creation()
end