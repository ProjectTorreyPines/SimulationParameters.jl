function OptParameter(nominal::Real, lower::Real, upper::Real)
    if nominal < lower
        error("Optimization parameter: nominal value < lower bound")
    elseif nominal > upper
        error("Optimization parameter: nominal value > lower bound")
    end
    return OptParameter(nominal, lower, upper, Vector{typeof(nominal)}())
end

function OptParameter(nominal::T, options::AbstractVector{T}) where T
    return OptParameter(nominal, NaN, NaN, options)
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameter
"""
function ↔(x::Real, r::AbstractVector)
    return OptParameter(x, r[1], r[end])
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameter
"""
function ↔(x::Any, r::Tuple)
    return OptParameter(x, NaN, NaN, collect(r))
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

Set parameters from the optimization_vector in place
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
            setproperty!(parameter, :value, optimization_vector[k])
            k += 1
        end
    end
    return parameters, k
end

function opt2value(opt::OptParameter, tp::Type)
    if isempty(opt.options)
        if tp <: Integer
            lower = Int(opt.lower)
            upper = Int(opt.upper)
            return rand(range(opt.lower, stop=opt.upper))
        else
            lower = opt.lower
            upper = opt.upper
            return lower + rand() * (upper - lower)
        end
    else
        index = rand(range(1, stop=length(opt.options)))
        return opt.options[index]
    end
end