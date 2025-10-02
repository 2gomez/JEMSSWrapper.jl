"""
    struct ScenarioConfig

Configuration structure containing all file paths needed for a simulation scenario.
"""
struct ScenarioConfig
    config_name::String
    scenario_name::String
    config_path::String
    models_path::String

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

    # Defaults
    default_ambulances_file::String
    default_calls_file::String
    
    # Constructor with validation
    function ScenarioConfig(config_name, scenario_name, config_path, models_path,
                           hospitals_file, stations_file, nodes_file, arcs_file,
                           r_net_travel_file, map_file, priorities_file, travel_file,
                           stats_file, demand_file, demand_coverage_file,
                           default_ambulances_file, default_calls_file)
        
        required_files = [
            ("hospitals", hospitals_file),
            ("stations", stations_file),
            ("nodes", nodes_file),
            ("arcs", arcs_file),
            ("map", map_file),
            ("priorities", priorities_file),
            ("travel", travel_file),
            ("stats", stats_file),
            ("default_ambulances", default_ambulances_file),
            ("default_calls", default_calls_file)
        ]
        
        # Validate files
        for (name, filepath) in required_files
            if !isempty(filepath) && !isfile(filepath)
                throw(ArgumentError("Required file not found ($name): $filepath"))
            elseif isempty(filepath)
                throw(ArgumentError("Required file path is empty: $name"))
            end
        end
        
        new(config_name, scenario_name, config_path, models_path,
            hospitals_file, stations_file, nodes_file, arcs_file,
            r_net_travel_file, map_file, priorities_file, travel_file,
            stats_file, demand_file, demand_coverage_file,
            default_ambulances_file, default_calls_file)
    end
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