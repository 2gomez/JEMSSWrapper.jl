# src/scenario/config_loader.jl
"""
ConfigLoader
============

TOML-based configuration loading for flexible scenario setup.
"""
module ConfigLoader

using TOML
using ..PathUtils: PROJECT_ROOT

export create_config_from_toml

"""
    struct ConfigData

Container for loaded configuration data from TOML file.
"""
struct ConfigData
    metadata::Dict{String, Any}
    files::Dict{String, String}
end

"""
    struct SimulationConfig

Configuration structure containing all file paths needed for a simulation.
"""
struct SimulationConfig
    # Basic scenario info
    config_name::String
    scenario_name::String
    data_dir::String
    config_path::String

    # Infrastructure files
    ambulance_file::String
    hospitals_file::String
    stations_file::String

    # Road network files
    nodes_file::String
    arcs_file::String
    r_net_travel_file::String

    # Map and routing files
    map_file::String
    priorities_file::String
    travel_file::String

    # Control files
    stats_file::String
    
    # Calls
    call_gen_config_file::String
    calls_file::String

    # Demand
    demand_file::String
    demand_coverage_file::String
end

"""
    load_config_file(config_path::String)

Load and parse a TOML configuration file.

# Arguments
- `config_path::String`: Path to the TOML configuration file

# Returns
- `ConfigData`: Parsed configuration data

# Example
```julia
config = load_config_file("scenarios/auckland/configs/base.toml")
```
"""
function load_config_file(config_path::String)
    if !isfile(config_path)
        throw(ArgumentError("Configuration file not found: $config_path"))
    end
    
    try
        toml_data = TOML.parsefile(config_path)
        
        # Extract sections with defaults
        metadata = get(toml_data, "metadata", Dict{String, Any}())
        files = get(toml_data, "files", Dict{String, String}())
                
        return ConfigData(metadata, files)
        
    catch e
        throw(ArgumentError("Failed to parse TOML configuration file '$config_path': $e"))
    end
end

"""
    create_config_from_toml(config_data::ConfigData; 
                           overrides::Dict{String, String} = Dict{String, String}())

Create a SimulationConfig from loaded TOML configuration data.

# Arguments
- `config_path::String`: Path to the TOML configuration file
- `overrides::Dict{String, String}`: File path overrides

# Returns
- `SimulationConfig`: Configuration object ready for simulation
"""
function create_config_from_toml(config_path::String;
                                overrides::Dict{String, String} = Dict{String, String}())
    config_data = load_config_file(config_path)
    files = copy(config_data.files)
    
    # Apply overrides
    for (key, value) in overrides
        files[key] = value
    end
    
    # Resolve metadata
    config_name = get(config_data.metadata, "name", basename(config_path))
    scenario_name = get(config_data.metadata, "scenario_name", dirname(dirname(config_path)))
    data_dir = get(config_data.metadata, "data_dir", joinpath(config_path, "..", "data"))

    # Define default file paths
    default_files = Dict(
        "ambulances" => "ambulances/base.csv",
        "hospitals" => "hospitals/base.csv",
        "stations" => "stations/base.csv",
        "nodes" => "roads/nodes.csv",
        "arcs" => "roads/arcs.csv",
        "r_net_travels" => "",
        "map" => "maps/base.csv",
        "priorities" => "misc/call priorities/base.csv",
        "travel" => "travel/base.csv",
        "stats_control" => "calls/generated/stats_control.csv",
        "call_gen_config" => "",
        "calls" => "",
        "demand" => "",
        "demand_coverage" => ""
    )
    
    # Helper function to get file path and join with data_dir
    get_file_path(key) = begin
        filename = get(files, key, default_files[key])
        isempty(filename) ? filename : joinpath(PROJECT_ROOT, data_dir, filename)
    end
    
    return SimulationConfig(
        config_name,
        scenario_name,
        data_dir,
        config_path,
        get_file_path("ambulances"),
        get_file_path("hospitals"),
        get_file_path("stations"),
        get_file_path("nodes"),
        get_file_path("arcs"),
        get_file_path("r_net_travels"),
        get_file_path("map"),
        get_file_path("priorities"),
        get_file_path("travel"),
        get_file_path("stats_control"),
        get_file_path("call_gen_config"),
        get_file_path("calls"),
        get_file_path("demand"),
        get_file_path("demand_coverage")
    )
end

end # module ConfigLoader