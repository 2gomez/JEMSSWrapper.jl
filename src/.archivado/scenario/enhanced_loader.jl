# src/scenario/enhanced_loader.jl
"""
Enhanced scenario loading with TOML configuration support.
This extends the existing loader.jl with new functions.
"""

using .ConfigLoader
using .ScenarioValidation: validate_config
using ..SimulationInitialization: initialize_simulation
using .ScenarioLoader: ScenarioData
using Dates

export load_scenario_from_config, load_scenario_from_config_file, generate_default_config

"""
    load_scenario_from_config(scenario_name::String, config_name::String; 
                             scenarios_base_dir::String = "",
                             calls_date::String = "",
                             calls_file::String = "",
                             overrides::Dict{String, String} = Dict{String, String}())

Load a scenario using a TOML configuration file.

# Arguments
- `scenario_name::String`: Name of the scenario
- `config_name::String`: Name of the config file (with or without .toml extension)
- `scenarios_base_dir::String`: Base directory containing scenarios
- `calls_date::String`: Optional calls date specification (yyyy, yyyy-mm, yyyy-mm-dd)
- `calls_file::String`: Optional direct calls file path
- `overrides::Dict{String, String}`: Optional file path overrides

# Returns
- `ScenarioData`: Loaded scenario data ready for evaluation

# Examples
```julia
# Basic usage
scenario = load_scenario_from_config("wellington", "base")

# With calls date override
scenario = load_scenario_from_config("wellington", "base"; calls_date="2019-01-15")

# With file overrides
scenario = load_scenario_from_config("wellington", "base"; 
    overrides=Dict("ambulances" => "ambulances/variant2.csv"))

# With direct calls file
scenario = load_scenario_from_config("wellington", "base"; 
    calls_file="calls/special/custom.csv")
```
"""
function load_scenario_from_config(scenario_name::String, config_name::String; 
                                  scenarios_base_dir::String = "",
                                  calls_date::String = "",
                                  calls_file::String = "",
                                  overrides::Dict{String, String} = Dict{String, String}())
    
    @info "Loading scenario from config: $scenario_name/$config_name"
    
    # Resolve and load config file
    config_path = ConfigLoader.resolve_config_path(scenario_name, config_name, scenarios_base_dir)
    config_data = ConfigLoader.load_config_file(config_path)
    
    # Validate config structure
    ConfigLoader.validate_config_structure(config_data)
    
    # Create simulation config
    sim_config = ConfigLoader.create_config_from_toml(config_data; 
        calls_date=calls_date, calls_file=calls_file, overrides=overrides)
    
    # Use existing loading infrastructure
    return load_scenario_from_sim_config(sim_config, config_data)
end

"""
    load_scenario_from_config_file(config_file_path::String; 
                                  calls_date::String = "",
                                  calls_file::String = "",
                                  overrides::Dict{String, String} = Dict{String, String}())

Load a scenario using a direct path to a TOML configuration file.

# Arguments
- `config_file_path::String`: Direct path to the TOML configuration file
- `calls_date::String`: Optional calls date specification
- `calls_file::String`: Optional direct calls file path
- `overrides::Dict{String, String}`: Optional file path overrides

# Returns
- `ScenarioData`: Loaded scenario data ready for evaluation
"""
function load_scenario_from_config_file(config_file_path::String; 
                                       calls_date::String = "",
                                       calls_file::String = "",
                                       overrides::Dict{String, String} = Dict{String, String}())
    
    @info "Loading scenario from config file: $config_file_path"
    
    # Load config file
    config_data = ConfigLoader.load_config_file(config_file_path)
    
    # Validate config structure
    ConfigLoader.validate_config_structure(config_data)
    
    # Create simulation config
    sim_config = ConfigLoader.create_config_from_toml(config_data; 
        calls_date=calls_date, calls_file=calls_file, overrides=overrides)
    
    # Use existing loading infrastructure
    return load_scenario_from_sim_config(sim_config, config_data)
end

"""
    load_scenario_from_sim_config(sim_config::SimulationConfig, config_data::ConfigData)

Internal function to load scenario from SimulationConfig and ConfigData.
"""
function load_scenario_from_sim_config(sim_config::SimulationConfig, config_data::ConfigData)
    # Validate configuration
    validate_config(sim_config; check_files=get(config_data.options, "validate_files", true))
    
    # Initialize simulation
    @info "Initializing simulation..."
    base_sim = initialize_simulation(sim_config)
    
    # Create enhanced metadata
    metadata = Dict{String, Any}(
        "loaded_at" => now(),
        "config_file" => config_data.config_path,
        "config_metadata" => config_data.metadata,
        "scenario_name" => sim_config.scenario_name,
        "calls_date" => sim_config.calls_date,
        "num_ambulances" => base_sim.numAmbs,
        "num_hospitals" => base_sim.numHospitals,
        "num_stations" => base_sim.numStations,
        "num_calls" => base_sim.numCalls,
        "simulation_start_time" => base_sim.startTime
    )
    
    @info "Scenario loaded successfully!" *
          " Config: $(basename(config_data.config_path))" *
          " | Ambulances: $(metadata["num_ambulances"])" *
          " | Hospitals: $(metadata["num_hospitals"])" *
          " | Stations: $(metadata["num_stations"])" *
          " | Calls: $(metadata["num_calls"])"
    
    return ScenarioData(sim_config, base_sim, metadata)
end

"""
    generate_default_config(scenario_name::String, config_name::String = "base"; 
                           scenarios_base_dir::String = "",
                           calls_date::String = "2019-1-1")

Generate a default TOML configuration file from the current directory structure.

# Arguments
- `scenario_name::String`: Name of the scenario
- `config_name::String`: Name for the config file (without .toml extension)
- `scenarios_base_dir::String`: Base directory containing scenarios
- `calls_date::String`: Default calls date to include in config

# Returns
- `String`: Path to the created configuration file
"""
function generate_default_config(scenario_name::String, config_name::String = "base"; 
                                scenarios_base_dir::String = "",
                                calls_date::String = "2019-1-1")
    
    using ..PathUtils: resolve_scenario_path, resolve_calls_file
    
    scenario_path = resolve_scenario_path(scenario_name, scenarios_base_dir)
    configs_dir = joinpath(scenario_path, "configs")
    
    # Create configs directory if it doesn't exist
    if !isdir(configs_dir)
        mkpath(configs_dir)
    end
    
    config_file_path = joinpath(configs_dir, "$config_name.toml")
    
    # Generate calls file path relative to data directory
    calls_relative_path = resolve_calls_file("calls", calls_date)
    # Remove leading "calls/" to make it relative to data directory
    if startswith(calls_relative_path, "calls/")
        calls_relative_path = calls_relative_path
    else
        calls_relative_path = "calls/2019/2019.csv"  # Fallback
    end
    
    # Generate default TOML content
    toml_content = """
# Configuration for $scenario_name scenario
[metadata]
name = "$(scenario_name)_$config_name"
description = "Auto-generated configuration for $scenario_name scenario"
version = "1.0"
generated_at = "$(now())"

[files]
# Infrastructure files
ambulances = "ambulances/base.csv"
hospitals = "hospitals/base.csv" 
stations = "stations/base.csv"

# Road network files
nodes = "roads/nodes.csv"
arcs = "roads/arcs.csv"
r_net_travels = "roads/r_net_travels_jl-v1.10.8.jls"

# Map and routing files
map = "maps/base.csv"
priorities = "misc/call priorities/base.csv"
travel = "travel/base.csv"

# Control files
stats_control = "calls/generated/stats_control.csv"

# Default calls file (can be overridden with calls_date parameter)
calls = "$calls_relative_path"

[options]
validate_files = true
allow_missing_r_net_travels = true

# [paths]
# Uncomment to override default paths
# data_dir = "custom/data/directory"
"""
    
    # Write to file
    open(config_file_path, "w") do f
        write(f, toml_content)
    end
    
    @info "Generated default configuration: $config_file_path"
    
    return config_file_path
end