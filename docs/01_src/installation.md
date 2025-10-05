# Instalación

## Requisitos del Sistema

JEMSSWrapper.jl requiere:
- Julia ≥ 1.8
- JEMSS.jl (instalado automáticamente como dependencia)

## Instalación desde Código Fuente

Como este es un paquete no registrado, la instalación se realiza directamente desde el repositorio:

```julia
using Pkg

# Opción 1: Instalar desde repositorio local
Pkg.develop(path="/ruta/a/tu/JEMSSWrapper.jl")

# Opción 2: Instalar desde GitHub (cuando esté disponible)
# Pkg.add(url="https://github.com/2gomez/JEMSSWrapper.jl")
```

## Verificación de la Instalación

Para verificar que la instalación fue exitosa:

```julia
using JEMSSWrapper

# Verificar que el módulo se carga correctamente
println("JEMSSWrapper.jl instalado correctamente")

# Verificar versión
import Pkg
Pkg.status("JEMSSWrapper")
```

## Configuración inicial

TODO: 
* Descomprimir archivos JEMSS. 
