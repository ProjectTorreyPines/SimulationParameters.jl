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
    return Entry{T}(missing, WeakRef(nothing), units_check(units, description), description, default, default, default, missing, missing)
end