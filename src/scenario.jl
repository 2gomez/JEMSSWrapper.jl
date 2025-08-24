# src/scenario.jl
"""
Scenario
========

Unified scenario management including configuration loading and scenario creation.
Consolidates functionality from config.jl and loader.jl.
"""
module Scenario

using Dates
using TOML
using JEMSS
using ..PathUtils: PROJECT_DIR, SCENARIOS_DIR
using ..Types: SimulationConfig, ScenarioData
using ..Simulation: initialize_simulation, set_ambulances_data!, initialize_calls

export load_scenario_from_config

"""
    load_scenario_from_config(scenario_name::String, 
                             config_name::String,
                             ambulances_file::String,
                             calls_file::String;
                             num_sets::Int = 1,
                             scenarios_base_dir::String = SCENARIOS_DIR)

Load a scenario using a TOML configuration file.
"""
function load_scenario_from_config(scenario_name::String, 
                                  config_name::String,
                                  ambulances_file::String,
                                  calls_file::String;
                                  num_sets::Int = 1,
                                  scenarios_base_dir::String = SCENARIOS_DIR)
    
    @info "Loading scenario from config: $scenario_name/configs/$config_name"
    
    # Resolve config file path
    config_file = endswith(config_name, ".toml") ? config_name : "$config_name.toml"
    config_path = joinpath(scenarios_base_dir, scenario_name, "configs", config_file)
    
    # Validate config exists
    isfile(config_path) || throw(ArgumentError("Configuration file not found: $config_path"))

    # Create simulation config
    sim_config = create_config_from_toml(config_path)

    # Resolve data file paths
    ambulances_path = joinpath(PROJECT_DIR, sim_config.data_dir, ambulances_file)
    calls_path = joinpath(PROJECT_DIR, sim_config.data_dir, calls_file)
    
    # Validate data files exist
    isfile(ambulances_path) || throw(ArgumentError("Ambulances file not found: $ambulances_path"))
    isfile(calls_path) || throw(ArgumentError("Calls file not found: $calls_path"))
        
    # Load scenario
    return load_scenario_internal(sim_config, ambulances_path, calls_path, num_sets)
end

"""
    load_config_file(config_path::String)

Load and parse a TOML configuration file.
"""
function load_config_file(config_path::String)
    try
        toml_data = TOML.parsefile(config_path)
        
        # Extract sections with defaults
        metadata = get(toml_data, "metadata", Dict{String, Any}())
        files = get(toml_data, "files", Dict{String, String}())
                
        return metadata, files
        
    catch e
        throw(ArgumentError("Failed to parse TOML configuration file '$config_path': $e"))
    end
end

"""
    create_config_from_toml(config_path::String)

Create a SimulationConfig from loaded TOML configuration data.
"""
function create_config_from_toml(config_path::String)
    metadata, files = load_config_file(config_path)
    
    # Resolve metadata
    config_name = get(metadata, "name", basename(config_path))
    scenario_name = get(metadata, "scenario_name", basename(dirname(dirname(config_path))))
    data_dir = get(metadata, "data_dir", "data")

    # Define default file paths
    default_files = Dict(
        "hospitals" => "hospitals/base.csv",
        "stations" => "stations/base.csv",
        "nodes" => "roads/nodes.csv",
        "arcs" => "roads/arcs.csv",
        "r_net_travels" => "",
        "map" => "maps/base.csv",
        "priorities" => "misc/call priorities/base.csv",
        "travel" => "travel/base.csv",
        "stats" => "calls/single/train/stats_control.csv"
    )
    
    # Helper function to get file path
    get_file_path(key) = begin
        filename = get(files, key, default_files[key])
        isempty(filename) ? filename : joinpath(PROJECT_DIR, data_dir, filename)
    end
    
    return SimulationConfig(
        config_name,
        scenario_name,
        data_dir,
        config_path,
        get_file_path("hospitals"),
        get_file_path("stations"),
        get_file_path("nodes"),
        get_file_path("arcs"),
        get_file_path("r_net_travels"),
        get_file_path("map"),
        get_file_path("priorities"),
        get_file_path("travel"),
        get_file_path("stats")
    )
end

"""
    load_scenario_internal(sim_config, ambulances_path, calls_path, num_sets)

Internal function to load scenario from SimulationConfig.
"""
function load_scenario_internal(sim_config::SimulationConfig, 
                               ambulances_path::String, 
                               calls_path::String, 
                               num_sets::Int)

    @info "Initializing simulation..."
    base_sim = initialize_simulation(sim_config)
    set_ambulances_data!(base_sim, ambulances_path)
    call_sets = initialize_calls(base_sim, calls_path, num_sets)
    
    metadata = Dict{String, Any}(
        "loaded_at" => now(),
        "config_name" => sim_config.config_name,
        "scenario_name" => sim_config.scenario_name,
        "config_file" => sim_config.config_path,
        "data_dir" => sim_config.data_dir,
        "ambulance_path" => ambulances_path,
        "calls_path" => calls_path,
        "num_sets" => num_sets
    )
    
    @info "Scenario loaded successfully!"
    
    return ScenarioData(base_sim, call_sets, metadata)
end

end # module Scenario