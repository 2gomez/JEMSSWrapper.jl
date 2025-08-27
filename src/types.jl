"""
Types
=====

Core type definitions shared across modules to avoid circular dependencies.
"""
module Types

using Dates
using JEMSS

export ScenarioConfig, ScenarioData

"""
    struct ScenarioConfig

Configuration structure containing all file paths needed for a simulation scenario.
"""
struct ScenarioConfig
    config_name::String
    scenario_name::String
    data_dir::String
    config_path::String

    # Configuration files
    hospitals_file::String
    stations_file::String
    nodes_file::String
    arcs_file::String
    r_net_travel_file::String
    map_file::String
    priorities_file::String
    travel_file::String
    stats_file::String
    demand_file::String
    demand_coverage_file::String
end

"""
    struct ScenarioData

Container for loaded scenario with the base simulation object, call sets and metadata.
"""
struct ScenarioData
    base_simulation::JEMSS.Simulation
    calls::Vector{JEMSS.Call}
    ambulances::Vector{JEMSS.Ambulance}
    metadata::Dict{String, Any}
end

end # module Types