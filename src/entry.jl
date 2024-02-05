mutable struct Entry{T} <: AbstractParameter{T}
    _name::Symbol
    _parent::WeakRef
    units::String
    description::String
    value::Union{Missing,Function,T}
    base::Union{Missing,Function,T}
    default::Union{Missing,Function,T}
    opt::Union{Missing,OptParameter}
    check::Union{Nothing,Function}
end

"""
    Entry{T}(units::String, description::String; default::Union{Missing,T}=missing) where T

Defines a entry parameter
"""
function Entry{T}(units::String, description::String; default::Union{Missing,T}=missing, check::Union{Nothing,Function}=nothing) where {T}
    return Entry{T}(:not_set, WeakRef(nothing), units_check(units, description), description, default, default, default, missing, check)
end
