"""
PolicyInterface
===============

Basic policy interface for move-up strategies.
This is a minimal implementation for Phase 1.
"""
module PolicyInterface

export MoveUpPolicy, StandardMoveUpPolicy, apply_policy!

"""
    abstract type MoveUpPolicy

Abstract base type for all move-up policies.
"""
abstract type MoveUpPolicy end

"""
    struct StandardMoveUpPolicy <: MoveUpPolicy

Standard move-up policy that uses JEMSS built-in strategies.
"""
struct StandardMoveUpPolicy <: MoveUpPolicy
    strategy::String
    parameters::Dict{String, Any}
end

"""
    StandardMoveUpPolicy(strategy::String = "standard")

Create a standard move-up policy.

# Arguments
- `strategy::String`: Strategy name ("standard", "dmexclp", etc.)
"""
function StandardMoveUpPolicy(strategy::String = "standard")
    return StandardMoveUpPolicy(strategy, Dict{String, Any}())
end

"""
    apply_policy!(sim, policy::StandardMoveUpPolicy)

Apply a standard move-up policy to a simulation.
For Phase 1, this just sets up the basic JEMSS move-up configuration.

# Arguments
- `sim`: JEMSS Simulation object
- `policy::StandardMoveUpPolicy`: Policy to apply
"""
function apply_policy!(sim, policy::StandardMoveUpPolicy)
    # Access JEMSS through the wrapper
    JEMSS = Main.JEMSSWrapper.jemss
    
    mud = sim.moveUpData
    if policy.strategy == "standard"
        mud.useMoveUp = false
        mud.moveUpModule = JEMSS.nullMoveUpModule
    elseif policy.strategy == "dmexclp"
        mud.useMoveUp = true
        mud.moveUpModule = JEMSS.dmexclpModule
        # Apply parameters if available
        busy_fraction = get(policy.parameters, "busyFraction", 0.4)
        JEMSS.initDmexclp!(sim; busyFraction=busy_fraction)
    else
        @warn "Unknown move-up strategy: $(policy.strategy), using standard"
        mud.useMoveUp = false
        mud.moveUpModule = JEMSS.nullMoveUpModule
    end
end

"""
    get_policy_name(policy::MoveUpPolicy)

Get a descriptive name for the policy.
"""
function get_policy_name(policy::StandardMoveUpPolicy)
    return "Standard-$(policy.strategy)"
end

end # module PolicyInterface