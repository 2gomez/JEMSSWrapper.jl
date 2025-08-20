# src/scenario/config_loader.jl
"""
ConfigLoader
============

TOML-based configuration loading for flexible scenario setup.
"""
module ConfigLoader

using TOML
using ..PathUtils
using ..ScenarioConfig: SimulationConfig

export load_config_file, create_config_from_toml, ConfigData

"""
    struct ConfigData

Container for loaded configuration data from TOML file.
"""
struct ConfigData
    metadata::Dict{String, Any}
    files::Dict{String, String}
    options::Dict{String, Any}
    paths::Dict{String, String}
    config_path::String
    scenario_path::String
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
        options = get(toml_data, "options", Dict{String, Any}())
        paths = get(toml_data, "paths", Dict{String, String}())
        
        # Determine scenario path
        config_dir = dirname(config_path)
        scenario_path = get(paths, "base_path", dirname(config_dir))
        
        return ConfigData(metadata, files, options, paths, config_path, scenario_path)
        
    catch e
        throw(ArgumentError("Failed to parse TOML configuration file '$config_path': $e"))
    end
end

"""
    resolve_config_path(scenario_name::String, config_name::String, scenarios_base_dir::String = "")

Resolve the path to a configuration file.

# Arguments
- `scenario_name::String`: Name of the scenario
- `config_name::String`: Name of the config file (with or without .toml extension)
- `scenarios_base_dir::String`: Base directory containing scenarios

# Returns
- `String`: Full path to the configuration file
"""
function resolve_config_path(scenario_name::String, config_name::String, scenarios_base_dir::String = "")
    # Add .toml extension if not present
    if !endswith(config_name, ".toml")
        config_name = config_name * ".toml"
    end
    
    scenario_path = resolve_scenario_path(scenario_name, scenarios_base_dir)
    config_path = joinpath(scenario_path, "configs", config_name)
    
    return config_path
end

"""
    create_config_from_toml(config_data::ConfigData; 
                           calls_date::String = "",
                           calls_file::String = "",
                           overrides::Dict{String, String} = Dict{String, String}())

Create a SimulationConfig from loaded TOML configuration data.

# Arguments
- `config_data::ConfigData`: Loaded configuration data
- `calls_date::String`: Optional calls date specification (overrides config)
- `calls_file::String`: Optional direct calls file path (overrides config and date)
- `overrides::Dict{String, String}`: File path overrides

# Returns
- `SimulationConfig`: Configuration object ready for simulation
"""
function create_config_from_toml(config_data::ConfigData; 
                                calls_date::String = "",
                                calls_file::String = "",
                                overrides::Dict{String, String} = Dict{String, String}())
    
    files = copy(config_data.files)
    scenario_path = config_data.scenario_path
    
    # Apply overrides
    for (key, value) in overrides
        files[key] = value
    end
    
    # Resolve data directory
    data_dir = get(config_data.paths, "data_dir", joinpath(scenario_path, "data"))
    
    # Build file paths with proper resolution
    function resolve_file_path(filename::String)
        if isabs(filename)
            return filename
        else
            return joinpath(data_dir, filename)
        end
    end
    
    # Resolve calls file with priority: calls_file > calls_date > config default
    resolved_calls_file = ""
    if !isempty(calls_file)
        # Direct file specification has highest priority
        resolved_calls_file = resolve_file_path(calls_file)
    elseif !isempty(calls_date)
        # Date specification resolves to calls directory structure
        calls_base_dir = joinpath(data_dir, "calls")
        resolved_calls_file = resolve_calls_file(calls_base_dir, calls_date)
    elseif haskey(files, "calls")
        # Use config file default
        resolved_calls_file = resolve_file_path(files["calls"])
    else
        throw(ArgumentError("No calls file specified in config, calls_date, or calls_file parameters"))
    end
    
    # Determine scenario name and calls date for metadata
    scenario_name = get(config_data.metadata, "name", basename(scenario_path))
    effective_calls_date = !isempty(calls_date) ? calls_date : get_calls_date_from_path(resolved_calls_file)
    
    return SimulationConfig(
        scenario_name,
        effective_calls_date,
        scenario_path,
        resolve_file_path(get(files, "ambulances", "ambulances/base.csv")),
        resolve_file_path(get(files, "hospitals", "hospitals/base.csv")),
        resolve_file_path(get(files, "stations", "stations/base.csv")),
        resolve_file_path(get(files, "nodes", "roads/nodes.csv")),
        resolve_file_path(get(files, "arcs", "roads/arcs.csv")),
        resolve_file_path(get(files, "r_net_travels", "")),  # Optional file
        resolve_file_path(get(files, "map", "maps/base.csv")),
        resolve_file_path(get(files, "priorities", "misc/call priorities/base.csv")),
        resolve_file_path(get(files, "travel", "travel/base.csv")),
        resolve_file_path(get(files, "stats_control", "calls/generated/stats_control.csv")),
        resolved_calls_file
    )
end

"""
    get_calls_date_from_path(calls_file_path::String)

Extract date specification from calls file path for metadata.
"""
function get_calls_date_from_path(calls_file_path::String)
    filename = basename(calls_file_path)
    name_without_ext = splitext(filename)[1]
    
    # Try to extract date pattern (yyyy, yyyy-mm, yyyy-mm-dd)
    if occursin(r"^\d{4}(-\d{2}(-\d{2})?)?$", name_without_ext)
        return name_without_ext
    else
        return "custom"
    end
end

"""
    list_config_files(scenario_name::String, scenarios_base_dir::String = "")

List available configuration files for a scenario.

# Arguments
- `scenario_name::String`: Name of the scenario
- `scenarios_base_dir::String`: Base directory containing scenarios

# Returns
- `Vector{String}`: List of available config file names (without .toml extension)
"""
function list_config_files(scenario_name::String, scenarios_base_dir::String = "")
    scenario_path = resolve_scenario_path(scenario_name, scenarios_base_dir)
    configs_dir = joinpath(scenario_path, "configs")
    
    if !isdir(configs_dir)
        return String[]
    end
    
    config_files = String[]
    for file in readdir(configs_dir)
        if endswith(file, ".toml") && isfile(joinpath(configs_dir, file))
            push!(config_files, splitext(file)[1])  # Remove .toml extension
        end
    end
    
    return sort(config_files)
end

"""
    validate_config_structure(config_data::ConfigData)

Validate the structure of loaded configuration data.

# Arguments
- `config_data::ConfigData`: Configuration data to validate

# Returns
- `Bool`: true if structure is valid

# Throws
- `ArgumentError`: If required sections or fields are missing
"""
function validate_config_structure(config_data::ConfigData)
    # Check required file entries
    required_files = ["ambulances", "hospitals", "stations", "nodes", "arcs", "map", "priorities", "travel"]
    
    missing_files = String[]
    for file_key in required_files
        if !haskey(config_data.files, file_key)
            push!(missing_files, file_key)
        end
    end
    
    if !isempty(missing_files)
        throw(ArgumentError("Missing required file configurations: $(join(missing_files, ", "))"))
    end
    
    # Check that either calls file or ability to resolve calls is present
    has_calls = haskey(config_data.files, "calls")
    has_stats = haskey(config_data.files, "stats_control")
    
    if !has_calls
        @warn "No default calls file specified in config - calls_date or calls_file parameter will be required"
    end
    
    if !has_stats
        @warn "No stats_control file specified in config - using default path"
    end
    
    return true
end

end # module ConfigLoader