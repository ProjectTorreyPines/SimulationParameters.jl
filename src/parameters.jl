abstract type AbstractParameters end

function setup_parameters(parameters::AbstractParameters)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: Union{AbstractParameter,AbstractParameters}
            setfield!(parameter, :_parent, WeakRef(parameters))
            setfield!(parameter, :_name, field)
        end
        if typeof(parameter) <: AbstractParameters
            setup_parameters(parameter)
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
    self_name = path(parameters)
    if field ∉ keys(parameters)
        throw(InexistentParameterException([self_name; field]))
    end
    parameter = getfield(parameters, field)
    if typeof(parameter) <: AbstractParameters
        return parameter
    else
        if parameter.value === missing
            if typeof(parameter) <: Entry
                throw(NotsetParameterException([self_name; field], parameter.units))
            elseif typeof(parameter) <: Switch
                throw(NotsetParameterException([self_name; field], parameter.units, collect(keys(parameter.options))))
            else
                error("Should not be here")
            end
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
    self_name = path(parameters)
    if field ∉ keys(parameters)
        throw(InexistentParameterException([self_name; field]))
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

function Base.setproperty!(parameters::AbstractParameters, field::Symbol, value::Any)
    if startswith(string(field), "_")
        error("use setfield! for :$field")
    end
    if field ∉ keys(parameters)
        self_name = path(parameters)
        throw(InexistentParameterException([self_name; field]))
    else
        parameter = getfield(parameters, field)
        # handle OptParameter in Entry
        if typeof(parameter) <: Entry
            tp = typeof(parameter).parameters[1]
            if typeof(value) <: OptParameter
                if tp <: Union{Integer,Bool}
                    parameter.lower = value.lower - 0.5
                    parameter.upper = value.upper + 0.5
                else
                    parameter.lower = value.lower
                    parameter.upper = value.upper
                end
                value = value.nominal
            end
            if ~(ismissing(parameter.lower) || ismissing(parameter.lower))
                if tp <: Integer
                    parameter.value = Int(round(value))
                elseif tp <: Bool
                    parameter.value = Bool(round(value))
                else
                    parameter.value = value
                end
            else
                parameter.value = value
            end
        elseif typeof(parameter) <: AbstractParameter
            parameter.value = value
            #setfield!(parameter, :_parent, WeakRef(parameters))
            #setfield!(parameter, :_name, field)
        elseif typeof(parameter) <: AbstractParameters
            setfield!(parameters, field, value)
            #setfield!(parameter, :_parent, WeakRef(parameters))
            #setfield!(parameter, :_name, field)
        else
            error("should not be here")
        end
    end
end

function Base.keys(parameters::Union{AbstractParameter,AbstractParameters})
    return (field for field in fieldnames(typeof(parameters)) if field ∉ [:_parent, :_name])
end

function Base.parent(parameters::Union{AbstractParameter,AbstractParameters})
    return getfield(parameters, :_parent).value
end

function name(parameters::Union{AbstractParameter,AbstractParameters})
    return getfield(parameters, :_name)
end

function path(parameters::Union{AbstractParameter,AbstractParameters})::Vector{Symbol}
    if parent(parameters) === nothing
        return Symbol[name(parameters)]
    else
        return Symbol[path(parent(parameters)); name(parameters)]
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