"""
ScenarioLoader
==============

Main interface for loading scenarios and creating simulations.
"""
module ScenarioLoader

using ..ScenarioConfig: SimulationConfig, create_config_from_scenario
using ..ScenarioValidation: validate_config
using ..SimulationInitialization: initialize_simulation

export load_scenario, load_scenario_config, ScenarioData

"""
    struct ScenarioData

Container for loaded scenario data that can be reused for multiple evaluations.
"""
struct ScenarioData
    config::SimulationConfig
    base_simulation::Any  # JEMSS Simulation object
    metadata::Dict{String, Any}
end

"""
    load_scenario(scenario_name::String, calls_date::String = "2019-1-1"; scenarios_base_dir::String = "")

Load a complete scenario and return initialized simulation data.

# Arguments
- `scenario_name::String`: Name of the scenario to load
- `calls_date::String`: Date specification for calls data
- `scenarios_base_dir::String`: Base directory containing scenarios (optional)

# Returns
- `ScenarioData`: Loaded scenario data ready for policy evaluation

# Examples
```julia
# Load a scenario with default calls date
scenario = load_scenario("wellington")

# Load scenario with specific date
scenario = load_scenario("wellington", "2019-01-15")

# Load from custom directory
scenario = load_scenario("my_scenario", "2019-1-1"; scenarios_base_dir="/path/to/scenarios")
```
"""
function load_scenario(scenario_name::String, calls_date::String = "2019-1-1"; 
                      scenarios_base_dir::String = "")
    
    @info "Loading scenario: $scenario_name (calls: $calls_date)"
    
    # Create configuration
    config = create_config_from_scenario(scenario_name, calls_date, scenarios_base_dir)
    
    # Validate configuration
    @info "Validating scenario configuration..."
    validate_config(config)
    
    # Initialize simulation
    @info "Initializing simulation..."
    base_sim = initialize_simulation(config)
    
    # Create metadata
    metadata = Dict{String, Any}(
        "loaded_at" => now(),
        "scenario_name" => scenario_name,
        "calls_date" => calls_date,
        "num_ambulances" => base_sim.numAmbs,
        "num_hospitals" => base_sim.numHospitals,
        "num_stations" => base_sim.numStations,
        "num_calls" => base_sim.numCalls,
        "simulation_start_time" => base_sim.startTime
    )
    
    @info "Scenario loaded successfully!" *
          " Ambulances: $(metadata["num_ambulances"])" *
          " | Hospitals: $(metadata["num_hospitals"])" *
          " | Stations: $(metadata["num_stations"])" *
          " | Calls: $(metadata["num_calls"])"
    
    return ScenarioData(config, base_sim, metadata)
end

"""
    load_scenario_config(scenario_name::String, calls_date::String = "2019-1-1"; scenarios_base_dir::String = "")

Load only the scenario configuration without initializing the simulation.
Useful for validation or inspection.

# Arguments
- `scenario_name::String`: Name of the scenario to load
- `calls_date::String`: Date specification for calls data
- `scenarios_base_dir::String`: Base directory containing scenarios (optional)

# Returns
- `SimulationConfig`: Configuration object with all file paths
"""
function load_scenario_config(scenario_name::String, calls_date::String = "2019-1-1"; 
                             scenarios_base_dir::String = "")
    
    config = create_config_from_scenario(scenario_name, calls_date, scenarios_base_dir)
    validate_config(config; check_files=false)  # Only check structure, not file existence
    
    return config
end

"""
    get_scenario_info(scenario_data::ScenarioData)

Get summary information about a loaded scenario.

# Arguments
- `scenario_data::ScenarioData`: Loaded scenario data

# Returns
- `Dict`: Summary information about the scenario
"""
function get_scenario_info(scenario_data::ScenarioData)
    return Dict(
        "scenario_name" => scenario_data.config.scenario_name,
        "calls_date" => scenario_data.config.calls_date,
        "scenario_path" => scenario_data.config.scenario_path,
        "metadata" => scenario_data.metadata
    )
end

"""
    list_available_scenarios(scenarios_base_dir::String = "")

List all available scenarios in the scenarios directory.

# Arguments
- `scenarios_base_dir::String`: Base directory containing scenarios (optional)

# Returns
- `Vector{String}`: List of available scenario names
"""
function list_available_scenarios(scenarios_base_dir::String = "")
    using ..PathUtils: get_wrapper_root, validate_scenario_structure
    
    if isempty(scenarios_base_dir)
        scenarios_base_dir = joinpath(get_wrapper_root(), "scenarios")
    end
    
    if !isdir(scenarios_base_dir)
        @warn "Scenarios directory not found: $scenarios_base_dir"
        return String[]
    end
    
    scenarios = String[]
    for item in readdir(scenarios_base_dir)
        item_path = joinpath(scenarios_base_dir, item)
        if isdir(item_path) && validate_scenario_structure(item_path)
            push!(scenarios, item)
        end
    end
    
    return sort(scenarios)
end

"""
    Base.show(io::IO, scenario_data::ScenarioData)

Pretty print scenario data information.
"""
function Base.show(io::IO, scenario_data::ScenarioData)
    println(io, "ScenarioData:")
    println(io, "  Scenario: $(scenario_data.config.scenario_name)")
    println(io, "  Calls Date: $(scenario_data.config.calls_date)")
    println(io, "  Ambulances: $(scenario_data.metadata["num_ambulances"])")
    println(io, "  Hospitals: $(scenario_data.metadata["num_hospitals"])")
    println(io, "  Stations: $(scenario_data.metadata["num_stations"])")
    println(io, "  Calls: $(scenario_data.metadata["num_calls"])")
    println(io, "  Loaded: $(scenario_data.metadata["loaded_at"])")
end

end # module ScenarioLoader