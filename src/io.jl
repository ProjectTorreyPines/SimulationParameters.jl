function par2ystr(par::AbstractParameters; show_info::Bool=true, skip_defaults::Bool=false)
    tmp = par2ystr(par, String[]; show_info, skip_defaults)
    return join(tmp[2:end], "\n")
end

function par2ystr(par::AbstractParametersVector, txt::Vector{String}; show_info::Bool=true, skip_defaults::Bool=false)
    for (k, parameter) in enumerate(par)
        par2ystr(parameter, txt; is_part_of_array=true, show_info, skip_defaults)
    end
end

function equals_with_missing(a, b)
    if ismissing(a) && ismissing(b)
        return true
    elseif ismissing(a) || ismissing(b)
        return false
    else
        return a == b
    end
end

function YAML._print(io::IO, value::Missing, level::Int=0, ignore_level::Bool=false)
    return println(io, "~")
end

function YAML._print(io::IO, value::Symbol, level::Int=0, ignore_level::Bool=false)
    return println(io, ":$value")
end

function YAML._print(io::IO, value::AbstractRange, level::Int=0, ignore_level::Bool=false)
    return println(io, "$(Float64(value.offset)):$(Float64(value.step)):$(Float64(value.offset+value.len))")
end

function YAML._print(io::IO, value::Enum, level::Int=0, ignore_level::Bool=false)
    str_enum = string(value)
    if match(r"^_.*_$", str_enum) !== nothing
        println(io, ":$(str_enum[2:end-1])")
    else
        println(io, str_enum)
    end
end

function par2ystr(par::AbstractParameters, txt::Vector{String}; is_part_of_array::Bool=false, show_info::Bool=true, skip_defaults::Bool=false)
    for field in keys(par)
        try
            parameter = getfield(par, field)
            p = path(parameter)
            sp = spath(p)
            depth = (count(".", sp) + count("[", sp) - 1) * 2
            if is_part_of_array
                pre = string(" "^(depth - 2), "- ")
                is_part_of_array = false
            else
                pre = " "^depth
            end
            if typeof(parameter) <: AbstractParameters
                if skip_defaults && all(
                    !(typeof(leaf) <: ParsNodeRepr) || !(typeof(leaf.value) <: AbstractParameter) || equals_with_missing(getfield(leaf.value, :value), getfield(leaf.value, :default))
                    for leaf in AbstractTrees.Leaves(parameter)
                )
                    continue
                else
                    push!(txt, "")
                    push!(txt, string(pre, p[end], ":"))
                    par2ystr(parameter, txt; show_info, skip_defaults)
                end

            elseif typeof(parameter) <: AbstractParametersVector
                if isempty(parameter)
                    continue
                end
                if length(p) == 2
                    push!(txt, "")
                end
                push!(txt, string(pre, p[end], ":"))
                par2ystr(parameter, txt; show_info, skip_defaults)

            elseif typeof(parameter) <: AbstractParameter
                default = getfield(parameter, :default)
                value = getfield(parameter, :value)
                if value === default && skip_defaults
                    continue
                end
                tp = typeof(parameter).parameters[1]
                units = getfield(parameter, :units)
                if units == "-" || !show_info
                    units = ""
                else
                    units = "[$units]"
                end
                if show_info
                    description = getfield(parameter, :description)
                    if typeof(parameter) <: Switch
                        description = description * " $([k for k in keys(parameter.options)])"
                    end
                    description = replace(description, "\n" => "\\n")
                else
                    description = ""
                end
                if typeof(value) <: Function
                    # NOTE: For now parameters saved to JSON/YAML are not time dependent
                    time = global_time(par)
                    value = value(time)::tp
                end

                extra_info = strip("$units $description")
                if !isempty(extra_info)
                    extra_info = " # $(extra_info)"
                end

                vrepr = rstrip(YAML.write(value), '\n')

                if contains(vrepr, "\n") || (startswith(vrepr, "- ") && typeof(value) <: AbstractArray && length(value) == 1)
                    push!(txt, string(pre, p[end], ": ", extra_info))
                    for linerep in split(vrepr, "\n")
                        push!(txt, string(pre, linerep))
                    end
                else
                    push!(txt, string(pre, p[end], ": ", vrepr, extra_info))
                end
            else
                error("par2ystr should not be here")
            end
        catch e
            println("* $(spath(getfield(par, field)))")
            rethrow(e)
        end
    end
    return txt
end

"""
    par2yaml(@nospecialize(par::AbstractParameters), filename::String; kw...)

Save AbstractParameters to YAML

NOTE: kw arguments are passed to YAML.print
"""
function par2yaml(@nospecialize(par::AbstractParameters), filename::String; kw...)
    yaml_string = par2ystr(par; kw...)
    open(filename, "w") do io
        return write(io, yaml_string)
    end
    return yaml_string
end

function Base.string(@nospecialize(par::AbstractParameters); show_info=false, skip_defaults=true)
    return par2ystr(par; show_info, skip_defaults)
end

"""
    ystr2par(yaml_string::String, par_data::AbstractParameters)

Loads AbstractParameters from YAML string
"""
function ystr2par(yaml_string::String, par_data::AbstractParameters)
    if isempty(yaml_string)
        return par_data
    end

    # replace missing with null
    missing_null = line -> replace(line, r"\bmissing\b" => "null")
    yaml_string = join((missing_null(line) for line in split(yaml_string, "\n")), "\n")

    # now parse
    data = YAML.load(yaml_string; dicttype=OrderedCollections.OrderedDict)
    data = replace_colon_strings_to_symbols(data)
    dict2par!(data, par_data)
    setup_parameters!(par_data)
    return par_data
end

"""
    yaml2par(filename::AbstractString, par_data::AbstractParameters)

Loads AbstractParameters from YAML
"""
function yaml2par(filename::AbstractString, par_data::AbstractParameters)
    open(filename, "r") do io
        return ystr2par(read(io, String), par_data)
    end
end

"""
    par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)

Save AbstractParameters to JSON

NOTE: kw arguments are passed to JSON.print
"""
function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    json_string = par2jstr(par; kw...)
    open(filename, "w") do io
        return write(io, json_string)
    end
    return json_string
end

"""
    json2par(filename::AbstractString, par_data::AbstractParameters)

Loads AbstractParameters from JSON
"""
function json2par(filename::AbstractString, par_data::AbstractParameters)
    open(filename, "r") do io
        return jstr2par(read(io, String), par_data)
    end
end

"""
    jstr2par(json_string::String, par_data::AbstractParameters)

Loads AbstractParameters from JSON string
"""
function jstr2par(json_string::String, par_data::AbstractParameters)
    data = JSON.parse(json_string; dicttype=OrderedCollections.OrderedDict)
    data = replace_colon_strings_to_symbols(data)
    dict2par!(data, par_data)
    setup_parameters!(par_data)
    return par_data
end

"""
    par2jstr(@nospecialize(par::AbstractParameters); indent::Int=1, kw...)

Returns JSON serialization of AbstractParameters
"""
function par2jstr(@nospecialize(par::AbstractParameters); indent::Int=1, kw...)
    data = par2dict(par)
    data = replace_symbols_to_colon_strings(data)
    return JSON.json(data, indent; kw...)
end

"""
    par2dict(par::AbstractParameters)

Convert AbstractParameters to dictionary
"""
function par2dict(par::AbstractParameters)
    dct = OrderedCollections.OrderedDict()
    return par2dict!(par, dct)
end

"""
    par2dict!(par::AbstractParameters, dct::AbstractDict)

Convert AbstractParameters to dictionary
"""
function par2dict!(par::AbstractParameters, dct::AbstractDict)
    for field in keys(par)
        parameter = getfield(par, field)
        if typeof(parameter) <: AbstractParameters
            dct[field] = OrderedCollections.OrderedDict()
            par2dict!(parameter, dct[field])
        elseif typeof(parameter) <: AbstractParametersVector
            dct[field] = []
            par2dict!(parameter, dct[field])
        elseif typeof(parameter) <: AbstractParameter
            tp = typeof(parameter).parameters[1]
            value = getfield(parameter, :value)
            if value === missing
                # dct[field] = missing
                # pass
            elseif typeof(value) <: Function
                # NOTE: For now parameters are saved to JSON not time dependent
                time = global_time(par)
                dct[field] = value(time)::tp
            elseif tp <: Enum
                str_enum = string(value)
                dct[field] = ":$(str_enum[2:end-1])"
            elseif tp <: AbstractRange
                str_enum = string(value)
                dct[field] = "$(Float64(value.offset)):$(Float64(value.step)):$(Float64(value.offset+value.len))"
            elseif tp <: Symbol
                dct[field] = ":$value"
            elseif tp <: Measurement
                dct[field] = "$value"
            else
                dct[field] = value
            end
        else
            error("par2dict! should not be here")
        end
    end
    return dct
end

function par2dict!(par::AbstractParametersVector, vec::AbstractVector)
    for parameter in par
        push!(vec, par2dict!(parameter, OrderedCollections.OrderedDict()))
    end
end

"""
    dict2par!(dct::AbstractDict, par::AbstractParameters)

Convert dictionary to AbstractParameters
"""
function dict2par!(dct::AbstractDict, par::AbstractParameters)
    for field in keys(par)
        parameter = getfield(par, field)
        if field ∉ keys(dct)
            # this can happen when par is newer than dct
            continue
        end
        if dct[field] === nothing
            continue
        elseif typeof(parameter) <: AbstractParameters
            dict2par!(dct[field], parameter)
        elseif typeof(parameter) <: AbstractParametersVector
            dict2par!(dct[field], parameter)
        else
            tp = typeof(parameter).parameters[1]
            value = replace_colon_strings_to_symbols(dct[field])
            if tp <: Enum
                if typeof(value) <: Int
                    value = Symbol(string(tp(value))[2:end-1])
                end
                setproperty!(par, field, value)
            else
                if value === nothing
                    value = missing
                elseif tp <: Measurement
                    if typeof(value) <: AbstractString
                        v, e = split(value, "±")
                        value = parse(Float64, v) ± parse(Float64, e)
                    end
                elseif tp <: AbstractRange || (tp <: AbstractVector && typeof(value) <: String && contains(value, ":"))
                    if typeof(value) <: AbstractString
                        parts = split(value, ":")
                        start = parse(Float64, parts[1])
                        step = parse(Float64, parts[2])
                        stop = parse(Float64, parts[3])
                    else
                        start = value[1]
                        step = length(value)
                        stop = value[end]
                    end
                    value = start:step:stop
                elseif typeof(value) <: AbstractVector
                    if !isempty(value)
                        value = eltype(tp).(value)
                    else
                        value = Vector{eltype(tp)}()
                    end
                elseif tp <: Symbol && typeof(value) <: String && value[1] == ':'
                    value = Symbol(value[2:end])
                end
                try
                    setfield!(parameter, :value, value)
                catch e
                    @show field
                    @show value
                    rethrow(e)
                end
            end
        end
    end
    return par
end

function dict2par!(vec::AbstractVector, par::AbstractParametersVector)
    for kk in eachindex(vec)
        subpar = eltype(par)()
        push!(par, subpar)
        dict2par!(vec[kk], subpar)
    end
end

"""
    replace_symbols_to_colon_strings(obj::Any)

Recursively converts all Symbol in a data structure to strings preceeded by column `:`

NOTE: does not modify the original obj but insteady makes a copy of the data
"""
function replace_symbols_to_colon_strings(obj::Any)
    if isa(obj, AbstractDict)
        new_dict = typeof(obj).name.wrapper()
        for (k, v) in obj
            new_key = isa(k, Symbol) ? ":$k" : k
            new_value = isa(v, Symbol) ? ":$v" : replace_symbols_to_colon_strings(v)
            new_dict[new_key] = new_value
        end
        return new_dict
    elseif isa(obj, AbstractVector)
        return [replace_symbols_to_colon_strings(elem) for elem in obj]
    elseif isa(obj, Symbol)
        return ":$obj"
    else
        return obj
    end
end

"""
    replace_colon_strings_to_symbols(obj::Any)

Recursively converts all strings preceeded by column `:` to Symbol
Assumes that keys in dictionary are always symbols

NOTE: does not modify the original obj but insteady makes a copy of the data
"""
function replace_colon_strings_to_symbols(obj::Any)
    if isa(obj, AbstractDict)
        kk = [isa(k, String) ? Symbol(lstrip(k, ':')) : k for k in keys(obj)]
        vv = [isa(v, String) && startswith(v, ":") ? Symbol(lstrip(v, ':')) : replace_colon_strings_to_symbols(v) for v in values(obj)]
        return typeof(obj).name.wrapper(zip(kk, vv))
    elseif isa(obj, AbstractVector)
        return [replace_colon_strings_to_symbols(elem) for elem in obj]
    elseif isa(obj, String) && startswith(obj, ":")
        return Symbol(lstrip(obj, ':'))
    else
        return obj
    end
end
