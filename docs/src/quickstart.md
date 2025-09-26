# Guía de Inicio Rápido

Esta guía te ayudará a comenzar con JEMSSWrapper.jl en pocos minutos.

## Ejemplo Básico

```julia
using JEMSSWrapper

# Load scenario
scenario = load_scenario_from_config(
    scenario_name="auckland",
    config_name="base.toml",
    ambulance_file="ambulances/ambulances_1.csv"
    calls_file="calls/single/train/gen_config.xml"
)

# Define strategy
my_strategy = BaseANNStrategy(...)

# Create simulation instance
sim_instance = create_simulation_instance(scenario)

# Use the JEMSSWrapper new simulate_custom! function with strategy
simulate_custom!(sim_instance, my_strategy)

# Print average responde time
println(jemss.getAvgCallRespondeDuration(sim_instance))
```

## Otros ejemplos

TODO: 
* Ejemplo logging y stats
* Pensar otros posibles ejemplosg