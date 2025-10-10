"""
    load_scenario_from_config(scenario_name::String, 
                              config_name::String;
                              ambulances_path::String = "",
                              calls_path::String = "",
                              scenarios_dir::String = SCENARIOS_DIR) -> ScenarioData

Load a simulation scenario from TOML configuration files.

Creates a complete scenario with infrastructure (stations, hospitals, road network),
ambulances, and calls. The scenario can be modified later with `update_scenario_calls` 
or `update_scenario_ambulances`.

# Arguments
- `scenario_name::String`: Name of the scenario (e.g., "auckland")
- `config_name::String`: Name of the configuration file (e.g., "base.toml")
- `ambulances_path::String`: Optional custom path to ambulances CSV
- `calls_path::String`: Optional custom path to calls CSV
- `scenarios_dir::String`: Base directory for scenarios (defaults to `SCENARIOS_DIR`)

# Returns
- `ScenarioData`: Immutable scenario configuration containing simulation, calls, and metadata

# Examples
```julia
# Load default scenario
scenario = load_scenario_from_config("auckland", "base.toml")

# Load with custom calls
scenario = load_scenario_from_config("auckland", "base.toml"; 
                                     calls_path="custom_calls.csv")
```
"""
function load_scenario_from_config(scenario_name::String, 
                                  config_name::String;
                                  ambulances_path::String = "",
                                  calls_path::String = "",
                                  scenarios_dir::String = SCENARIOS_DIR)
    
    @info "Loading scenario from config: $scenarios_dir/$scenario_name/configs/$config_name"
    
    config_file = endswith(config_name, ".toml") ? config_name : "$config_name.toml"
    scenario_path = joinpath(scenarios_dir, scenario_name)
    config_path = joinpath(scenario_path, "configs", config_file)
    
    isfile(config_path) || throw(ArgumentError("Configuration file not found: $config_path"))

    sim_config = create_config_from_toml(config_path, scenario_path)

    ambulances_path = isempty(ambulances_path) ? sim_config.default_ambulances_file : ambulances_path
    
    calls_path = isempty(calls_path) ? sim_config.default_calls_file : calls_path
    
    isfile(ambulances_path) || throw(ArgumentError("Ambulances file not found: $ambulances_path"))
    isfile(calls_path) || throw(ArgumentError("Calls file not found: $calls_path"))
        
    return load_scenario_internal(sim_config, ambulances_path, calls_path)
end

"""
    load_config_file(config_path::String)

Load and parse a TOML configuration file.
"""
function load_config_file(config_path::String)
    try
        toml_data = TOML.parsefile(config_path)
        
        metadata = get(toml_data, "metadata", Dict{String, String}())
        files = get(toml_data, "files", Dict{String, String}())
        defaults = get(toml_data, "defaults", Dict{String, String}())
                
        return metadata, files, defaults
        
    catch e
        throw(ArgumentError("Failed to parse TOML configuration file '$config_path': $e"))
    end
end

"""
    create_config_from_toml(config_path::String)

Create a ScenarioConfig from loaded TOML configuration data.
"""
function create_config_from_toml(config_path::String, scenario_path::String)
    metadata, files, defaults = load_config_file(config_path)
    
    # Resolve metadata
    config_name = get(metadata, "name", basename(config_path))
    scenario_name = get(metadata, "scenario_name", basename(dirname(dirname(config_path))))
    models_path = joinpath(scenario_path, get(metadata, "models_dir", "models"))
    
    get_filepath(dict_files, key) = begin
        filename = get(dict_files, key, "") 
        isempty(filename) ? filename : joinpath(models_path, filename)
    end
    
    return ScenarioConfig(
        config_name,
        scenario_name,
        config_path,
        models_path,
        get_filepath(files, "hospitals"),
        get_filepath(files, "stations"),
        get_filepath(files, "nodes"),
        get_filepath(files, "arcs"),
        get_filepath(files, "r_net_travels"),
        get_filepath(files, "map"),
        get_filepath(files, "priorities"),
        get_filepath(files, "travel"),
        get_filepath(files, "stats"),
        get_filepath(files, "demand"),
        get_filepath(files, "demand_coverage"),
        get_filepath(defaults, "ambulances"),
        get_filepath(defaults, "calls")
    )
end

"""
    load_scenario_internal(sim_config, ambulances_path, calls_path)

Internal function to load scenario from ScenarioConfig.
"""
function load_scenario_internal(sim_config::ScenarioConfig, 
                               ambulances_path::String, 
                               calls_path::String)
    @info "Initializing simulation..."
    base_sim = initialize_simulation(sim_config)
    calls = initialize_calls(base_sim, calls_path)
    ambulances = initialize_ambulances(ambulances_path)
    
    metadata = scenario_config_to_dict(sim_config)
    metadata["ambulances_path"] = ambulances_path
    metadata["calls_path"] = calls_path 

    @info "Scenario loaded successfully!"
    
    return ScenarioData(base_sim, calls, ambulances, metadata)
end


"""
    update_scenario_calls(scenario::ScenarioData, calls_path::String) -> ScenarioData

Update calls in an existing scenario without reloading infrastructure.

Creates a new `ScenarioData` with modified calls while preserving stations, hospitals,
and road network. Useful for testing different demand patterns on the same infrastructure.

# Arguments
- `scenario::ScenarioData`: Original scenario
- `calls_path::String`: Path to new calls CSV file

# Returns
- `ScenarioData`: New scenario with updated calls

# Examples
```julia
base_scenario = load_scenario_from_config("auckland", "base.toml")
peak_scenario = update_scenario_calls(base_scenario, "peak_hours_calls.csv")
```
"""
function update_scenario_calls(scenario::ScenarioData, calls_path::String)
    calls = initialize_calls(scenario.base_simulation, calls_path)
    
    return ScenarioData(
        scenario.base_simulation,  
        calls,             
        scenario.ambulances,
        merge(scenario.metadata, Dict("calls_path" => calls_path))
    )
end

"""
    update_scenario_ambulances(scenario::ScenarioData, ambulances_path::String) -> ScenarioData

Update ambulances in an existing scenario without reloading infrastructure.

Creates a new `ScenarioData` with modified ambulance fleet while preserving infrastructure
and calls. Useful for testing different fleet configurations.

# Arguments
- `scenario::ScenarioData`: Original scenario
- `ambulances_path::String`: Path to new ambulances CSV file

# Returns
- `ScenarioData`: New scenario with updated ambulances

# Examples
```julia
base_scenario = load_scenario_from_config("auckland", "base.toml")
expanded_fleet = update_scenario_ambulances(base_scenario, "20_ambulances.csv")
```
"""
function update_scenario_ambulances(scenario::ScenarioData, ambulances_path::String)
    ambulances = initialize_ambulances(ambulances_path)
    
    return ScenarioData(
        scenario.base_simulation,
        scenario.calls,
        ambulances, 
        merge(scenario.metadata, Dict("ambulances_path" => ambulances_path))
    )
end