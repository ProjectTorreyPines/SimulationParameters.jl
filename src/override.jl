mutable struct OverrideParameters{T<:Real,D<:AbstractParameters{T}} <: AbstractParameters{T}
    _parent::WeakRef
    _name::Symbol
    _original::D
    _override::D
    _overwritten::Vector{Symbol}
end

"""
    OverrideParameters(original::AbstractParameters; kw...)

OverrideParameters masks the input AbstractParameters parameter such that any subsequent edit to the parameters does not affect the original.
This is useful to allow local changes to parameters without affecting the original.
It is much more efficient than doing a deepcopy of the original.
"""
function OverrideParameters(original::AbstractParameters; kw...)
    _parent = getfield(original, :_parent)
    _name = getfield(original, :_name)
    override = typeof(original)()
    setfield!(override, :_name, _name)
    setfield!(override, :_parent, _parent)
    opar = OverrideParameters(_parent, _name, original, override, Symbol[])
    if !isempty(kw)
        for (key, value) in kw
            setproperty!(opar, key, value)
        end
    end
    return opar
end

function OverrideParameters(opar::OverrideParameters; kw...)
    error("Cannot OverrideParameters of an OverrideParameters: $(spath(opar))")
end

function getparameter(opar::OverrideParameters, field::Symbol)
    overwritten = getfield(opar, :_overwritten)
    if field ∈ overwritten
        override = getfield(opar, :_override)
        return getfield(override, field)
    else
        original = getfield(opar, :_original)
        return getfield(original, field)
    end
end

function Base.keys(opar::OverrideParameters)
    override = getfield(opar, :_override)
    return keys(override)
end

function Base.setproperty!(opar::OverrideParameters, field::Symbol, value)
    override = getfield(opar, :_override)
    overwritten = getfield(opar, :_overwritten)
    if field ∉ overwritten
        push!(overwritten, field)
    end
    setproperty!(override, field, value)
    return value
end

function Base.getproperty(opar::OverrideParameters, field::Symbol)
    overwritten = getfield(opar, :_overwritten)
    if field ∈ overwritten
        override = getfield(opar, :_override)
        return getproperty(override, field)
    else
        original = getfield(opar, :_original)
        return getproperty(original, field)
    end
end

function global_time(opar::OverrideParameters)
    return global_time(getfield(opar, :_original))
end

function global_time(opar::OverrideParameters, time0::Float64)
    return global_time(getfield(opar, :_original), time0)
end

function time_range(opar::OverrideParameters)
    return time_range(getfield(opar, :_original))
end
