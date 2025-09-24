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
base_strategy = BaseANNStrategy(...)
ann_weights = Vector(...)

# Create simulation instances
sim_without_moveup = create_simulation_instance(scenario)
sim_with_moveup, new_strategy = create_simulation_instance_with_strategy(
    scenario=scenario,
    base_strategy=base_strategy,
    new_params=ann_weights
)

# Use the JEMSS original simulate! function
jemss.simulate!(sim_without_moveup)

# Use the JEMSSWrapper new simulate_custom! function with strategy
simulate_custom!(sim_with_moveup, new_strategy)

println(jemss.getAvgCallRespondeDuration(sim_without_moveup))
println(jemss.getAvgCallRespondeDuration(sim_with_moveup))
```

## Otros ejemplos

TODO: 
* Ejemplo logging y stats
* Pensar otros posibles ejemplosg