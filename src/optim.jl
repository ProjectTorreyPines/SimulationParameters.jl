struct OptParameterRange{T} <: OptParameter where {T<:Real}
    nominal::T
    lower::T
    upper::T
    options::AbstractVector{Missing}
end

struct OptParameterChoice{T} <: OptParameter where {T<:Any}
    nominal::T
    lower::Missing
    upper::Missing
    options::AbstractVector{T}
end


function OptParameterRange(nominal::T, lower::T, upper::T) where {T}
    if nominal < lower
        error("Optimization parameter: nominal value < lower bound")
    elseif nominal > upper
        error("Optimization parameter: nominal value > lower bound")
    end
    return OptParameterRange(nominal, lower, upper, Vector{Missing}())
end

function OptParameterChoice(nominal::T, options::AbstractVector{T}) where {T}
    return OptParameterChoice(nominal, missing, missing, options)
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameter
"""
function ↔(x::Real, r::AbstractVector)
    @assert length(r) == 2
    @assert typeof(x) === typeof(r[1]) === typeof(r[2]) "OptParameter `P ↔ [L, U]` must have the same type for `P`, `L`, and `U`"
    return OptParameterRange(x, r[1], r[2])
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameter
"""
function ↔(x::Any, r::Tuple)
    @assert eltype(collect(r)) === typeof(x) "OptParameter `P ↔ (O1, O2, ...)` must have the same type for `P` and all the `Os`"
    return OptParameterChoice(x, collect(r))
end

"""
    opt_parameters(parameters::AbstractParameters, optimization_vector=AbstractParameter[])

Create and return the optimization_vector from parameters
"""
function opt_parameters(parameters::AbstractParameters, optimization_vector=AbstractParameter[])
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            opt_parameters(parameter, optimization_vector)
        elseif typeof(parameter.opt) <: OptParameter
            push!(optimization_vector, parameter)
        end
    end
    return optimization_vector
end

"""
    parameters_from_opt!(parameters::AbstractParameters, optimization_vector::AbstractVector)

Set optimization parameters based on the optimization_vector in place
"""
function parameters_from_opt!(parameters::AbstractParameters, optimization_vector::AbstractVector)
    parameters_from_opt!(parameters, optimization_vector, 1)
    return parameters
end

function parameters_from_opt!(parameters::AbstractParameters, optimization_vector::AbstractVector, k::Int)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            _, k = parameters_from_opt!(parameter, optimization_vector, k)
        elseif typeof(parameter.opt) <: OptParameter
            value = parameter.opt(optimization_vector[k])
            setproperty!(parameter, :value, value)
            k += 1
        end
    end
    return parameters, k
end

function float_bounds(parameter::AbstractParameter)
    if parameter.opt === missing
        error("$(parameter.name) does not have a optimization range defined")
    end
    return float_bounds(parameter.opt)
end

function float_bounds(opt::OptParameter)
    tp = typeof(opt.nominal)
    if isempty(opt.options)
        if tp <: Union{Bool,Integer}
            lower = Int(opt.lower) - 0.5
            upper = Int(opt.upper) + 0.5
        else
            lower = opt.lower
            upper = opt.upper
        end
    else
        lower = 0.5
        upper = length(opt.options) + 0.5
    end
    return [lower, upper]
end

function (opt::OptParameter)(x::Float64)
    tp = typeof(opt.nominal)
    lower, upper = float_bounds(opt)
    @assert (lower <= x) && (x <= upper) "OptParameter exceeded bounds"
    if isempty(opt.options)
        if tp <: Union{Integer,Bool}
            if x == lower
                return tp(ceil(x))
            elseif x == upper
                return tp(floor(x))
            else
                return tp(round(x))
            end
        else
            return x
        end
    else
        if x == lower
            index = Int(ceil(x))
        elseif x == upper
            index = Int(floor(x))
        else
            index = Int(round(x))
        end
        return opt.options[index]
    end
end

function opt2value(opt::OptParameter, tp::Type)
    if isempty(opt.options)
        if tp <: Integer
            lower = Int(opt.lower)
            upper = Int(opt.upper)
            return rand(range(opt.lower; stop=opt.upper))
        else
            lower = opt.lower
            upper = opt.upper
            return lower + rand() * (upper - lower)
        end
    else
        index = rand(range(1; stop=length(opt.options)))
        return opt.options[index]
    end
end

function Base.rand(parameters::AbstractParameters, field::Symbol)
    parameter = getfield(parameters, field)
    return opt2value(parameter.opt, typeof(parameter.value))
end

function rand!(parameters::AbstractParameters, field::Symbol)
    parameter = getfield(parameters, field)
    return setfield!(parameter, :value, rand(parameters, field))
end
