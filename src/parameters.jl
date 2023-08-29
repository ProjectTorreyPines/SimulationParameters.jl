abstract type AbstractParameters end

function setup_parameters!(parameters::AbstractParameters)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: Union{AbstractParameter,AbstractParameters}
            setfield!(parameter, :_parent, WeakRef(parameters))
            setfield!(parameter, :_name, field)
        end
        if typeof(parameter) <: AbstractParameters
            setup_parameters!(parameter)
        end
    end
end

function set_new_base!(parameters::AbstractParameters)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            set_new_base!(parameter)
        else
            setfield!(parameter, :base, parameter.value)
        end
    end
    return parameters
end

function Base.getproperty(parameters::AbstractParameters, field::Symbol)
    if startswith(string(field), "_")
        error("use getfield for :$field")
    end
    if field ∉ keys(parameters)
        throw(InexistentParameterException([path(parameters); field]))
    end
    parameter = getfield(parameters, field)
    if typeof(parameter) <: AbstractParameters
        return parameter
    else
        if parameter.value === missing
            if typeof(parameter) <: Entry
                throw(NotsetParameterException([path(parameters); field], parameter.units))
            elseif typeof(parameter) <: Switch
                throw(NotsetParameterException([path(parameters); field], parameter.units, collect(keys(parameter.options))))
            else
                error("Should not be here")
            end
        elseif typeof(parameter.value) <: Function
            return parameter.value(top(parameters).time.simulation_start)
        else
            tp = typeof(parameter).parameters[1]
            return parameter.value::tp
        end
    end
end

"""
Return value of `key` parameter or `default` if parameter is missing

NOTE: This is useful because accessing a `missing` parameter would raise an error
"""
function Base.getproperty(parameters::AbstractParameters, field::Symbol, default)
    if field ∉ keys(parameters)
        throw(InexistentParameterException([path(parameters); field]))
    end
    parameter = getfield(parameters, field)
    if typeof(parameter) <: AbstractParameters
        return parameter
    else
        if parameter.value === missing
            return default
        else
            tp = typeof(parameter).parameters[1]
            return parameter.value::tp
        end
    end
end

function Base.deepcopy(parameters::T) where {T<:Union{AbstractParameter,AbstractParameters}}
    parameters1 = Base.deepcopy_internal(parameters, Base.IdDict())::T
    setfield!(parameters1, :_parent, WeakRef(nothing))
    return parameters1
end

function Base.setproperty!(parameters::AbstractParameters, field::Symbol, value::Any)
    if startswith(string(field), "_")
        error("use setfield! for :$field")
    end
    if field ∉ keys(parameters)
        throw(InexistentParameterException([path(parameters); field]))
    end

    parameter = getfield(parameters, field)

    if typeof(parameter) <: AbstractParameter
        if typeof(value) <: OptParameter
            setfield!(parameter, :opt, value)
            value = getfield(value, :nominal)
        else
            setfield!(parameter, :opt, missing)
        end
        parameter.value = value

    elseif typeof(parameter) <: AbstractParameters
        setfield!(parameters, field, value)

    else
        error("AbstractParameters should only hold other AbstractParameter or AbstractParameters types")
    end

    parameter = getfield(parameters, field)
    setfield!(parameter, :_name, field)
    setfield!(parameter, :_parent, WeakRef(parameters))

    return value
end

function Base.keys(parameters::Union{AbstractParameter,AbstractParameters})
    return (field for field in fieldnames(typeof(parameters)) if field ∉ (:_parent, :_name))
end

function Base.values(parameters::Union{AbstractParameter,AbstractParameters})
    return (getfield(parameters, field) for field in fieldnames(typeof(parameters)) if field ∉ (:_parent, :_name))
end

function Base.parent(parameters::Union{AbstractParameter,AbstractParameters})
    return getfield(parameters, :_parent).value
end

function name(parameters::Union{AbstractParameter,AbstractParameters})
    return getfield(parameters, :_name)
end

"""
    top(parameters::Union{AbstractParameter,AbstractParameters})

Returns the top level that contains this parameter/parameters
"""
function top(parameters::Union{AbstractParameter,AbstractParameters})
    h = parameters
    while parent(h) !== nothing
        h = parent(h)
    end
    return h
end

"""
    path(parameters::Union{AbstractParameter,AbstractParameters})::Vector{Symbol}

Returns the location in the parameters hierarchy as a vector of Symbols
"""
function path(parameters::Union{AbstractParameter,AbstractParameters})::Vector{Symbol}
    if parent(parameters) === nothing
        return Symbol[name(parameters)]
    else
        return Symbol[path(parent(parameters)); name(parameters)]
    end
end

"""
    leaves(pars::AbstractParameters)::Vector{AbstractParameter}

Returns a vector with all the parameters contained downstream of pars
"""
function leaves(pars::AbstractParameters)::Vector{AbstractParameter}
    res = Vector{AbstractParameter}()
    leaves!(pars, res)
    return res
end

function leaves!(pars::AbstractParameters, res::Vector{AbstractParameter})
    for field in keys(pars)
        par = getfield(pars, field)
        if typeof(par) <: AbstractParameters
            leaves!(par, res)
        else
            push!(res, par)
        end
    end
end

function Base.ismissing(parameters::AbstractParameters, field::Symbol)::Bool
    return getfield(parameters, field).value === missing
end

"""
    (par::AbstractParameters)(kw...)

This functor is used to override the parameters at function call
"""
function (par::AbstractParameters)(kw...)
    par_copy = deepcopy(par)
    if !isempty(kw)
        for (key, value) in kw
            setproperty!(par_copy, key, value)
        end
    end
    setfield!(par_copy, :_parent, getfield(par, :_parent))
    return par_copy
end