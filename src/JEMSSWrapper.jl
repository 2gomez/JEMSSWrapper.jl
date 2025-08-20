module JEMSSWrapper

using JEMSS

@info "✓ Successfully loaded JEMSS from local fork"

# Some path constants of JEMSSWrapper
const WRAPPER_PATH = joinpath(@__DIR__, "..")
const JEMSS_PATH = joinpath(@__DIR__, "..", "deps", "JEMSS")

# Make JEMSS accessible through JEMSSWrapper
const jemss = JEMSS

# Function to get JEMSS module info
function get_jemss_info()
    return (
        module_ref = JEMSS,
        path = JEMSS_PATH,
        exports = names(JEMSS, all=false)
    )
end

# Export the info function for testing
export get_jemss_info, jemss

end # module JEMSSWrapper