# JEMSS Wrapper

A Julia wrapper for the JEMSS (Julia Emergency Medical Services Simulator) to facilitate policy evaluation and neuroevolution experiments.

## Setup

### 1. Clone with submodules
```bash
git clone --recursive https://github.com/2gomez/JEMSSWrapper.jl.git
cd JEMSSWrapper.jl
```

### 2. If already cloned without submodules
```bash
git submodule update --init --recursive
```

### 3. Setup local JEMSS dependency
```bash
julia --project=. -e 'using Pkg; Pkg.develop(path="deps/JEMSS")'
```

<!-- Check for the `unzip_data.jl` file -->

### 4. Test the wrapper
```bash
julia --project=. examples/basic_test.jl
```

## Structure

```
JEMSSWrapper.jl/
├── src/
│   └── JEMSSWrapper.jl    # Main module
├── examples/
│   └── basic_test.jl      # Basic functionality test
├── deps/
│   └── JEMSS/             # JEMSS fork submodule
└── Project.toml
```

## Usage

```julia
using JEMSSWrapper

# Access JEMSS functionality through the wrapper
# TODO: Add usage examples once implementation is complete
```

## Development

This is an initial minimal version that verifies:
- Local JEMSS fork can be loaded as dependency
- Basic wrapper functionality works
- Foundation for policy evaluation system

Future development will add policy interfaces, metrics extraction, and parallel evaluation capabilities.