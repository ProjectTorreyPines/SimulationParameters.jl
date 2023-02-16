struct ParsNodeRepr
    field
    value
end

function AbstractTrees.printnode(io::IO, pars::AbstractParameters)
    printstyled(io, split(string(typeof(pars)), "__")[end]; bold=true)
end

function AbstractTrees.children(pars::AbstractParameters)::Vector{ParsNodeRepr}
    return [ParsNodeRepr(field, getfield(pars, field)) for field in sort(collect(keys(pars)))]
end

function AbstractTrees.children(node_value::ParsNodeRepr)
    value = node_value.value
    if typeof(value) <: AbstractParameters
        return (ParsNodeRepr(field, getfield(value, field)) for field in keys(value))
    else
        return []
    end
end

function AbstractTrees.printnode(io::IO, node_value::ParsNodeRepr)
    field = node_value.field
    par = node_value.value
    if typeof(par) <: AbstractParameters
        printstyled(io, field; bold=true)
    elseif typeof(par) <: AbstractParameter 
        if typeof(par.value) <: AbstractDict
            printstyled(io, "$field[:]"; bold=true)
        else
            color = parameter_color(par)
            printstyled(io, field)
            printstyled(io, " ➡ ")
            printstyled(io, "$(repr(par.value))"; color=color)
            if length(replace(par.units, "-" => "")) > 0 && par.value !== missing
                printstyled(io, " [$(par.units)]"; color=color)
            end
        end
    elseif par isa AbstractParametersSet
    else
        error(field)
    end
end

function Base.show(io::IO, ::MIME"text/plain", pars::AbstractParameters, depth::Int=0)
    return AbstractTrees.print_tree(io, pars)
end

function parameter_color(p::AbstractParameter)::Symbol
    value = p.value
    if value === missing
        color = :yellow
    elseif typeof(value) == typeof(p.default) && value == p.default
        color = :green
    elseif typeof(value) == typeof(p.base) && value == p.base
        color = :blue
    else
        color = :red
    end
end

function Base.show(io::IO, p::AbstractParameter)
    color = parameter_color(p)
    printstyled(io, join(path(p), "."); bold=true, color=color)
    for item in fieldnames(typeof(p))
        if startswith(string(item), "_")
            continue
        end
        printstyled(io, "\n- $item: "; bold=true)
        printstyled(io, "$(getfield(p, item))")
    end
end
