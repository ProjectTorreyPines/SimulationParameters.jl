# ================= #
# OptParameterRange #
# ================= #
struct OptParameterRange{T} <: OptParameter where {T<:Real}
    nominal::T
    lower::T
    upper::T
    choices::Missing
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

# ==================== #
# OptParameterFunction #
# ==================== #
struct OptParameterFunction{T} <: OptParameter where {T<:Function}
    nominal::T
    lower::T
    upper::T
    choices::Missing
end

"""
    ↔(x::Function, b::Function)

"leftrightarrow" unicode constructor for OptParameterFunction
"""
function ↔(x::Function, b::Function)
    return OptParameterFunction(x, b)
end

function OptParameterFunction(nominal::T, bounds::T) where {T<:Function}
    return OptParameterFunction(nominal, t -> -bounds(t), bounds, missing)
end

# ==================== #

"""
    opt_parameters(parameters::AbstractParameters, optimization_vector::Vector{AbstractParameter}=AbstractParameter[])

Create and return the optimization_vector from parameters
"""
function opt_parameters(parameters::AbstractParameters, optimization_vector::Vector{AbstractParameter}=AbstractParameter[])
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            opt_parameters(parameter, optimization_vector)
        elseif typeof(parameter) <: AbstractParametersVector
            aop = getfield(parameter, :_aop)
            for kk in aop
                opt_parameters(aop[kk], optimization_vector)
            end
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
        elseif typeof(parameter) <: AbstractParametersVector
            for kk in eachindex(getfield(parameter, :_aop))
                _, k = parameters_from_opt!(parameter[kk], optimization_values, k)
            end
        elseif typeof(parameter.opt) <: OptParameter
            value = parameter.opt(optimization_values[k])
            setproperty!(parameter, :value, value)
            k += 1
        end
    end
    return parameters, k
end

# ============ #
# float_bounds #
# ============ #
"""
    float_bounds(parameter::AbstractParameter)

Returns optimization bounds of a parameter (if it has one)
"""
function float_bounds(parameter::AbstractParameter)
    if parameter.opt === missing
        error("$(parameter.name) does not have a optimization range defined")
    end
    return float_bounds(parameter.opt)
end

function float_bounds(opt::OptParameterRange)
    tp = typeof(opt.nominal)
    if tp <: Union{Bool,Integer}
        lower = Int(opt.lower) - 0.5
        upper = Int(opt.upper) + 0.5
    else
        lower = opt.lower
        upper = opt.upper
    end
    return [lower, upper]
end

function float_bounds(opt::OptParameterChoice)
    lower = 0.5
    upper = length(opt.choices) + 0.5
    return [lower, upper]
end

function (opt::OptParameterRange)(x::Float64)
    tp = typeof(opt.nominal)
    lower, upper = float_bounds(opt)
    @assert (lower <= x) && (x <= upper) "OptParameter exceeded bounds"
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
end

function (opt::OptParameterChoice)(x::Float64)
    lower, upper = float_bounds(opt)
    @assert (lower <= x) && (x <= upper) "OptParameter exceeded bounds"
    if x == lower
        index = Int(ceil(x))
    elseif x == upper
        index = Int(floor(x))
    else
        index = Int(round(x))
    end
    return opt.choices[index]
end

# ========= #
# opt2value #
# ========= #
"""
    opt2value(opt::OptParameterRange, tp::Type)

Samples the OptParameterRange for a value
"""
function opt2value(opt::OptParameterRange, tp::Type)
    if tp <: Integer
        lower = Int(opt.lower)
        upper = Int(opt.upper)
        return rand(range(opt.lower; stop=opt.upper))
    else
        lower = opt.lower
        upper = opt.upper
        return lower + rand() * (upper - lower)
    end
end

"""
    opt2value(opt::OptParameterChoice, tp::Type)

Samples the OptParameterChoice for a value
"""
function opt2value(opt::OptParameterChoice, tp::Type)
    index = rand(range(1; stop=length(opt.choices)))
    return opt.choices[index]
end

# ==== #
# rand #
# ==== #
"""
    Base.rand(parameter::AbstractParameter)

Generates a new random sample within the OptParameter distribution
"""
function Base.rand(parameter::AbstractParameter)
    return opt2value(parameter.opt, typeof(parameter.value))
end

"""
    rand!(parameter::AbstractParameter)

Generates a new random sample within the OptParameter distribution and updates the parameter value
"""
function rand!(parameter::AbstractParameter)
    return setfield!(parameter, :value, rand(parameter))
end
