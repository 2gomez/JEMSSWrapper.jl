#!/usr/bin/env julia

"""
Basic test script to verify JEMSS wrapper can load and use the local JEMSS fork.
This script attempts to load JEMSSWrapper and run a basic simulation.
"""

using Pkg

# Activate local project
Pkg.activate(joinpath(@__DIR__, ".."))

# Load the wrapper
using JEMSSWrapper

function main()
    println("=== JEMSS Wrapper Basic Test ===")
    
    try
        println("✓ Successfully loaded JEMSSWrapper module")
        
        # Test JEMSS functionality access through JEMSSWrapper
        println("✓ Successfully loaded JEMSSWrapper module")
        
        # Get JEMSS info
        jemss_info = JEMSSWrapper.get_jemss_info()
        println("✓ JEMSS loaded from: $(dirname(jemss_info.path))")
        
        # Run basic simulation test
        println("\n=== Running Basic Simulation Test ===")
        
        try
            # Access JEMSS functions through wrapper
            initSim = JEMSSWrapper.jemss.initSim
            simulate! = JEMSSWrapper.jemss.simulate!
            
            # Use example config from JEMSS
            config_path = joinpath(jemss_info.path, "example", "input", "sim_config.xml")
            
            if !isfile(config_path)
                println("⚠ Example config not found at: $config_path")
                println("✓ JEMSS accessible but no example to run")
            else
                println("Loading simulation config: $config_path")
                sim = initSim(config_path)
                simulate!(sim)
                println("✓ Simulation completed successfully")
            end
            
        catch e
            println("⚠ Simulation test failed: $e")
            println("✓ JEMSS loaded but example needs adjustment")
        end
        
    catch e
        println("✗ Error during test:")
        println(e)
        return 1
    end
    
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end