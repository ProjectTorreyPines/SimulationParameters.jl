module SimulationParameters

import OrderedCollections
import AbstractTrees
import JSON

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

export AbstractParameter, AbstractParameters, AbstractParametersVector, setup_parameters!
export Entry, Switch, SwitchOption, ParametersVector
export par2dict, par2dict!, dict2par!, set_new_base!
export show_modified
export OptParameter, ↔, opt_parameters, parameters_from_opt!, rand, rand!, float_bounds
export InexistentParameterException, NotsetParameterException, BadParameterException

end # module SimulationParameters
