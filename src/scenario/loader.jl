"""
ScenarioLoader
==============

Main interface for loading scenarios and creating simulations.
"""
module ScenarioLoader

using Dates
using ..PathUtils: SCENARIOS_DIR
using ..ConfigLoader: SimulationConfig, create_config_from_toml
using ..SimulationInitialization: initialize_simulation

export load_scenario_from_config, ScenarioData

JEMSS = Main.JEMSSWrapper.jemss

"""
    struct ScenarioData

Container for loaded scenario data that can be reused for multiple evaluations.
"""
struct ScenarioData
    config::SimulationConfig
    base_simulation::JEMSS.Simulation
    metadata::Dict{String, Any}
end

"""
    load_scenario_from_config(scenario_name::String, config_name::String; 
                             scenarios_base_dir::String = "",
                             overrides::Dict{String, String} = Dict{String, String}())

Load a scenario using a TOML configuration file.

# Arguments
- `scenario_name::String`: Name of the scenario
- `config_name::String`: Name of the config file (with or without .toml extension)
- `scenarios_base_dir::String`: Base directory containing scenarios
- `overrides::Dict{String, String}`: Optional file path overrides

# Returns
- `ScenarioData`: Loaded scenario data ready for evaluation

# Examples
```julia
# Basic usage
scenario = load_scenario_from_config("wellington", "base")

# With file overrides
scenario = load_scenario_from_config("wellington", "base"; 
    overrides=Dict("ambulances" => "ambulances/variant2.csv"))

```
"""
function load_scenario_from_config(scenario_name::String, config_name::String; 
                                  scenarios_base_dir::String = SCENARIOS_DIR,
                                  overrides::Dict{String, String} = Dict{String, String}())
    
    @info "Loading scenario from config: $scenario_name/configs/$config_name.toml"
    
    # Resolve config file path
    config_path = joinpath(scenarios_base_dir, scenario_name, "configs", "$config_name.toml")
    
    # Create simulation config
    sim_config = create_config_from_toml(config_path, overrides=overrides)
        
    # Use existing loading infrastructure
    return load_scenario_from_sim_config(sim_config)
end

"""
    load_scenario_from_sim_config(sim_config::SimulationConfig)

Internal function to load scenario from SimulationConfig.
"""
function load_scenario_from_sim_config(sim_config::SimulationConfig)    
    # Initialize simulation
    @info "Initializing simulation..."
    base_sim = initialize_simulation(sim_config)
    
    # Create enhanced metadata
    metadata = Dict{String, Any}(
        "loaded_at" => now(),
        "config_name" => sim_config.config_name,
        "scenario_name" => sim_config.scenario_name,
        "config_file" => sim_config.config_path,
        "data_dir" => sim_config.data_dir,
        "num_ambulances" => base_sim.numAmbs,
        "num_hospitals" => base_sim.numHospitals,
        "num_stations" => base_sim.numStations,
        "num_calls" => base_sim.numCalls,
        "simulation_start_time" => base_sim.startTime
    )
    
    @info "Scenario loaded successfully!" *
          " Config: $(basename(sim_config.config_name))" *
          " | Ambulances: $(metadata["num_ambulances"])" *
          " | Hospitals: $(metadata["num_hospitals"])" *
          " | Stations: $(metadata["num_stations"])" *
          " | Calls: $(metadata["num_calls"])"
    
    return ScenarioData(sim_config, base_sim, metadata)
end

end # module ScenarioLoader