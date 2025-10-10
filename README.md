# JEMSSWrapper.jl

[![Docs Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://2gomez.github.io/JEMSSWrapper.jl/dev) [![License: Unlicense](https://img.shields.io/badge/license-Unlicense-blue.svg)](http://unlicense.org/)

**JEMSSWrapper.jl** is a wrapper for [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl), designed and developed specifically to facilitate the integration of neuroevolution algorithms for optimizing dynamic ambulance relocation policies.

## Installation

Install the package from the repository:

```julia
using Pkg

# Option 1: installing from a local repository
Pkg.develop(path="/path/to/JEMSSWrapper.jl")

# Option 2: installing from GitHub repository
Pkg.add(url="https://github.com/2gomez/JEMSSWrapper.jl")
```

To verify that the installation was successful:

```julia
using JEMSSWrapper
import Pkg

println("JEMSSWrapper.jl successfully installed")

Pkg.status("JEMSSWrapper")
```

## Features

- **Dynamic relocation strategies**: Create custom strategies using an abstract class without modifying the simulator internally (unlike JEMSS.jl)
- **Replication with policy changes**: Designed for move-up policie optimization with neuroevolution worflows, that require reunning multiple simulations with different parameters.  
- **TOML-based configuration**: configuration with TOML files instead of XML, plus a scenario object for easier call and ambulance set modifications

## Usage

The typical workflow involves three steps: load a scenario, optionally modify it, and run simulations with custom strategies.

```julia
using JEMSSWrapper

# Load scenario
scenario = load_scenario_from_config("auckland", "base.toml")

# Create simulation 
sim = create_simulation_instance(scenario)

# Modify calls or ambulances if needed (optional)
scenario_custom = update_scenario_calls(scenario, "custom_calls.csv")
scenario_custom = update_scenario_ambulances(scenario, "custom_ambulances.csv")

# Define a custom strategy
struct MyStrategy <: AbstractMoveUpStrategy end

JEMSSWrapper.should_trigger_on_dispatch(::MyStrategy, sim) = true
JEMSSWrapper.should_trigger_on_free(::MyStrategy, sim) = false
JEMSSWrapper.decide_moveup(::MyStrategy, sim, amb) = ([], [])

# Run simulation
simulate_custom!(sim; moveup_strategy=MyStrategy())

# Get resutls
println("Average response time: ", JEMSS.getAvgCallResponseDuration(sim))
```

## Documentation

Full documentation available at [2gomez.github.io/JEMSSWrapper.jl/dev](https://2gomez.github.io/JEMSSWrapper.jl/dev).

## License

JEMSSWrapper.jl code is released into the public domain under the [Unlicense](https://unlicense.org/).

This package depends on [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl), which is licensed under Apache License 2.0. Users must comply with Apache 2.0 terms for the JEMSS.jl dependency.

See [LICENSE](LICENSE) for details.