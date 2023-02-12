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
    return Switch{T}(missing, WeakRef(nothing), options, units_check(units, description), description, default, default, default)
end

function Switch(T::Type, options::Vector{<:Pair}, units::String, description::String; default=missing)
    opts = Dict{Any,SwitchOption}()
    for (key, desc) in options
        opts[key] = SwitchOption(key, desc)
    end
    return Switch{T}(missing, WeakRef(nothing), opts, units_check(units, description), description, default, default, default)
end

function Switch(T::Type, options::Vector{<:Union{Symbol,String}}, units::String, description::String; default=missing)
    opts = Dict{eltype(options),SwitchOption}()
    for key in options
        opts[key] = SwitchOption(key, "$key")
    end
    return Switch{T}(missing, WeakRef(nothing), opts, units_check(units, description), description, default, default, default)
end

function Base.setproperty!(p::Switch, field::Symbol, value)
    if typeof(value) <: Pair
        p.options[value.first].value = value.second
        value = value.first
    end
    if (value !== missing) && !(value in keys(p.options))
        throw(BadParameterException([field], value, p.units, collect(keys(p.options))))
    end
    return setfield!(p, :value, value)
end