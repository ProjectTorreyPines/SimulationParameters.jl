abstract type AbstractParameters{T} end

# ======================== #
# AbstractParametersVector #
# ======================== #
abstract type AbstractParametersVector{T} <: AbstractVector{T} end

Base.@kwdef mutable struct ParametersVector{T<:AbstractParameters} <: AbstractParametersVector{T}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = Symbol("[]")
    _aop::Vector{T} = Vector{T}()
end

function Base.eltype(::Type{ParametersVector{T}}) where {T}
    return T
end

function Base.size(pv::AbstractParametersVector)
    return size(pv._aop)
end

function Base.getindex(pv::AbstractParametersVector, i::Any)
    return getindex(pv._aop, i)
end

function Base.setindex!(pv::AbstractParametersVector, value, i::Int)
    return setindex!(pv._aop, value, i)
end

function Base.popat!(pv::AbstractParametersVector, i::Int)
    return popat!(pv._aop, i)
end

function Base.pop!(pv::AbstractParametersVector)
    return pop!(pv._aop)
end

function Base.empty!(pv::AbstractParametersVector)
    return empty!(pv._aop)
end

function Base.deleteat!(pv::AbstractParametersVector, i::Int)
    return deleteat!(pv._aop, i)
end

function Base.iterate(pv::AbstractParametersVector)
    return iterate(pv._aop)
end

function Base.iterate(pv::AbstractParametersVector, state)
    return iterate(pv._aop, state)
end

function Base.resize!(pv::AbstractParametersVector, n::Int, args...; kw...)
    d = n - length(pv._aop)
    if d > 0
        for k in 1:d
            push!(pv, eltype(pv)(args...; kw...))
        end
    elseif d < 0
        for k in 1:-d
            pop!(pv)
        end
    end

    return pv
end

function Base.push!(parameters_vector::AbstractParametersVector, parameters::AbstractParameters)
    aop = getfield(parameters_vector, :_aop)
    setfield!(parameters, :_parent, WeakRef(parameters_vector))
    setfield!(parameters, :_name, Symbol(length(parameters_vector)))
    setup_parameters!(parameters)
    return push!(aop, parameters)
end

function Base.setindex!(parameters_vector::AbstractParametersVector, index::Int, parameters::AbstractParameters)
    aop = getfield(parameters_vector, :_aop)
    setfield!(parameters, :_parent, WeakRef(parameters_vector))
    setfield!(parameters, :_name, Symbol(index))
    setup_parameters!(parameters)
    return setindex!(aop, index, parameters)
end

function setup_parameters!(parameters::AbstractParametersVector)
    for (kk, parameter) in enumerate(parameters)
        if typeof(parameter) <: AbstractParameters
            setfield!(parameter, :_parent, WeakRef(parameters))
            setfield!(parameter, :_name, Symbol(kk))
            setup_parameters!(parameter)
        else
            error("$(spath(parameters))[$kk] can only be a subtype of `AbstractParameters`")
        end
    end
end

function set_new_base!(@nospecialize(parameters::AbstractParametersVector))
    for (kk, parameter) in enumerate(parameters)
        if typeof(parameter) <: AbstractParameters
            setfield!(parameter, :_parent, WeakRef(parameters))
            setfield!(parameter, :_name, Symbol(kk))
            set_new_base!(parameter)
        else
            error("$(spath(parameters))[$kk] can only be a subtype of `AbstractParameters`")
        end
    end
end

# ================== #
# AbstractParameters #
# ================== #
function getparameter(parameters::AbstractParameters, field::Symbol)
    return getfield(parameters, field)
end

function setup_parameters!(parameters::AbstractParameters)
    for field in keys(parameters)
        parameter = getparameter(parameters, field)
        if typeof(parameter) <: Union{AbstractParameter,AbstractParameters,AbstractParametersVector}
            setfield!(parameter, :_parent, WeakRef(parameters))
            setfield!(parameter, :_name, field)
        else
            error(
                "$(spath(parameters)).$field can only be a subtype of `AbstractParameter`, `AbstractParameters`, `AbstractParametersVector` and not `$(typeof(parameter))`"
            )
        end
        if typeof(parameter) <: AbstractParameter
            # pass
        elseif typeof(parameter) <: AbstractParameters
            setup_parameters!(parameter)
        elseif typeof(parameter) <: AbstractParametersVector
            setup_parameters!(parameter)
        else
            error("setup_parameters! should not be here")
        end
    end
end

function set_new_base!(@nospecialize(parameters::AbstractParameters))
    for field in keys(parameters)
        parameter = getparameter(parameters, field)
        if typeof(parameter) <: AbstractParameters
            set_new_base!(parameter)
        elseif typeof(parameter) <: AbstractParametersVector
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
        throw(InexistentParametersFieldException(parameters, field))
    end
    parameter = getparameter(parameters, field)
    if typeof(parameter) <: AbstractParameters
        return parameter
    elseif typeof(parameter) <: AbstractParametersVector
        return parameter
    else
        if parameter.value === missing
            if typeof(parameter) <: Entry
                throw(NotsetParameterException([path(parameters); field], parameter.units))
            elseif typeof(parameter) <: Switch
                throw(NotsetParameterException([path(parameters); field], parameter.units, collect(keys(parameter.options))))
            else
                error("Only `Entry` and `Switch` are recognized subtypes of `AbstractParameter`")
            end
        else
            tp = typeof(parameter).parameters[1]
            # if the user entered a function for a parameter that was not explicitly of Function type,
            # then this is an indication of a time dependent parameter
            if typeof(parameter.value) <: Union{Function,TimeData} && !(tp <: Function)
                time0 = global_time(parameters)
                value = parameter.value(time0)
                if !ismissing(value) && !isnothing(parameter.check) && !(typeof(value) <: Function)
                    parameter.check(value)
                end
                return value::tp
            else
                return parameter.value::tp
            end
        end
    end
end

function _getproperty(parameters::AbstractParameters, field::Symbol, default)
    if field ∉ keys(parameters)
        throw(InexistentParametersFieldException(parameters, field))
    end
    parameter = getfield(parameters, field)
    if typeof(parameter) <: AbstractParameters
        return parameter
    else
        if parameter.value === missing
            return default
        else
            tp = typeof(parameter).parameters[1]
            return getproperty(parameters, field)::tp
        end
    end
end

"""
Return value of `key` parameter or `default` if parameter is missing

NOTE: This is useful because accessing a `missing` parameter would raise an error
"""
function Base.getproperty(parameters::AbstractParameters, field::Symbol, default)
    return _getproperty(parameters, field, default)
end

function Base.getproperty(parameters::AbstractParameters, field::Symbol, default::Symbol)
    return _getproperty(parameters, field, default)
end

function Base.deepcopy(parameters::T) where {T<:Union{AbstractParameter,AbstractParameters}}
    parameters1 = Base.deepcopy_internal(parameters, Base.IdDict())
    setfield!(parameters1, :_parent, WeakRef(nothing))
    return parameters1
end

function Base.setproperty!(parameters::AbstractParameters, field::Symbol, value::Any)
    if startswith(string(field), "_")
        error("use setfield! for :$field")
    end
    if field ∉ keys(parameters)
        throw(InexistentParametersFieldException(parameters, field))
    end

    parameter = getparameter(parameters, field)

    if typeof(parameter) <: AbstractParameter
        if typeof(value) <: OptParameter
            setfield!(parameter, :opt, value)
            value = getfield(value, :nominal)
        else
            setfield!(parameter, :opt, missing)
        end

        if !ismissing(value) && !isnothing(parameter.check) && !(typeof(value) <: Union{Function,TimeData})
            parameter.check(value)
        end

        parameter.value = value

    elseif typeof(parameter) <: AbstractParametersVector
        setfield!(parameters, field, value)

    elseif typeof(parameter) <: AbstractParameters
        setfield!(parameters, field, value)

    else
        error("AbstractParameters should only hold other `AbstractParameter`, `AbstractParameters`, or `AbstractParametersVector` types, not `$(typeof(parameter))")
    end

    parameter = getparameter(parameters, field)
    setfield!(parameter, :_name, field)
    setfield!(parameter, :_parent, WeakRef(parameters))

    return value
end

function Base.keys(parameters::Union{AbstractParameter,AbstractParameters})
    return (field for field in fieldnames(typeof(parameters)) if !startswith(string(field), '_'))
end

function Base.values(parameters::AbstractParameters)
    return (getparameter(parameters, field) for field in fieldnames(typeof(parameters)) if !startswith(string(field), '_'))
end

function Base.values(parameters::AbstractParameter)
    return (getfield(parameters, field) for field in fieldnames(typeof(parameters)) if !startswith(string(field), '_'))
end

function Base.parent(parameters::Union{AbstractParameter,AbstractParameters,AbstractParametersVector})
    return getfield(parameters, :_parent).value
end

function name(parameters::Union{AbstractParameter,AbstractParameters,AbstractParametersVector})
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
function path(parameters::Union{AbstractParameter,AbstractParameters,AbstractParametersVector})::Vector{Symbol}
    if parent(parameters) === nothing
        return Symbol[name(parameters)]
    else
        return Symbol[path(parent(parameters)); name(parameters)]
    end
end

function path(parameters::Vector{<:AbstractParameters})::Vector{Symbol}
    return path(parent(parameters[1]))
end

function spath(p::Vector{Symbol})::String
    integer_pattern = r"^\d+$"
    pstring = ""
    for (k, sym) in enumerate(p)
        str = string(sym)
        if occursin(integer_pattern, str)
            pstring *= "[$str]"
        elseif k == 1
            pstring *= "$str"
        else
            pstring *= ".$str"
        end
    end
    return pstring
end

"""
    spath(parameters::Union{AbstractParameter,AbstractParameters})::String

Returns the location in the parameters hierarchy as a string
"""
function spath(parameters::Union{AbstractParameter,AbstractParameters,AbstractParametersVector})::String
    return spath(path(parameters))
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
        elseif typeof(par) <: AbstractParametersVector
            for p in par
                leaves!(p, res)
            end
        else
            push!(res, par)
        end
    end
end

function Base.ismissing(parameters::AbstractParameters, field::Symbol)::Bool
    return getparameter(parameters, field).value === missing
end

# ==== #
# time #
# ==== #
function global_time(pars::AbstractParameters, time0::Float64)
    return error("`global_time(::$(typeof(pars)))` is not defined")
end

function global_time(par::AbstractParameter, time0::Float64)
    return global_time(parent(par))
end

function global_time(pars::AbstractParameters)
    return error("`global_time(::$(typeof(pars)))` is not defined")
end

function global_time(par::AbstractParameter)
    return global_time(parent(par))
end

function time_range(pars::AbstractParameters)
    return error("`time_range(::$(typeof(pars)))` is not defined")
end

function time_range(par::AbstractParameter)
    return time_range(parent(par))
end
