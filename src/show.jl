struct ParsNodeRepr
    field
    value
end

function AbstractTrees.printnode(io::IO, pars::AbstractParameters)
    printstyled(io, split(string(typeof(pars)), "__")[end]; bold=true)
end

function AbstractTrees.children(pars::AbstractParameters)::Vector{ParsNodeRepr}
    return [ParsNodeRepr(field, getfield(pars, field)) for field in collect(keys(pars))]
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
    wrap_length = 120
    if typeof(par) <: AbstractParameters
        printstyled(io, field; bold=true)
    elseif typeof(par) <: AbstractParameter
        color = parameter_color(par)
        printstyled(io, "$(field)")
        M = length("$(field)")
        printstyled(io, " ➡ ")
        M += 3
        if typeof(par.value) <: AbstractDict
            tmp = "$(typeof(par.value))("
            for (k, v) in par.value
                tmp *= "\n$(' '^M)$(repr(k)) => $(repr(v))"
            end
            tmp *= ")"
            printstyled(io, tmp; color=color)
            M = length(split(tmp, "\n")[end])
        else
            printstyled(io, "$(repr(par.value))"; color=color)
            M += length("$(repr(par.value))")
        end
        if length(replace(par.units, "-" => "")) > 0 && par.value !== missing
            printstyled(io, " [$(par.units)]"; color=color, bold=true)
            M += length(" [$(par.units)]")
        end
        if M > wrap_length - 10
            print(io, "\n")
            M = 0
        else
            print(io, " ")
            M += 1
        end
        if typeof(par) <: Entry
            printstyled(io, word_wrap(replace(par.description, "\n" => " "), wrap_length; i=wrap_length - M); color=:light_white, underline=false)
        elseif typeof(par) <: Switch
            printstyled(io, word_wrap("$(replace(par.description,"\n" => " ")) $([k for k in keys(par.options)])", wrap_length; i=wrap_length - M); color=:light_white, underline=false)
        end
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

function show_modified(pars::AbstractParameters)
    show_modified(stdout, pars)
end

function show_modified(io::IO, pars::AbstractParameters)
    printed = false
    for field in values(pars)
        if typeof(field) <: AbstractParameters
            show_modified(field)
        elseif field.value === field.default
            continue
        elseif field.value !== field.default || (field.value == field.default) != true
            printed = true
            println(io, "$(join(path(field), ".")) = $(repr(field.value))")
        end
    end
    if printed
        println(io, "")
    end
end