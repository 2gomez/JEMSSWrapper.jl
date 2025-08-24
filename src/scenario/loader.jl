"""
ScenarioLoader
==============

Main interface for loading scenarios and creating simulations.
"""
module ScenarioLoader

using Dates
using JEMSS
using ..PathUtils: PROJECT_ROOT, SCENARIOS_DIR
using ..ConfigLoader: SimulationConfig, create_config_from_toml
using ..SimulationInitialization: initialize_simulation, set_ambulances_data!

export load_scenario_from_config, Scenario


"""
    struct Scenario

Container for loaded scenario with the base simulation object, the initial situation of 
the scenario and its metadata. The simulation objects does not contains all about the calls.
"""
struct Scenario
    base_sim::JEMSS.Simulation
    metadata::Dict{String, Any}
end
# struct WrappedSimulator
#     simulator::Simulation
#     calls::Vector{Vector{Call}}
# end

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
- `scenarios_base_dir::String`: Base directory containing scenarios

# Returns
- `Scenario`: Loaded scenario data ready for evaluation
```
"""
function load_scenario_from_config(scenario_name::String, 
                                  config_name::String,
                                  ambulances_file::String,
                                  scenarios_base_dir::String = SCENARIOS_DIR)
    
    @info "Loading scenario from config: $scenario_name/configs/$config_name"
    
    # Resolve config file path
    config_path = joinpath(scenarios_base_dir, scenario_name, "configs", config_name)

    # Create simulation config
    sim_config = create_config_from_toml(config_path)

    # Resolve ambulance file path
    ambulances_path = joinpath(PROJECT_ROOT, sim_config.data_dir, ambulances_file)
        
    # Use existing loading infrastructure
    return load_scenario(sim_config, ambulances_path)
end

"""
    load_scenario(sim_config::SimulationConfig)

Internal function to load scenario from SimulationConfig.
"""
function load_scenario(sim_config::SimulationConfig, ambulances_path::String)    
    # Initialize simulation
    @info "Initializing simulation..."
    base_sim = initialize_simulation(sim_config)
    set_ambulances_data!(base_sim, ambulances_path)    
    
    # Create enhanced metadata
    metadata = Dict{String, Any}(
        "loaded_at" => now(),
        "config_name" => sim_config.config_name,
        "scenario_name" => sim_config.scenario_name,
        "config_file" => sim_config.config_path,
        "data_dir" => sim_config.data_dir,
        "num_ambulances" => base_sim.numAmbs,
        "num_hospitals" => base_sim.numHospitals,
        "num_stations" => base_sim.numStations
    )
    
    @info "Scenario loaded successfully!" *
          " Config: $(basename(sim_config.config_name))" *
          " | Ambulances: $(metadata["num_ambulances"])" *
          " | Hospitals: $(metadata["num_hospitals"])" *
          " | Stations: $(metadata["num_stations"])"
    
    return Scenario(base_sim, metadata)
end

end # module ScenarioLoader