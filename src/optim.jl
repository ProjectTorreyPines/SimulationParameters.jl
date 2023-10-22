# ================= #
# OptParameterRange #
# ================= #
struct OptParameterRange{T} <: OptParameter where {T<:Real}
    nominal::T
    lower::T
    upper::T
    choices::missing
end

function OptParameterRange(nominal::T, lower::T, upper::T) where {T}
    if nominal < lower
        error("Optimization parameter: nominal value < lower bound")
    elseif nominal > upper
        error("Optimization parameter: nominal value > lower bound")
    end
    return OptParameterRange(nominal, lower, upper, missing)
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameterRange
"""
function ↔(x::Real, r::AbstractVector)
    @assert length(r) == 2
    @assert typeof(x) === typeof(r[1]) === typeof(r[2]) "OptParameterRange `P ↔ [L, U]` must have the same type for `P`, `L`, and `U`"
    return OptParameterRange(x, r[1], r[2])
end

# ================== #
# OptParameterChoice #
# ================== #
struct OptParameterChoice{T} <: OptParameter where {T<:Any}
    nominal::T
    lower::Missing
    upper::Missing
    choices::AbstractVector{T}
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameterChoice
"""
function ↔(x::Any, r::Tuple)
    @assert eltype(collect(r)) === typeof(x) "OptParameterChoice `P ↔ (O1, O2, ...)` must have the same type for `P` and all the choices `Os`"
    return OptParameterChoice(x, collect(r))
end

function OptParameterChoice(nominal::T, choices::AbstractVector{T}) where {T}
    return OptParameterChoice(nominal, missing, missing, choices)
end

end

"""
    opt_parameters(parameters::AbstractParameters, optimization_vector::AbstractParameter{OptParameter}=AbstractParameter{OptParameter}[])

Create and return the optimization_vector from parameters
"""
function opt_parameters(parameters::AbstractParameters, optimization_vector::Vector{<:OptParameter}=OptParameter[])
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
    parameters_from_opt!(parameters::AbstractParameters, optimization_values::AbstractVector)

Set optimization parameters based on the optimization_values
"""
function parameters_from_opt!(parameters::AbstractParameters, optimization_values::AbstractVector)
    parameters_from_opt!(parameters, optimization_values, 1)
    return parameters
end

function parameters_from_opt!(parameters::AbstractParameters, optimization_values::AbstractVector, k::Int)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            _, k = parameters_from_opt!(parameter, optimization_values, k)
        elseif typeof(parameter.opt) <: OptParameter
            value = parameter.opt(optimization_values[k])
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
    if opt.choices === missing
        if tp <: Union{Bool,Integer}
            lower = Int(opt.lower) - 0.5
            upper = Int(opt.upper) + 0.5
        else
            lower = opt.lower
            upper = opt.upper
        end
    else
        lower = 0.5
        upper = length(opt.choices) + 0.5
    end
    return [lower, upper]
end

function (opt::OptParameter)(x::Float64)
    tp = typeof(opt.nominal)
    lower, upper = float_bounds(opt)
    @assert (lower <= x) && (x <= upper) "OptParameter exceeded bounds"
    if opt.choices === missing
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
        return opt.choices[index]
    end
end

function opt2value(opt::OptParameter, tp::Type)
    if opt.choices === missing
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
        index = rand(range(1; stop=length(opt.choices)))
        return opt.choices[index]
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
