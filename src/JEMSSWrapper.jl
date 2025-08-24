# src/JEMSSWrapper.jl
module JEMSSWrapper

using JEMSS

@info "✓ Successfully loaded JEMSS from local fork"

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

export get_jemss_info, jemss
export PROJECT_ROOT, JEMSS_DIR
export load_scenario_from_config, create_simulation_copy, set_calls!

# Function to get JEMSS module info (backward compatibility)
function get_jemss_info()
    return (
        module_ref = JEMSS,
        path = JEMSS_DIR,
        exports = names(JEMSS, all=false)
    )
end

end # module JEMSSWrapper