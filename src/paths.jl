"""
    PROJECT_DIR

Root directory of the JEMSSWrapper package.
"""
const PROJECT_DIR = dirname(dirname(@__FILE__))

"""
    SCENARIOS_DIR

Directory containing scenario symbolic links.
"""
const SCENARIOS_DIR = joinpath(PROJECT_DIR, "examples", "scenarios")

"""
    JEMSS_DATA_DIR

Directory containing JEMSS data files.
"""
const JEMSS_DATA_DIR = joinpath(JEMSS.jemssDir, "data")