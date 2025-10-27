# Scenarios & Configuration

Learn how to configure and work with simulation scenarios in JEMSSWrapper.

---

## Table of Contents

- [Directory Structure](#directory-structure)
- [Configuration Files](#configuration-files)
- [Loading Scenarios](#loading-scenarios)
- [Modifying Scenarios](#modifying-scenarios)
- [Creating New Scenarios](#creating-new-scenarios)

---

## Directory Structure

Scenarios are organized in a standard directory structure:

```
scenarios/
└── auckland/
    ├── configs/
    │   ├── base.toml
    │   ├── peak_hours.toml
    │   └── reduced_fleet.toml
    └── models/              # Link or copy of JEMSS model files
        ├── hospitals/
        ├── stations/
        ├── travel/
        ├── ambulances/
        ├── calls/
        └── ...
```

### Setting the Scenarios Directory

By default, JEMSSWrapper looks for scenarios in `examples/scenarios`. Customize this location:

```julia
scenario = load_scenario_from_config("auckland", "base.toml";
                                     scenarios_dir="/path/to/scenarios")
```

---

## Configuration Files

Configuration files use TOML format and define all data files needed for a scenario.

### Complete Example

```toml
[metadata]
name = "auckland_base"
scenario_name = "auckland"
description = "Auckland scenario with standard configuration"
models_dir = "models"  # relative to scenarios/auckland/

[files]
# Infrastructure (required)
hospitals = "hospitals/hospitals_1.csv"
stations = "stations/stations_1.csv"
nodes = "travel/roads/nodes.csv"
arcs = "travel/roads/arcs.csv"
map = "maps/map_1.csv"
travel = "travel/travel/travel_1.csv"
priorities = "misc/call priorities/priorities_1.csv"
stats = "calls/single/train/stats_control.csv"

# Travel network cache (auto-generated if missing)
r_net_travels = "travel/roads/r_net_travels.jls"

# Optional demand modeling
# demand = "demand/demand_1.csv"
# demand_coverage = "demand/coverage/demand_coverage_1.csv"

[defaults]
# Default data files (can be overridden when loading)
ambulances = "ambulances/ambulances_1.csv"
calls = "calls/single/train/gen_config.xml"
```

### Configuration Sections

#### `[metadata]`

Basic scenario information:

- `name`: Unique identifier for this configuration
- `scenario_name`: Must match the directory name
- `description`: Human-readable description
- `models_dir`: Directory containing model files (relative to scenario directory)

#### `[files]`

All paths are relative to `scenarios/{scenario_name}/{models_dir}/`.

**Required files**:
- `hospitals`, `stations`: Infrastructure locations and capacities
- `nodes`, `arcs`: Road network definition
- `map`: Geographic map data
- `travel`: Travel time configuration
- `priorities`: Call priority definitions
- `stats`: Statistical configuration

**Auto-generated**:
- `r_net_travels`: Serialized travel network (computed from nodes/arcs on first run)

**Optional**:
- `demand`, `demand_coverage`: Demand modeling (can be commented out or omitted)

#### `[defaults]`

Default ambulances and calls files. Can be overridden when loading the scenario.

---

## Loading Scenarios

### Basic Loading

```julia
# Load with default ambulances and calls from config
scenario = load_scenario_from_config("auckland", "base.toml")
```

This loads:
- Config: `scenarios/auckland/configs/base.toml`
- Models: `scenarios/auckland/models/...`
- Default ambulances and calls from `[defaults]` section

### Custom Data Files

Override default ambulances or calls:

```julia
# Custom calls only
scenario = load_scenario_from_config("auckland", "base.toml";
                                     calls_path="data/peak_hours_calls.csv")

# Custom ambulances and calls
scenario = load_scenario_from_config("auckland", "base.toml";
                                     ambulances_path="data/fleet_15.csv",
                                     calls_path="data/test_calls.csv")
```

### Multiple Configurations

Load different configurations of the same scenario:

```julia
# Standard configuration
base = load_scenario_from_config("auckland", "base.toml")

# Peak hours scenario
peak = load_scenario_from_config("auckland", "peak_hours.toml")

# Budget constraints
budget = load_scenario_from_config("auckland", "reduced_fleet.toml")
```

---

## Modifying Scenarios

Once loaded, scenarios can be modified without reloading infrastructure.

### Update Calls

Test different demand patterns on the same infrastructure:

```julia
# Load base scenario
base_scenario = load_scenario_from_config("auckland", "base.toml")

# Update with different call patterns
peak_scenario = update_scenario_calls(base_scenario, "data/peak_calls.csv")
night_scenario = update_scenario_calls(base_scenario, "data/night_calls.csv")
```

### Update Ambulances

Test different fleet configurations:

```julia
# Start with base scenario
base_scenario = load_scenario_from_config("auckland", "base.toml")

# Try different fleet sizes
fleet_10_scenario = update_scenario_ambulances(base_scenario, "data/10_ambulances.csv")
fleet_15_scenario = update_scenario_ambulances(base_scenario, "data/15_ambulances.csv")
```

---

## Creating New Scenarios

### Step 1: Prepare Model Files

Option A - Use JEMSS city models from `JEMSS_DATA_DIR` path. Available cities: auckland, edmonton, manhattan, utrecht

Option B - Prepare your own model files following JEMSS format.

### Step 2: Create Directory Structure

```bash
# Create scenario directories
mkdir -p scenarios/my_city/configs
mkdir -p scenarios/my_city/models

# Or use existing structure
scenarios/
└── my_city/
    ├── configs/
    └── models/
```

### Step 3: Link or Copy Model Files

```bash
# Option 1: Symbolic link (recommended for JEMSS cities)
ln -s ~/.julia/packages/JEMSS/.../data/cities/auckland/models/1 \
      scenarios/my_city/models

# Option 2: Copy files (if you need to modify them)
cp -r /path/to/model/files/* scenarios/my_city/models/
```

### Step 4: Create Configuration File

Create `scenarios/my_city/configs/base.toml` following the format shown above. Ensure:

- `scenario_name` matches directory name (`my_city`)
- All file paths exist in `models/` directory
- Required files are specified
- Optional files (`demand`, `demand_coverage`) are commented out if not available

### Step 5: Test Loading

```julia
scenario = load_scenario_from_config("my_city", "base.toml")
sim = simulate_scenario(scenario)

# Verify it loaded correctly
println("Stations: ", sim.numStations)
println("Ambulances: ", sim.numAmbs)
println("Hospitals: ", sim.numHospitals)
```

## See Also

- **[API Reference](@ref)** - Complete function documentation
- **[JEMSS.jl Data](https://github.com/uoa-ems-research/JEMSS.jl/tree/master/data/cities)** - Example city models