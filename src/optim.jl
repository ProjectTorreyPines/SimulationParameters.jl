struct OptParameter
    nominal::Real
    lower::Real
    upper::Real
    function OptParameter(nominal, lower, upper)
        if nominal < lower
            error("Optimization parameter: nominal value < lower bound")
        elseif nominal > upper
            error("Optimization parameter: nominal value > lower bound")
        end
        return new(nominal, lower, upper)
    end
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameter
"""
function ↔(x::Real, r::AbstractVector)
    #@assert typeof(x) == typeof(r[1]) == typeof(r[end]) "type of optimization range does not match the nominal value"
    return OptParameter(x, r[1], r[end])
end

"""
    opt_parameters(parameters::AbstractParameters, opt_vector=AbstractParameter[])

Create and return the opt_vector from parameters
"""
function opt_parameters(parameters::AbstractParameters, opt_vector=AbstractParameter[])
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            opt_parameters(parameter, opt_vector)
        elseif typeof(parameter) <: Entry
            if parameter.lower !== missing
                push!(opt_vector, parameter)
            end
        end
    end
    return opt_vector
end

"""
    parameters_from_opt!(parameters::AbstractParameters, opt_vector::AbstractVector)

Set parameters from the opt_vector in place
"""
function parameters_from_opt!(parameters::AbstractParameters, opt_vector::AbstractVector)
    parameters_from_opt!(parameters, opt_vector, 1)
    return parameters
end

function parameters_from_opt!(parameters::AbstractParameters, opt_vector::AbstractVector, k::Int)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            _, k = parameters_from_opt!(parameter, opt_vector, k)
        elseif typeof(parameter) <: Entry
            if parameter.lower !== missing
                setproperty!(parameter, :value, opt_vector[k])
                k += 1
            end
        end
    end
    return parameters, k
end