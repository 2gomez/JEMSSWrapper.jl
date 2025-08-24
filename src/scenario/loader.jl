"""
ScenarioLoader
==============

Main interface for loading scenarios and creating simulations.
"""
module ScenarioLoader

using Dates
using JEMSS
using ..PathUtils: PROJECT_DIR, SCENARIOS_DIR
using ..ConfigLoader: SimulationConfig, create_config_from_toml
using ..SimulationInitialization: initialize_simulation, set_ambulances_data!, initialize_calls

export load_scenario_from_config, Scenario


"""
    struct Scenario

Container for loaded scenario with the base simulation object, the initial situation of 
the scenario and its metadata. The simulation objects does not contains all about the calls.
"""
struct Scenario
    base_sim::JEMSS.Simulation
    calls_sets::Vector{Vector{JEMSS.Call}}
    metadata::Dict{String, Any}
end

"""
    load_scenario_from_config(scenario_name::String, 
                             config_name::String,
                             ambulances_file::String,
                             scenarios_base_dir::String = SCENARIOS_DIR)

Load a scenario using a TOML configuration file.

# Arguments
- `scenario_name::String`: Name of the scenario
- `config_name::String`: Name of the config file (with or without .toml extension)
- `ambulances_file::String`: Filename of the ambulances data
- `call_file::String`: Filename of the calls data (calls or call generator configuration)
- `num_sets:Int`: Number of sets to split the calls
- `scenarios_base_dir::String`: Base directory containing scenarios

# Returns
- `Scenario`: Loaded scenario data ready for evaluation
```
"""
function load_scenario_from_config(scenario_name::String, 
                                  config_name::String,
                                  ambulances_file::String,
                                  calls_file::String,
                                  num_sets::Int = 1,
                                  scenarios_base_dir::String = SCENARIOS_DIR)
    
    @info "Loading scenario from config: $scenario_name/configs/$config_name"
    
    # Resolve config file path
    config_path = joinpath(scenarios_base_dir, scenario_name, "configs", config_name)

    # Create simulation config
    sim_config = create_config_from_toml(config_path)

    # Resolve ambulance file and calls file path
    ambulances_path = joinpath(PROJECT_DIR, sim_config.data_dir, ambulances_file)
    calls_path = joinpath(PROJECT_DIR, sim_config.data_dir, calls_file)
        
    # Use existing loading infrastructure
    return load_scenario(sim_config, ambulances_path, calls_path, num_sets)
end

"""
    load_scenario(sim_config::SimulationConfig)

Internal function to load scenario from SimulationConfig.
"""
function load_scenario(sim_config::SimulationConfig, ambulances_path::String, 
                      calls_path::String, num_sets::Int)

    @info "Initializing simulation..."
    base_sim = initialize_simulation(sim_config)
    set_ambulances_data!(base_sim, ambulances_path)
    calls_sets = initialize_calls(base_sim, calls_path, num_sets)
    
    metadata = Dict{String, Any}(
        "loaded_at" => now(),
        "config_name" => sim_config.config_name,
        "scenario_name" => sim_config.scenario_name,
        "config_file" => sim_config.config_path,
        "data_dir" => sim_config.data_dir,
        "ambulance_path" => ambulances_path,
        "calls_path" => calls_path
    )
    
    @info "Scenario loaded successfully!"
    
    return Scenario(base_sim, calls_sets, metadata)
end

end # module ScenarioLoader