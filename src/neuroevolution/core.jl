# src/neuroevolution/core.jl
"""
Neuroevolution Core
==================

Basic structure for neuroevolution policy evaluation system.
"""
module NeuroevolutionCore

using JEMSS

export AbstractStateEncoder, AbstractPolicy, AbstractEvaluator

"""
Interface for converting simulation states into neural network input format.
"""
abstract type AbstractStateEncoder end

"""
    encode_state(encoder::AbstractStateEncoder, sim::JEMSS.Simulation) -> Vector{Float64}

Convert simulation state into neural network input vector.
"""
function encode_state end

"""
Interface for neural network policies that make decisions.
"""
abstract type AbstractPolicy end

"""
    predict(policy::AbstractPolicy, state::Vector{Float64}) -> Int

Make a decision based on the current state representation.
For now, returns an integer representing the decision.
"""
function predict end

"""
Interface for evaluating policies within the simulation environment.
"""
abstract type AbstractEvaluator end

"""
    evaluate_policy(evaluator::AbstractEvaluator, policy::AbstractPolicy, scenario_data) -> Float64

Evaluate a policy's performance. Returns a single metric value.
"""
function evaluate_policy end

end # module NeuroevolutionCore