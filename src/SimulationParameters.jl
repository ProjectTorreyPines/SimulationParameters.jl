module SimulationParameters

import AbstractTrees

#= ================= =#
#  AbstractParameter  #
#= ================= =#
abstract type AbstractParameter end

function AbstractTrees.children(par::AbstractParameter)
    if typeof(par.value) <: AbstractDict
        return [k => par.value[k] for k in sort(collect(keys(par.value)))]
    else
        return []
    end
end

function AbstractTrees.printnode(io::IO, par::AbstractParameter)
    color = parameter_color(par)
    if typeof(par.value) <: AbstractDict
        printstyled(io, "$(getfield(par,:_name))[:]"; bold=true)
    else
        printstyled(io, getfield(par, :_name))
        printstyled(io, " ➡ ")
        printstyled(io, "$(repr(par.value))"; color=color)
        if length(replace(par.units, "-" => "")) > 0 && par.value !== missing
            printstyled(io, " [$(par.units)]"; color=color)
        end
    end
end


#= ===== =#
#  Entry  #
#= ===== =#
mutable struct Entry{T} <: AbstractParameter
    _name::Union{Missing,Symbol}
    _parent::WeakRef
    units::String
    description::String
    value::Union{Missing,T}
    base::Union{Missing,T}
    default::Union{Missing,T}
    lower::Union{Missing,Float64}
    upper::Union{Missing,Float64}
end

"""
    Entry(T::DataType, units::String, description::String; default = missing)

Defines a entry parameter
"""
function Entry(T::Type, units::String, description::String; default=missing)
    return Entry{T}(missing, WeakRef(missing), units, description, default, default, default, missing, missing)
end

# function Entry(T::Type, ids::Type, field::Symbol; default=missing)
#     txt = IMAS.info(ids, field)
#     return Entry(T, get(txt, "units", ""), get(txt, "documentation", ""); default)
# end

function value(parameter::Entry{T}, path::Vector{Symbol})::T where {T}
    value = parameter.value
    if value === missing
        throw(NotsetParameterException(path))
    else
        return value::T
    end
end

#= ====== =#
#  Switch  #
#= ====== =#
struct SwitchOption
    value::Any
    description::String
end

mutable struct Switch{T} <: AbstractParameter
    _name::Union{Missing,Symbol}
    _parent::WeakRef
    options::Dict{Any,SwitchOption}
    units::String
    description::String
    value::Union{Missing,T}
    base::Union{Missing,T}
    default::Union{Missing,T}
end

"""
    Switch(T::Type, options::Dict{Any,SwitchOption}, units::String, description::String; default=missing)

Defines a switch parameter
"""
function Switch(T::Type, options::Dict{Any,SwitchOption}, units::String, description::String; default=missing)
    if !in(default, keys(options))
        error("$(repr(default)) is not a valid option: $(collect(keys(options)))")
    end
    return Switch{T}(missing, WeakRef(missing), options, units, description, default, default, default)
end

function Switch(T::Type, options::Vector{<:Pair}, units::String, description::String; default=missing)
    opts = Dict{Any,SwitchOption}()
    for (key, desc) in options
        opts[key] = SwitchOption(key, desc)
    end
    return Switch{T}(missing, WeakRef(missing), opts, units, description, default, default, default)
end

function Switch(T::Type, options::Vector{<:Union{Symbol,String}}, units::String, description::String; default=missing)
    opts = Dict{eltype(options),SwitchOption}()
    for key in options
        opts[key] = SwitchOption(key, "$key")
    end
    return Switch{T}(missing, WeakRef(missing), opts, units, description, default, default, default)
end

# function Switch(T::Type, options, ids::Type{<:IMAS.IDS}, field::Symbol; default=missing)
#     location = "$(IMAS.fs2u(ids)).$(field)"
#     txt = IMAS.info(location)
#     return Switch(T, options, get(txt, "units", ""), get(txt, "documentation", ""); default)
# end

function Base.setproperty!(p::Switch, key::Symbol, value)
    if typeof(value) <: Pair
        p.options[value.first].value = value.second
        value = value.first
    end
    if (value !== missing) && !(value in keys(p.options))
        throw(BadParameterException([key], value, collect(keys(p.options))))
    end
    return setfield!(p, :value, value)
end

function parameter_color(p::AbstractParameter)
    value = p.value
    if value === missing
        color = :yellow
    elseif typeof(value) == typeof(p.default) && value == p.default
        color = :green
    elseif typeof(value) == typeof(p.base) && value == p.base
        color = :blue
    else
        color = :red
    end
end

function Base.show(io::IO, p::AbstractParameter)
    color = parameter_color(p)
    printstyled(io, join(path(p), "."); bold=true, color=color)
    for item in fieldnames(typeof(p))
        if startswith(string(item), "_")
            continue
        end
        printstyled(io, "\n- $item: "; bold=true)
        printstyled(io, "$(getfield(p, item))")
    end
end

function value(parameter::Switch{T}, path::Vector{Symbol})::T where {T}
    if parameter.value === missing
        throw(NotsetParameterException(path, collect(keys(parameter.options))))
    end
    value = parameter.options[parameter.value].value
    if value === missing
        throw(NotsetParameterException(path))
    else
        return value::T
    end
end

#======================#
#= AbstractParameters =#
#======================#
abstract type AbstractParameters end

abstract type ParametersActor <: AbstractParameters end # container for all parameters of an actor
abstract type ParametersAllActors <: AbstractParameters end # --> abstract type of ParametersActors, container for all parameters of all actors

abstract type ParametersInit <: AbstractParameters end # container for all parameters of a init
abstract type ParametersAllInits <: AbstractParameters end # --> abstract type of ParametersInits, container for all parameters of all inits


function Base.getproperty(parameters::AbstractParameters, field::Symbol)
    self_name = Symbol(split(string(typeof(parameters).name.name),"__")[end])
    if field ∉ fieldnames(typeof(parameters))
        throw(InexistentParameterException([self_name, field]))
    end
    x = getfield(parameters, field)
    if typeof(x) <: AbstractParameters
        return x
    else
        if x.value === missing
            throw(NotsetParameterException([self_name, field]))
        else
            tp = typeof(x).parameters[1]
            return x.value::tp
        end
    end
end

"""
Return value of `key` parameter or `default` if parameter is missing
NOTE: This is useful because accessing a `missing` parameter would raise an error
"""
function Base.getproperty(parameters::AbstractParameters, field::Symbol, default)
    value = getfield(parameters, field)
    if value === missing
        return default
    else
        return getproperty(parameters, field)
    end
end

function Base.setproperty!(parameters::AbstractParameters, field::Symbol, value::Any)
    if field ∉ fieldnames(typeof(parameters))
        self_name = Symbol(split(string(typeof(parameters).name.name),"__")[end])
        throw(FUSE.InexistentParameterException([self_name, field]))
    else
        x = getfield(parameters, field)
        x.value = value
    end
end

function value(parameter::T, path::Vector{Symbol})::T where {T<:AbstractParameters}
    return parameter::T
end

function AbstractTrees.printnode(io::IO, pars::AbstractParameters)
    printstyled(io, split(string(typeof(pars)),"__")[end]; bold=true)
end

struct FUSEnodeRepr
    field
    value
end

function AbstractTrees.children(pars::AbstractParameters)
    return [FUSEnodeRepr(field, getfield(pars, field)) for field in sort(collect(fieldnames(typeof(pars))))]
end

function AbstractTrees.children(node_value::FUSEnodeRepr)
    value = node_value.value
    if typeof(value) <: AbstractParameters
        return [FUSEnodeRepr(field, getfield(value, field)) for field in fieldnames(typeof(value))]
    else
        return []
    end
end

function AbstractTrees.printnode(io::IO, node_value::FUSEnodeRepr)
    field = node_value.field
    par = node_value.value
    if typeof(par) <: AbstractParameters
        printstyled(io, field; bold=true)
    elseif typeof(par) <: AbstractParameter
        if typeof(par.value) <: AbstractDict
            printstyled(io, "$field[:]"; bold=true)
        else
            color = parameter_color(par)
            printstyled(io, field)
            printstyled(io, " ➡ ")
            printstyled(io, "$(repr(par.value))"; color=color)
            if length(replace(par.units, "-" => "")) > 0 && par.value !== missing
                printstyled(io, " [$(par.units)]"; color=color)
            end
        end
    else
        error(field)
    end
end

function Base.show(io::IO, ::MIME"text/plain", pars::AbstractParameters, depth::Int=0)
    return AbstractTrees.print_tree(io, pars)
end

function set_new_base!(parameters::AbstractParameters)
    for field in fieldnames(typeof(parameters))
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            set_new_base!(parameter)
        else
            setfield!(parameter, :base, parameter.value)
        end
    end
    return p
end

function Base.ismissing(parameters::AbstractParameters, field::Symbol)::Bool
    return getfield(parameters, field).value === missing
end

"""
    (par::AbstractParameters)(kw...)

This functor is used to override the parameters at function call
"""
function (par::AbstractParameters)(kw...)
    par = deepcopy(par)
    if !isempty(kw)
        for (key, value) in kw
            setproperty!(par, key, value)
        end
    end
    return par
end

"""
    diff(p1::AbstractParameters, p2::AbstractParameters)

Look for differences between two `ini` or `act` sets of parameters
"""
function Base.diff(p1::AbstractParameters, p2::AbstractParameters)
    k1 = fieldnames(typeof(p1))
    k2 = fieldnames(typeof(p2))
    commonkeys = intersect(Set(k1), Set(k2))
    if length(commonkeys) != length(k1)
        error("p1 has more keys")
    elseif length(commonkeys) != length(k2)
        error("p2 has more keys")
    end
    for key in commonkeys
        v1 = getfield(p1, key)
        v2 = getfield(p2, key)
        if typeof(v1) !== typeof(v2)
            error("$key is of different type")
        elseif typeof(v1) <: AbstractParameters
            diff(v1, v2)
        elseif typeof(v1.value) === typeof(v2.value) === Missing
            continue
        elseif v1.value != v2.value
            error("$key had different value:\n$v1\n\n$v2")
        end
    end
end

"""
    par2dict(par::AbstractParameters)

Convert FUSE parameters to dictionary
"""
function par2dict(par::AbstractParameters)
    ret = Dict()
    return par2dict!(par, ret)
end

function par2dict!(par::AbstractParameters, ret::AbstractDict)
    for item in fieldnames(typeof(par))
        value = getfield(par, item)
        if typeof(value) <: AbstractParameters
            ret[item] = Dict()
            par2dict!(value, ret[item])
        elseif typeof(value) <: AbstractParameter
            ret[item] = Dict()
            for field in fieldnames(typeof(value))
                if startswith(string(field), "_")
                    continue
                end
                ret[item][field] = getfield(value, field)
            end
        end
    end
    return ret
end

function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    open(filename, "w") do io
        JSON.print(io, par2dict(par), 1; kw...)
    end
end

function dict2par!(dct::AbstractDict, par::AbstractParameters)
    for (key, val) in par
        if key ∈ keys(dct)
            # this is if dct was par2dict function
            dkey = key
            dvalue = :value
        else
            # this is if dct was generated from json
            dkey = string(key)
            dvalue = "value"
        end
        if typeof(val) <: AbstractParameters
            dict2par!(dct[dkey], val)
        elseif dct[dkey][dvalue] === nothing
            setproperty!(par, key, missing)
        elseif typeof(dct[dkey][dvalue]) <: AbstractVector # this could be done more generally
            setproperty!(par, key, Real[k for k in dct[dkey][dvalue]])
        else
            try
                setproperty!(par, key, Symbol(dct[dkey][dvalue]))
            catch e
                try
                    setproperty!(par, key, dct[dkey][dvalue])
                catch e
                    display((key, e))
                end
            end
        end
    end
    return par
end

function json2par(filename::AbstractString, par_data::AbstractParameters)
    json_data = JSON.parsefile(filename, dicttype=DataStructures.OrderedDict)
    return dict2par!(json_data, par_data)
end

#= ================= =#
#  Parameters errors  #
#= ================= =#
struct InexistentParameterException <: Exception
    path::Vector{Symbol}
end
Base.showerror(io::IO, e::InexistentParameterException) = print(io, "$(join(e.path,".")) does not exist")

struct NotsetParameterException <: Exception
    path::Vector{Symbol}
    options::Vector{Any}
end
NotsetParameterException(path::Vector{Symbol}) = NotsetParameterException(path, [])
function Base.showerror(io::IO, e::NotsetParameterException)
    if length(e.options) > 0
        print(io, "Parameter $(join(e.path,".")) is not set. Valid options are: $(join(map(repr,e.options),", "))")
    else
        print(io, "Parameter $(join(e.path,".")) is not set")
    end
end

struct BadParameterException <: Exception
    path::Vector{Symbol}
    value::Any
    options::Vector{Any}
end
Base.showerror(io::IO, e::BadParameterException) =
    print(io, "Parameter $(join(e.path,".")) = $(repr(e.value)) is not one of the valid options: $(join(map(repr,e.options),", "))")




end # module SimulationParameters
