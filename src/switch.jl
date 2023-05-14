struct SwitchOption
    value::Any
    description::String
end

mutable struct Switch{T} <: AbstractParameter
    _name::Symbol
    _parent::WeakRef
    options::AbstractDict{<:Any,SwitchOption}
    units::String
    description::String
    value::Union{Missing,T}
    base::Union{Missing,T}
    default::Union{Missing,T}
    opt::Union{Missing,OptParameter}
end

"""
    Switch(T::Type, options::AbstractDict{Any,SwitchOption}, units::String, description::String; default=missing)

Defines a switch parameter
"""
function Switch{T}(options::AbstractDict{<:Any,SwitchOption}, units::String, description::String; default=missing) where {T}
    if default === missing
        default_value = missing
    elseif default ∈ keys(options)
        default_value = options[default].value
    else
        error("$description\n$(repr(default)) is not a valid option: $(collect(keys(options)))")
    end
    return Switch{T}(:not_set, WeakRef(nothing), options, units_check(units, description), description, default_value, default_value, default_value, missing)
end

function Switch{T}(options::Vector{Pair{Symbol,String}}, units::String, description::String; default=missing) where {T}
    opts = OrderedCollections.OrderedDict{Any,SwitchOption}()
    for (key, desc) in options
        opts[key] = SwitchOption(key, desc)
    end
    return Switch{T}(opts, units_check(units, description), description; default)
end

function Switch{T}(options::Vector{<:Union{Symbol,String}}, units::String, description::String; default=missing) where {T}
    opts = OrderedCollections.OrderedDict{eltype(options),SwitchOption}()
    for key in options
        opts[key] = SwitchOption(key, "$key")
    end
    return Switch{T}(opts, units_check(units, description), description; default)
end

function Base.setproperty!(p::Switch, field::Symbol, switch_value)
    if switch_value === missing
        setfield!(p, :value, missing)
    elseif switch_value in keys(p.options)
        setfield!(p, :value, p.options[switch_value].value)
    else
        throw(BadParameterException([field], switch_value, p.units, collect(keys(p.options))))
    end
end


"""
    legacy
"""
function Switch(T::Type, options::AbstractDict{<:Any,SwitchOption}, units::String, description::String; default=missing)
    Switch{T}(options, units, description; default)
end

function Switch(T::Type, options::Vector{Pair{Symbol,String}}, units::String, description::String; default=missing)
    Switch{T}(options, units, description; default)
end

function Switch(T::Type, options::Vector{<:Union{Symbol,String}}, units::String, description::String; default=missing)
    Switch{T}(options, units, description; default)
end