
mutable struct GroupedParameter{T}
    parameter::AbstractParameter
    values::Vector{T}
end

function grouping_parameters(args::Union{AbstractVector{<:AbstractParameters},AbstractParameters}...)
    converted = Vector{AbstractParameters}()
    for arg in args
        if arg isa AbstractParameters
            push!(converted, arg)
        else
            append!(converted, arg)
        end
    end

    return grouping_parameters(opt_parameters.(converted))
end

function grouping_parameters(inis_and_acts::AbstractArray{<:AbstractArray{<:AbstractParameters}})
    return grouping_parameters(reduce(vcat, inis_and_acts))
end

function grouping_parameters(ini_or_act::AbstractParameters)
    return grouping_parameters(opt_parameters(ini_or_act))
end

function grouping_parameters(multi_pars::Vector{<:Vector{<:AbstractParameter}})
    return grouping_parameters(reduce(vcat, multi_pars))
end

function grouping_parameters(multi_pars::Vector{<:AbstractParameter})
    GPs = GroupedParameter[]

    # Dictionaries to store values and the corresponding parameter for each key
    values_map = Dict{String,Vector{<:Real}}()
    parameter_map = Dict{String,AbstractParameter}()

    # Iterate over each vector of parameters
    for par in multi_pars
        key_name = spath(par)
        if haskey(parameter_map, key_name)
            if !isequal(parameter_map[key_name].opt, par.opt)
                error("Some of $key_name have different opt parameters\n" *
                      "  [1]: $(parameter_map[key_name].opt)\n" *
                      "  [2]: $(par.opt)")
            end
        else
            parameter_map[key_name] = par
        end

        if typeof(par.opt) <: OptParameterChoice
            idx = findfirst(par.opt.choices .== par.value)
            isempty(idx) ? error("$(spath(par)) value $(par.value) not found in $(par.opt.choices)") : nothing
            push!(get!(values_map, key_name, Vector{typeof(idx)}()), idx)
        else
            push!(get!(values_map, key_name, Vector{eltype(par.value)}()), par.value)
        end

    end

    # Build the grouped parameters vector from the dictionaries
    sorted_keys = sort(collect(keys(values_map)))
    for key in sorted_keys
        push!(GPs, GroupedParameter(parameter_map[key], values_map[key]))
    end

    return GPs
end
