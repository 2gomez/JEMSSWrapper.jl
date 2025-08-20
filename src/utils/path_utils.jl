"""
PathUtils
=========

Utilities for path resolution and scenario directory management.
"""
module PathUtils

export resolve_scenario_path, resolve_calls_file, get_wrapper_root, validate_scenario_structure

"""
    get_wrapper_root()

Get the root directory of the JEMSSWrapper package.
"""
function get_wrapper_root()
    return dirname(dirname(@__DIR__))
end

"""
    resolve_scenario_path(scenario_name::String, base_dir::String = "")

Resolve the full path to a scenario directory.

# Arguments
- `scenario_name::String`: Name of the scenario
- `base_dir::String`: Base directory containing scenarios (optional)

# Returns
- `String`: Full path to the scenario directory
"""
function resolve_scenario_path(scenario_name::String, base_dir::String = "")
    if isempty(base_dir)
        base_dir = joinpath(get_wrapper_root(), "scenarios")
    end
    return joinpath(base_dir, scenario_name)
end

"""
    resolve_calls_file(calls_base_dir::String, date_spec::String)

Resolve the file path for calls data based on date specification.

# Arguments
- `calls_base_dir::String`: Base directory containing calls data
- `date_spec::String`: Date specification (yyyy, yyyy-mm, or yyyy-mm-dd)

# Returns
- `String`: Path to the calls CSV file

# Examples
```julia
resolve_calls_file("/path/to/calls", "2019")        # -> /path/to/calls/2019/2019.csv
resolve_calls_file("/path/to/calls", "2019-01")     # -> /path/to/calls/2019/01/2019-01.csv
resolve_calls_file("/path/to/calls", "2019-01-15")  # -> /path/to/calls/2019/01/15/2019-01-15.csv
```
"""
function resolve_calls_file(calls_base_dir::String, date_spec::String)
    date_parts = split(date_spec, "-")
    
    if length(date_parts) == 1
        # Format: year.csv
        year = date_parts[1]
        calls_file = joinpath(calls_base_dir, year, "$year.csv")
    elseif length(date_parts) == 2
        # Format: year-month.csv
        year, month = date_parts
        calls_file = joinpath(calls_base_dir, year, month, "$year-$month.csv")
    elseif length(date_parts) == 3
        # Format: year-month-day.csv
        year, month, day = date_parts
        calls_file = joinpath(calls_base_dir, year, month, day, "$year-$month-$day.csv")
    else
        throw(ArgumentError("Invalid date specification: $date_spec. Use year, year-month, or year-month-day format"))
    end
    
    return calls_file
end

"""
    validate_scenario_structure(scenario_path::String)

Check if a scenario directory has the expected structure.

# Arguments
- `scenario_path::String`: Path to the scenario directory

# Returns
- `Bool`: true if structure is valid
"""
function validate_scenario_structure(scenario_path::String)
    if !isdir(scenario_path)
        return false
    end
    
    # Check for expected subdirectories
    expected_dirs = ["data"]
    for dir in expected_dirs
        if !isdir(joinpath(scenario_path, dir))
            return false
        end
    end
    
    # Check for data subdirectories
    data_path = joinpath(scenario_path, "data")
    expected_data_dirs = ["base", "roads", "calls"]
    for dir in expected_data_dirs
        if !isdir(joinpath(data_path, dir))
            return false
        end
    end
    
    return true
end

end # module PathUtils