# JEMSS.jl vs JEMSSWrapper.jl

## Implementación de estrategias de relocalización

En **JEMSS.jl**, para utilizar una estrategia de relocalización dinámica de ambulancias en una simulación, en el momento de inicializarla se específica la estrategia y se construye un objeto auxiliar `moveUpData` que define cómo será la política de decisión, a la que se puede denominar `MoveUpPolice`. Cuando se ejecuta la simulación, internamente se utiliza la función `simulateEventConsiderMoveUp!` para crear los eventos de decisión de relocalización de ambulancias, y se calculan las relocalizaciones a ejecutar. Además, durante la propia simulación cuando una ambulancias es despachada y vuelve a estar disponible, el simulador crea un nuevo evento para considerar una relocalización sea cual sea la estrategia de relocalización. Esto supone que dentro de propia la lógica de la política de decisión `MoveUpPolice`, se decide si cuando una ambulancia es despachada o vuelve a estar disponible se debe tomar una decisión de relocalización o no.

En general, para implementar una nueva estretagía de relocalización en JEMSS, es necesario crear un nuevo módulo `MoveUpDataPolice` (de la clase `MoveUpData`) y la función `MoveUpPolice` que estima la relocalización de las ambulancias cuando se da el evento correspondiente. Después, habría que definir una nueva forma de initicialización (`initSimMoveUpPolice`) de la simulación para la nueva estrategia. De esta forma, para cada nueva simulación se definirá el objeto `moveUpData` que determinará el comportamiento de `MoveUpPolice` de relocalización de ambulancias con el que se estimarán las relocalizaciones durantes la simulación. Finalmente, habría que modificar `simulateEventConsiderMoveUp!` para que incluya la nueva estretegia de decisión. 

Esto supone que para la implementación de una nueva estrategia MoveUp hay que hacer la siguiente serie de cambios en JEMSS.jl:
* Modificar `JEMSS.jl/src/types/types.jl`: definir una nueva clase de tipo `MoveUpDataType` e incluirla en la clase `MoveUpData`.
* Añadir `JEMSS.jl/src/decision/move_up/new_police.jl`: un nuevo módulo con las funciones `initSimMoveUpPolice` y `MoveUpPolice`.
* Modificar `JEMSS.jl/src/simulation.jl`: incluir en `simulateEventConsiderMoveUp!` la nueva política `MoveUpPolice` y lo mismo con el nuevo tipo de `MoveUpDataType` en las `simulateEventAmbDispached!` y `simulateEventAmbBecomesFree!`.

En el caso de **JEMSSWrapper.jl** se extiende la lógida del simulador original añadiendo una clase abstracta `AbstractMoveUpStrategy` con sus métodos propios para simular los eventos de relocalización. De esta forma, para crear una nueva estrategia de relocalización, únicamente es necesario crear una nueva clase de tipo `AbstractMoveUpStrategy` y sus respectivos métodos: `should_trigger_on_dispatch`, `should_trigger_on_free`, `decide_moveup` e `initialize_strategy!`. Esto evitando modificar manualmente otros módulos.

## Replicación de simulaciones

La algoritmos de neuroevolución requiren de la evaluación de muchos individuos, que corresponden a las políticas de decisión de relocalización. Cada individuo es una red neuronal artificial (ANN) y aunque pueden compartir características, como la topología de la red, cada individuo es diferente (o la inmensa mayoría). Como todos los individuos tienen que ser evaluados en un mismo escenario con las mismas llamadas y ambulancias, se necesita hacer replicación de las simulaciones utilizando una ANN en cada una de ellas.

El propio **JEMSS.jl** carece de una funcionalidad tan específica y aunque trae otras para crear y ejecutar simulaciones, estas no permiten del todo implementar la lógica requerida para las replicaciones necesaria para neuroevolución. 

Es por eso que **JEMSSWrapper.jl** crea desde cero las herramientas para crear replicas pensando en los algoritmos de neuroevolución. Utilizando la función `create_simulation_instance_with_strategy` es posible crear una nueva instancia de simulación utilizando una estrategia con nuevos parámetros o una nueva ANN.

## Carga de configuración e inicialización de simulaciones

La forma en la que **JEMSS.jl** crea una simulación comienza con cargar un archivo de configuración XML. En este se definen todos los datos necesarios: hospitales, estaciones, tiempos de viaje, etc. Se incluyen las llamadas, ambulancias y las estrategias de decisión a utilizar en la simulación. Utilizando este archivo, el simulador inicializa la simulación y después está lista para ejecutarse.

En cambio, **JEMSSWrapper.jl** sigue la misma idea, pero separa los elementos de la configuración. Utiliza un archivo de configuracion TOML para definir los aspectos básicos inmutables como los hospitalas, la red de carreteras, demanda, etc. Con esto se inicializa una simulación base. Después, se utiliza un archivo con las ambulancias y llamadas para posteriormente inicializarlas. Hasta este punto, se construye una instancia de `ScenarioData` y la simulación está lista para ejecutarse. La ventaja en este punto está en la creación de replicas con diferentes estrategias de relocalización, ya que  `create_simulation_instance_with_strategy` está pensada para recibir un objeto `ScenarioData` con el que crear la nueva instancia de simulación. Además, al separar los elementos inmutables de las ambulancias y llamadas, hay una mayor flexibilidad para probar con diferentes ubicaciones iniciales de ambulancias y conjuntos de llamadas.

## Estadísticas y logging de eventos

TODO

## Otras consideraciones de JEMSSWrapper.jl

En general, todo lo que se puede hacer con **JEMSS.jl** se puede hacer de igual forma con **JEMSSWrapper.jl**, ya que todas las funcionalidades del simulador original pueden ser llamadas con el wrapper. Las limitaciones y desventajas están en la lógica específica implementada en el wrapper.

El simulador JEMSS tiene dos elementos que afectan el comportamiento de una simulación. El primero determina la estrategia a la hora de añadir llamadas a la cola de llamadas, `addCallToQueue!`, cuya estrategia por defecto es `addCallToQueueSortPriorityThenTime!`. La segunda define la estrategia de despacho de ambulancias, `findAmbToDispatch!`, que tiene como valor por defecto la estrategia de `findNearestDispatchableAmb!`. Estos dos valores por defecto son fijos durante la inicialización de una simulación utilizando JEMSSWrapper, y no hay una utilidad específica para modificarlas. 
