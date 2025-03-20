struct ParsNodeRepr
    field
    value
end

############
# children #
############
function AbstractTrees.children(pars::AbstractParameters)
    return (ParsNodeRepr(field, getfield(pars, field)) for field in keys(pars))
end

function AbstractTrees.children(pars::AbstractParametersVector)
    return (ParsNodeRepr(k, pars[k]) for k in eachindex(pars))
end

function AbstractTrees.children(node_value::ParsNodeRepr)
    value = node_value.value
    if typeof(value) <: AbstractParametersVector
        return (ParsNodeRepr(k, value[k]) for k in eachindex(value))
    elseif typeof(value) <: AbstractParameters
        return (ParsNodeRepr(field, getfield(value, field)) for field in keys(value))
    else
        return []
    end
end

#############
# printnode #
#############
function AbstractTrees.printnode(io::IO, pars::AbstractParameters)
    name = split(split(string(typeof(pars)), "__")[end], "{")[1]
    return printstyled(io, name; bold=true)
end

function AbstractTrees.printnode(io::IO, pars::AbstractParametersVector)
    name = path(pars)[end]
    return printstyled(io, name; bold=true)
end

function AbstractTrees.printnode(io::IO, node_value::ParsNodeRepr)
    field = node_value.field
    par = node_value.value
    wrap_length = 120
    if typeof(par) <: AbstractParameters
        printstyled(io, field; bold=true)
    elseif typeof(par) <: AbstractParametersVector
        printstyled(io, field; bold=true)
    elseif typeof(par) <: AbstractParameter
        color = parameter_color(par)
        printstyled(io, "$(field)"; bold=true)
        M = length("$(field)")
        printstyled(io, "{$(split(string(typeof(par).parameters[1]),".")[end])}")
        M += length("{$(split(string(typeof(par).parameters[1]),".")[end])}")
        printstyled(io, " ➡ ")
        M += 3
        if typeof(par.value) <: TimeData
            printstyled(io, "TimeData{$(eltype(par.value.data))}[$(length(par.value.data))]"; color=color)
        elseif typeof(par.value) <: AbstractDict
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
            printstyled(
                io,
                word_wrap("$(replace(par.description,"\n" => " ")) $([k for k in keys(par.options)])", wrap_length; i=wrap_length - M);
                color=:light_white,
                underline=false
            )
        end
    else
        error("Error representing `$field` of type `$(typeof(par))`")
    end
end

########
# show #
########
function Base.show(io::IO, ::MIME"text/plain", pars::AbstractParameters, depth::Int=0)
    return AbstractTrees.print_tree(io, pars)
end

function Base.show(io::IO, ::MIME"text/plain", pars::AbstractParametersVector, depth::Int=0)
    return AbstractTrees.print_tree(io, pars)
end

function Base.show(io::IO, pars::AbstractParameters, depth::Int=0)
    return spath(pars)
end

function Base.show(io::IO, p::AbstractParameter)
    color = parameter_color(p)
    printstyled(io, spath(p); bold=true, color=color)
    printstyled(io, "\n- type: "; bold=true)
    printstyled(io, "$(typeof(p).parameters[1])")
    for item in fieldnames(typeof(p))
        if startswith(string(item), "_")
            continue
        end
        printstyled(io, "\n- $item: "; bold=true)
        printstyled(io, "$(getfield(p, item))")
    end
end

function Base.show(io::IO, ::MIME"text/plain", GP::GroupedParameter)
    p = GP.parameter
    color = parameter_color(p)
    printstyled(io, spath(p); bold=true, color=color)
    printstyled(io, "\n  ↳ N_samples: "; bold=true)
    printstyled(io, "$(length(GP.values))"; bold=true, color=:green)
    printstyled(io, "\n  ↳ type: "; bold=true)
    printstyled(io, "$(typeof(p).parameters[1])")

    for item in [:description, :opt]
        if startswith(string(item), "_")
            continue
        end
        printstyled(io, "\n  ↳ $item: "; bold=true)
        printstyled(io, "$(getfield(p, item))")
    end
end

function Base.show(io::IO, ::MIME"text/plain", GPs::AbstractArray{GroupedParameter})
    printstyled(io, "GroupedParameters"; bold=true)
    for (k, GP) in pairs(GPs)
        color = parameter_color(GP.parameter)
        printstyled(io, "\n[$k] "; bold=true, color=color)
        show(io, MIME"text/plain"(), GP)
    end
end

#########
# utils #
#########

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

function show_modified(pars::AbstractParameters)
    return show_modified(stdout, pars)
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
            println(io, "$(spath(field)) = $(repr(field.value))")
        end
    end
    if printed
        println(io, "")
    end
end

function parameters_details_dict(pars::SimulationParameters.AbstractParameters)
    data = OrderedCollections.OrderedDict{String,Any}()
    for leafRepr in AbstractTrees.Leaves(pars)
        leaf = leafRepr.value
        if typeof(leaf) <: SimulationParameters.ParametersVector
            continue
        end
        if typeof(leaf) <: SimulationParameters.AbstractParameters
            continue
        end
        data[spath(leaf)] = info = Dict()
        info["value"] = repr(leaf.value)
        info["description"] = leaf.description
        info["type"] = replace(string(typeof(leaf)), "SimulationParameters." => "")
        info["units"] = "$(isempty(leaf.units) ? "-" : leaf.units)"
        if typeof(leaf) <: Switch
            info["options"] = leaf.options
        end
    end
    return data
end
