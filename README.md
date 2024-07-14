# SimulationParameters.jl

SimulationParameters.jl provides handing of hierarchical input simulation parameters
* enforcing type
* with descriptions
* with units
* with checks

There are three key abstract parameters types:
* `AbstractParameters` define hierarchical containers (think of dictionaries)
* `AbstractParametersVector` hold arrays of hierarchical containers
* `AbstractParameter` hold individual parameters

There are two concrete types of `AbstractParameter`:
* `Entry` where the value can be set by the user
* `Switch` which allows users to select from a limited se of `SwitchOption`s

Both `Entry` and `Switch` support the definition of ranges/functions that can be used by optimizers to vary values for each of the parameters.

## Online documentation
For more details, see the [online documentation](https://projecttorreypines.github.io/SimulationParameters.jl/dev).

![Docs](https://github.com/ProjectTorreyPines/SimulationParameters.jl/actions/workflows/make_docs.yml/badge.svg)
