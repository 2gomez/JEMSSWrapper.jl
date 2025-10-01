"""
PathUtils
=========

Utilities for path resolution and scenario directory management.
"""
module PathUtils

using JEMSS: jemssDir

export PROJECT_DIR, SRC_DIR, SCENARIOS_DIR, JEMSS_DIR

const SRC_DIR = dirname(@__DIR__)
const PROJECT_DIR = dirname(SRC_DIR)
const SCENARIOS_DIR = joinpath(PROJECT_DIR, "examples/scenarios")
const JEMSS_DIR = jemssDir 

end # module Pathutils