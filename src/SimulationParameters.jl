module SimulationParameters

import OrderedCollections
import AbstractTrees
import JSON

#= ================= =#
#  AbstractParameter  #
#= ================= =#
include("parameter.jl")

#= ===== =#
#  Entry  #
#= ===== =#
include("entry.jl")

#= ====== =#
#  Switch  #
#= ====== =#
include("switch.jl")

#= ================== =#
#  AbstractParameters  #
#= ================== =#
include("parameters.jl")

#= ========= =#
#  utilities  #
#= ========= =#
include("utils.jl")

#= ==== =#
#  show  #
#= ==== =#
include("show.jl")

#= ====================== =#
#  Optimization parameter  #
#= ====================== =#
include("optim.jl")

#= ================= =#
#  Parameters errors  #
#= ================= =#
include("errors.jl")

export AbstractParameter, AbstractParameters, setup_parameters!
export Entry, Switch, SwitchOption
export par2dict, par2dict!, dict2par!, set_new_base!
export OptParameter, ↔, opt_parameters, parameters_from_opt!, rand!
export InexistentParameterException, NotsetParameterException, BadParameterException

end # module SimulationParameters
