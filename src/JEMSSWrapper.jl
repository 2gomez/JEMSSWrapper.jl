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

include("simulation/replication.jl")
using .SimulationReplication

export get_jemss_info, jemss
export PROJECT_DIR, JEMSS_DIR
export load_scenario_from_config, create_simulation_copy, set_calls!
export create_simulation_instances

end # module JEMSSWrapper