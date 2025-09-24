#!/bin/bash

# Script para regenerar y servir documentación de JEMSSWrapper.jl
# Uso: ./build_docs.sh

echo "🔨 Regenerando documentación..."
cd docs/
julia --project=. -e "include(\"make.jl\")"

echo "🌐 Sirviendo documentación en http://localhost:8002"
echo "   Presiona Ctrl+C para detener el servidor"
cd build/
python3 -m http.server 8002
