"""
PathUtils
=========

Utilities for path resolution and scenario directory management.
"""
module PathUtils

export PROJECT_DIR, SRC_DIR, SCENARIOS_DIR, JEMSS_DIR

const SRC_DIR = dirname(@__DIR__)
const PROJECT_DIR = dirname(SRC_DIR)
const SCENARIOS_DIR = joinpath(PROJECT_DIR, "scenarios")
const JEMSS_DIR = joinpath(PROJECT_DIR, "deps", "JEMSS")


end # module Pathutils