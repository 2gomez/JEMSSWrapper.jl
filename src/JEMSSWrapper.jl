module JEMSSWrapper

using JEMSS

@info "✅ Successfully loaded JEMSS from local fork"

# Path constants
const WRAPPER_PATH = joinpath(@__DIR__, "..")
const JEMSS_PATH = joinpath(@__DIR__, "..", "deps", "JEMSS")

# Make JEMSS accessible through JEMSSWrapper
const jemss = JEMSS

# Include all submodules
include("utils/path_utils.jl")
include("scenario/config.jl")
include("scenario/validation.jl")
include("scenario/loader.jl")
include("simulation/initialization.jl")
include("policy/interface.jl")
include("evaluation/runner.jl")

# Import modules
using .PathUtils
using .ScenarioConfig
using .ScenarioValidation
using .ScenarioLoader
using .SimulationInitialization
using .PolicyInterface
using .EvaluationRunner

# Legacy function for compatibility
function get_jemss_info()
    return (
        module_ref = JEMSS,
        path = JEMSS_PATH,
        exports = names(JEMSS, all=false)
    )
end

# High-level convenience functions

"""
    load_scenario(scenario_name::String, calls_date::String = "2019-1-1")

Load a scenario for policy evaluation.

# Arguments
- `scenario_name::String`: Name of the scenario
- `calls_date::String`: Date specification for calls data

# Returns
- `ScenarioData`: Loaded scenario data

# Example
```julia
scenario = JEMSSWrapper.load_scenario("wellington", "2019-1-1")
```
"""
function load_scenario(scenario_name::String, calls_date::String = "2019-1-1")
    return ScenarioLoader.load_scenario(scenario_name, calls_date)
end

"""
    evaluate_policy(scenario_data, policy; num_replications::Int = 1)

Evaluate a policy on a loaded scenario.

# Arguments
- `scenario_data`: Loaded scenario data
- `policy`: Policy to evaluate
- `num_replications::Int`: Number of simulation runs

# Returns
- `Vector{SimulationResult}`: Results from evaluation

# Example
```julia
scenario = JEMSSWrapper.load_scenario("wellington")
policy = JEMSSWrapper.StandardMoveUpPolicy("standard")
results = JEMSSWrapper.evaluate_policy(scenario, policy; num_replications=3)
```
"""
function evaluate_policy(scenario_data, policy; num_replications::Int = 1)
    return EvaluationRunner.evaluate_policy(scenario_data.config, policy; num_replications=num_replications)
end

"""
    create_standard_policy(strategy::String = "standard")

Create a standard move-up policy.

# Arguments
- `strategy::String`: Strategy name ("standard", "dmexclp")

# Returns
- `StandardMoveUpPolicy`: Policy object

# Example
```julia
policy = JEMSSWrapper.create_standard_policy("dmexclp")
```
"""
function create_standard_policy(strategy::String = "standard")
    return StandardMoveUpPolicy(strategy)
end

# Main exports - high-level API
export load_scenario, evaluate_policy, create_standard_policy

# Type exports
export ScenarioData, SimulationResult, StandardMoveUpPolicy

# Utility exports
export get_jemss_info, jemss

# Module exports for advanced usage
export ScenarioLoader, EvaluationRunner, PolicyInterface

end # module JEMSSWrapper