module SimulationParameters

import OrderedCollections
import AbstractTrees
import JSON
import YAML
import HDF5
import Measurements: ±, Measurement
import IMASutils: mirror_bound, argmin_abs
import Distributions
import Dates
import Serialization
import Base64
import HelpPlots

include("parameter.jl")

include("entry.jl")

include("switch.jl")

include("parameters.jl")

include("io.jl")

include("utils.jl")

include("optim.jl")

include("override.jl")

include("grouped.jl")

include("show.jl")

include("plot.jl")

include("errors.jl")

include("isequal.jl")

export AbstractParameter, AbstractParameters, AbstractParametersVector
export Entry, Switch, SwitchOption, ParametersVector, TimeData
export OverrideParameters
export setup_parameters!, set_new_base!
export par2dict, par2dict!, dict2par!
export par2jstr, jstr2par
export par2ystr, ystr2par
export par2json, json2par
export par2yaml, yaml2par
export par2hdf, hdf2par
export show_modified
export OptParameter, ↔, opt_parameters, parameters_from_opt!, rand, rand!, float_bounds, nominal_values, opt_labels
export InexistentParametersFieldException, NotsetParameterException, BadParameterException
export grouping_parameters

const document = Dict()
document[Symbol(@__MODULE__)] = [name for name in Base.names(@__MODULE__; all=false, imported=false) if name != Symbol(@__MODULE__)]

end # module SimulationParameters
