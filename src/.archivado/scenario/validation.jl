"""
ScenarioValidation
==================

Validation utilities for scenario configuration and data files.
"""
module ScenarioValidation

using ..ScenarioConfig: SimulationConfig
using ..PathUtils: validate_scenario_structure

export validate_config, validate_files, ValidationError

"""
    struct ValidationError <: Exception

Custom exception for validation errors.
"""
struct ValidationError <: Exception
    message::String
    missing_files::Vector{String}
end

function Base.show(io::IO, e::ValidationError)
    println(io, "ValidationError: $(e.message)")
    if !isempty(e.missing_files)
        println(io, "Missing files:")
        for file in e.missing_files
            println(io, "  - $file")
        end
    end
end

"""
    validate_config(config::SimulationConfig; check_files::Bool = true)

Validate a simulation configuration.

# Arguments
- `config::SimulationConfig`: Configuration to validate
- `check_files::Bool`: Whether to check file existence (default: true)

# Throws
- `ValidationError`: If validation fails
"""
function validate_config(config::SimulationConfig; check_files::Bool = true)
    # Validate scenario structure
    if !validate_scenario_structure(config.scenario_path)
        throw(ValidationError("Invalid scenario structure at $(config.scenario_path)", String[]))
    end
    
    # Validate files if requested
    if check_files
        validate_files(config)
    end
    
    return true
end

"""
    validate_files(config::SimulationConfig)

Check that all required files exist.

# Arguments
- `config::SimulationConfig`: Configuration to validate

# Throws
- `ValidationError`: If any required files are missing
"""
function validate_files(config::SimulationConfig)
    required_files = [
        ("ambulances", config.ambulance_file),
        ("hospitals", config.hospitals_file),
        ("stations", config.stations_file),
        ("nodes", config.nodes_file),
        ("arcs", config.arcs_file),
        ("map", config.map_file),
        ("priorities", config.priorities_file),
        ("travel", config.travel_file),
        ("stats", config.stats_file),
        ("calls", config.calls_file)
    ]
    
    # r_net_travel_file is optional
    if !isempty(config.r_net_travel_file)
        push!(required_files, ("r_net_travel", config.r_net_travel_file))
    end
    
    missing_files = String[]
    for (name, file_path) in required_files
        if !isfile(file_path)
            push!(missing_files, "$name: $file_path")
        end
    end
    
    if !isempty(missing_files)
        throw(ValidationError("Missing required files", missing_files))
    end
    
    return true
end

"""
    check_file_exists(file_path::String, description::String = "")

Check if a single file exists and provide helpful error message.

# Arguments
- `file_path::String`: Path to check
- `description::String`: Description of the file for error messages

# Returns
- `Bool`: true if file exists

# Throws
- `ValidationError`: If file doesn't exist
"""
function check_file_exists(file_path::String, description::String = "")
    if !isfile(file_path)
        desc = isempty(description) ? "File" : description
        throw(ValidationError("$desc not found", [file_path]))
    end
    return true
end

end # module ScenarioValidation