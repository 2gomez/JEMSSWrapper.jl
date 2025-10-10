# JEMSSWrapper.jl Documentation

*A Julia wrapper for JEMSS.jl designed to facilitate custom ambulance relocation strategies through neuroevolution*

## Overview

JEMSSWrapper.jl provides a clean, extensible interface to the [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl) emergency medical services simulator. It enables researchers to develop and test custom dynamic ambulance relocation policies without modifying the core simulator.

**Key Features:**
- **Dynamic relocation strategies**: Create custom strategies using an abstract class without modifying the simulator internally.
- **Replication with policy changes**: Designed for move-up policie optimization with neuroevolution worflows, that require running multiple simulations with different parameters.  
- **TOML-based configuration**: configuration with TOML files instead of XML, plus a scenario object for easier call and ambulance set modifications.

## Quick Start

### Installation
```julia
using Pkg

# Option 1: installing from a local repository
Pkg.develop(path="/path/to/JEMSSWrapper.jl")

# Option 2: installing from GitHub repository
Pkg.add(url="https://github.com/2gomez/JEMSSWrapper.jl")
Pkg.add(url="https://github.com/2gomez/JEMSSWrapper.jl")
```

### Basic Simulation

```julia
using JEMSSWrapper

# Load scenario
scenario = load_scenario_from_config("auckland", "base.toml")

# Create simulation
sim = create_simulation_instance(scenario)

# Define a custom strategy
struct MyStrategy <: AbstractMoveUpStrategy end

JEMSSWrapper.should_trigger_on_dispatch(::MyStrategy, sim) = true
JEMSSWrapper.should_trigger_on_free(::MyStrategy, sim) = false
JEMSSWrapper.decide_moveup(::MyStrategy, sim, amb) = ([], [])

# Run simulation
simulate_custom!(sim; moveup_strategy=MyStrategy())

# Get results
println("Average response time: ", JEMSS.getAvgCallResponseDuration(sim))
```

### Core Concepts

#### ScenarioData

An immutable struct containing a basic scenario defined by:
- The base simulation object. Without the calls and ambulances.
- The initialized calls set to use in the simulation.
- The ambulances and its initial positions to use in the simulation.
- Metadata of the scenario configuración, base simulation, calls and ambulances.

#### AbstractMoveUpStrategy

An interface for implementing custom ambulance relocation policies. Each strategie has to decide:

- **When** to trigger relocations: on dispatch or on ambulance free.
- **Which** ambulances to move.
- **Where** to send them.

## License

JEMSSWrapper.jl code is released into the public domain under the [Unlicense](https://unlicense.org/).

This package depends on [JEMSS.jl](https://github.com/uoa-ems-research/JEMSS.jl), which is licensed under Apache License 2.0. Users must comply with Apache 2.0 terms for the JEMSS.jl dependency.