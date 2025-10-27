# JEMSSWrapper.jl

*A Julia wrapper for JEMSS.jl designed to facilitate custom ambulance relocation strategies through evoluation and neuroevolution*

## Overview

JEMSSWrapper.jl provides a clean, extensible interface to the [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl) emergency medical services simulator. It enables researchers to develop and test custom dynamic ambulance relocation policies without modifying the core simulator.

**Key Features:**
- **Dynamic relocation strategies**: Create custom strategies using an abstract class without modifying the simulator internally.
- **Replication with policy changes**: Designed for move-up policie optimization with evoluation based worflows, that require running multiple simulations with different parameters.  
- **TOML-based configuration**: configuration with TOML files instead of XML, plus a scenario object for easier call and ambulance set modifications.

## Quick Start

### Installation
```julia
using Pkg

# Option 1: installing from a local repository
Pkg.develop(path="/path/to/JEMSSWrapper.jl")

# Option 2: installing from GitHub repository
Pkg.add(url="https://github.com/2gomez/JEMSSWrapper.jl")
```

### Basic Simulation

```julia
using JEMSSWrapper

# Load scenario
scenario = load_scenario_from_config("auckland", "base.toml")

# Define a custom strategy
struct MyStrategy <: AbstractMoveUpStrategy end

JEMSSWrapper.should_trigger_on_dispatch(::MyStrategy, sim) = true
JEMSSWrapper.should_trigger_on_free(::MyStrategy, sim) = false
JEMSSWrapper.decide_moveup(::MyStrategy, sim, amb) = ([], [], [])

# Run a simulation instance from the scenario
sim = simulate_scenario!(sim; moveup_strategy=MyStrategy())

# Get results
avg_response_time = get_metric(sim, :avg_response_time) # in days
println("Average response time: $(avg_response_time * 24 * 60) minutes") 
```

## License

JEMSSWrapper.jl code is released into the public domain under the [Unlicense](https://unlicense.org/).

This package depends on [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl), which is licensed under Apache License 2.0. Users must comply with Apache 2.0 terms for the JEMSS.jl dependency.