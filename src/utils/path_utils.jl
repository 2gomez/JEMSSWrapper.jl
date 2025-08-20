"""
PathUtils
=========

Utilities for path resolution and scenario directory management.
"""
module PathUtils

export PROJECT_ROOT, SRC_DIR, SCENARIOS_DIR

const SRC_DIR = dirname(@__DIR__)
const PROJECT_ROOT = dirname(SRC_DIR)
const SCENARIOS_DIR = joinpath(PROJECT_ROOT, "scenarios")
# const JEMSS_DIR = joinpath(PROJECT_ROOT, "deps", "JEMSS")


end # module Pathutils