mutable struct Entry{T} <: AbstractParameter
    _name::Symbol
    _parent::WeakRef
    units::String
    description::String
    value::Union{Missing,T}
    base::Union{Missing,T}
    default::Union{Missing,T}
    opt::Union{Missing,OptParameter}
end

"""
    Entry(T::DataType, units::String, description::String; default = missing)

Defines a entry parameter
"""
function Entry{T}(units::String, description::String; default::Union{Missing,T}=missing) where T
    return Entry{T}(:not_set, WeakRef(nothing), units_check(units, description), description, default, default, default, missing)
end

"""
    legacy
"""
function Entry(T::Type, units::String, description::String; default=missing)
    return Entry{T}(units, description; default)
end
