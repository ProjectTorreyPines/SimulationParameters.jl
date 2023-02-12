abstract type AbstractParameter end

function AbstractTrees.children(par::AbstractParameter)
    if typeof(par.value) <: AbstractDict
        return [k => par.value[k] for k in sort(collect(keys(par.value)))]
    else
        return []
    end
end

function AbstractTrees.printnode(io::IO, par::AbstractParameter)
    color = parameter_color(par)
    if typeof(par.value) <: AbstractDict
        printstyled(io, "$(getfield(par,:_name))[:]"; bold=true)
    else
        printstyled(io, getfield(par, :_name))
        printstyled(io, " ➡ ")
        printstyled(io, "$(repr(par.value))"; color=color)
        if length(replace(par.units, "-" => "")) > 0 && par.value !== missing
            printstyled(io, " [$(par.units)]"; color=color)
        end
    end
end

function units_check(units::AbstractString, description::AbstractString)
    if isempty(units)
        @error "Units cannot be an empty string. For unitless parameters use `-`. DESCRIPTION: $description"
    end
    return units
end