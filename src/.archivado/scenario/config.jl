"""
ScenarioConfig
==============

Configuration management for simulation scenarios.
Handles file paths and scenario parameters.
"""
module ScenarioConfig

using ..PathUtils

export SimulationConfig, create_config_from_scenario

"""
    struct SimulationConfig

Configuration structure containing all file paths needed for a simulation.
"""
struct SimulationConfig
    # Basic scenario info
    scenario_name::String
    calls_date::String
    scenario_path::String
    
    # Data files
    ambulance_file::String
    hospitals_file::String
    stations_file::String
    nodes_file::String
    arcs_file::String
    r_net_travel_file::String
    map_file::String
    priorities_file::String
    travel_file::String
    stats_file::String
    calls_file::String
end

"""
    create_config_from_scenario(scenario_name::String, calls_date::String = "2019-1-1", scenarios_base_dir::String = "")

Create a SimulationConfig from scenario name and calls date.

# Arguments
- `scenario_name::String`: Name of the scenario
- `calls_date::String`: Date specification for calls data
- `scenarios_base_dir::String`: Base directory containing scenarios (optional)

# Returns
- `SimulationConfig`: Configuration object with all file paths
"""
function create_config_from_scenario(scenario_name::String, 
                                   calls_date::String = "2019-1-1",
                                   scenarios_base_dir::String = "")
    # Resolve scenario path
    scenario_path = resolve_scenario_path(scenario_name, scenarios_base_dir)
    
    # Build directory structure
    data_dir = joinpath(scenario_path, "data")
    base_dir = joinpath(data_dir, "base")
    roads_dir = joinpath(data_dir, "roads")
    calls_dir = joinpath(data_dir, "calls")
    
    # Resolve calls file
    calls_file = resolve_calls_file(calls_dir, calls_date)
    
    return SimulationConfig(
        scenario_name,
        calls_date,
        scenario_path,
        joinpath(base_dir, "ambulances", "base.csv"),
        joinpath(base_dir, "hospitals", "base.csv"),
        joinpath(base_dir, "stations", "base.csv"),
        joinpath(roads_dir, "nodes.csv"),
        joinpath(roads_dir, "arcs.csv"),
        joinpath(roads_dir, "r_net_travels_jl-v1.10.8.jls"),
        joinpath(base_dir, "maps", "base.csv"),
        joinpath(base_dir, "misc", "call priorities", "base.csv"),
        joinpath(base_dir, "travel", "base.csv"),
        joinpath(base_dir, "calls", "generated", "stats_control.csv"),
        calls_file
    )
end

"""
    Base.show(io::IO, config::SimulationConfig)

Pretty print a SimulationConfig.
"""
function Base.show(io::IO, config::SimulationConfig)
    println(io, "SimulationConfig:")
    println(io, "  Scenario: $(config.scenario_name)")
    println(io, "  Calls Date: $(config.calls_date)")
    println(io, "  Path: $(config.scenario_path)")
end

end # module ScenarioConfig