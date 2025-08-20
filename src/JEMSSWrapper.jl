# src/JEMSSWrapper.jl
module JEMSSWrapper

using JEMSS

@info "✓ Successfully loaded JEMSS from local fork"

# Path constants
const WRAPPER_PATH = joinpath(@__DIR__, "..")
const JEMSS_PATH = joinpath(@__DIR__, "..", "deps", "JEMSS")

# Make JEMSS accessible through JEMSSWrapper
const jemss = JEMSS

include("utils/path_utils.jl")
using .PathUtils

include("scenario/config.jl")
using .ConfigLoader

include("simulation/initialization.jl")
using .SimulationInitialization

include("scenario/loader.jl")
using .ScenarioLoader


# # Load utility modules
# include("utils/path_utils.jl")
# using .PathUtils

# # Load scenario management modules
# include("scenario/config.jl")
# using .ScenarioConfig

# include("scenario/validation.jl")
# using .ScenarioValidation

# include("scenario/config_loader.jl")
# using .ConfigLoader

# include("scenario/loader.jl")
# using .ScenarioLoader

# # Load simulation modules
# # include("simulation/initialization.jl")
# # using .SimulationInitialization

# # Load policy modules
# # include("policy/interface.jl")
# # using .PolicyInterface

# # Load evaluation modules
# # include("evaluation/runner.jl")
# # using .EvaluationRunner

# # Enhanced loader with TOML support
# include("scenario/enhanced_loader.jl")

# # Export main API functions
# export get_jemss_info, jemss

# # Scenario loading (original API - backward compatible)
# export load_scenario, load_scenario_config

# # Enhanced scenario loading with TOML configs
# export load_scenario_from_config, load_scenario_from_config_file, generate_default_config

# # Policy management
# export create_standard_policy

# # Evaluation
# export evaluate_policy

# # Additional utilities
# export list_scenario_configs

# # Function to get JEMSS module info (backward compatibility)
# function get_jemss_info()
#     return (
#         module_ref = JEMSS,
#         path = JEMSS_PATH,
#         exports = names(JEMSS, all=false)
#     )
# end

# # Policy creation helper (backward compatibility)
# function create_standard_policy(strategy::String = "standard")
#     return StandardMoveUpPolicy(strategy)
# end

# """
#     list_scenario_configs(scenario_name; scenarios_base_dir="")

# List available configuration files for a scenario.

# # Arguments
# - `scenario_name::String`: Name of the scenario
# - `scenarios_base_dir::String`: Base directory containing scenarios

# # Returns
# - `Vector{String}`: List of available config names
# """
# function list_scenario_configs(scenario_name::String; scenarios_base_dir::String = "")
#     return ConfigLoader.list_config_files(scenario_name, scenarios_base_dir)
# end

# """
#     evaluate_policy(scenario_data, policy; num_replications=1)

# Evaluate a policy on loaded scenario data.

# # Arguments
# - `scenario_data`: ScenarioData object from load_scenario* functions
# - `policy`: MoveUpPolicy to evaluate
# - `num_replications::Int`: Number of simulation replications

# # Returns
# - `Vector{SimulationResult}`: Results from all replications
# """
# function evaluate_policy(scenario_data, policy; num_replications::Int = 1)
#     return EvaluationRunner.evaluate_policy(scenario_data.config, policy; num_replications=num_replications)
# end

end # module JEMSSWrapper