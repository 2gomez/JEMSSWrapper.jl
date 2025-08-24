# src/scenario/config_loader.jl
"""
ConfigLoader
============

TOML-based configuration loading for flexible scenario setup.
"""
module ConfigLoader

using TOML
using ..PathUtils: PROJECT_DIR

export create_config_from_toml

"""
    struct SimulationConfig

Configuration structure containing all file paths needed for a simulation.
"""
struct SimulationConfig
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
end

"""
    load_config_file(config_path::String)

Load and parse a TOML configuration file.

# Arguments
- `config_path::String`: Path to the TOML configuration file

# Returns
- `ConfigData`: Parsed configuration data
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
                
        return metadata, files
        
    catch e
        throw(ArgumentError("Failed to parse TOML configuration file '$config_path': $e"))
    end
end

"""
    create_config_from_toml(config_data::String)

Create a SimulationConfig from loaded TOML configuration data.

# Arguments
- `config_path::String`: Path to the TOML configuration file

# Returns
- `SimulationConfig`: Configuration object ready for simulation
"""
function create_config_from_toml(config_path::String)
    metadata, files = load_config_file(config_path)
    files = copy(files)
    
    # Resolve metadata
    config_name = get(metadata, "name", basename(config_path))
    scenario_name = get(metadata, "scenario_name", dirname(dirname(config_path)))
    data_dir = get(metadata, "data_dir", joinpath(config_path, "..", "data"))

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
    
    # Helper function to get file path and join with data_dir
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

end # module ConfigLoader