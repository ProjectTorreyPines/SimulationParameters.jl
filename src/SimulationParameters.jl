module SimulationParameters

import OrderedCollections
import AbstractTrees
import JSON
import YAML

include("parameter.jl")
include("entry.jl")
include("switch.jl")

include("parameters.jl")

include("io.jl")
include("utils.jl")

include("show.jl")
include("plot.jl")

include("optim.jl")

include("errors.jl")

export AbstractParameter, AbstractParameters, AbstractParametersVector
export Entry, Switch, SwitchOption, ParametersVector
export setup_parameters!, set_new_base!
export par2dict, par2dict!, dict2par!
export par2jstr, jstr2par
export par2ystr, ystr2par
export par2json, json2par
export par2yaml, yaml2par
export show_modified
export OptParameter, ↔, opt_parameters, parameters_from_opt!, rand, rand!, float_bounds
export InexistentParameterException, NotsetParameterException, BadParameterException

end # module SimulationParameters
