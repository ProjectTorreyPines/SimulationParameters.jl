# ==== # 
# YAML #
# ==== # 

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
            else
                pre = " "^depth
            end
            if typeof(parameter) <: AbstractParameters
                if skip_defaults && all(
                    !(typeof(leaf) <: ParsNodeRepr) || !(typeof(leaf.value) <: AbstractParameter) ||
                    equals_with_missing(getfield(leaf.value, :value), getfield(leaf.value, :default))
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
                if typeof(value) <: Union{Function,TimeData}
                    # NOTE: For now parameters saved to JSON/YAML are not time dependent
                    time0 = global_time(par)
                    value = value(time0)::tp
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
                error("par2ystr $(field) should not be here, with $(typeof(parameter))")
            end
            if is_part_of_array
                is_part_of_array = false
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
    ystr2par(yaml_string::String, par::AbstractParameters)

Loads AbstractParameters from YAML string
"""
function ystr2par(yaml_string::String, par::AbstractParameters)
    if isempty(yaml_string)
        return par
    end

    # replace missing with null
    missing_null = line -> replace(line, r"\bmissing\b" => "null")
    yaml_string = join((missing_null(line) for line in split(yaml_string, "\n")), "\n")

    # now parse
    data = YAML.load(yaml_string; dicttype=OrderedCollections.OrderedDict)
    data = replace_colon_strings_to_symbols(data)
    dict2par!(data, par)
    setup_parameters!(par)
    return par
end

"""
    yaml2par(filename::AbstractString, par::AbstractParameters)

Loads AbstractParameters from YAML
"""
function yaml2par(filename::AbstractString, par::AbstractParameters)
    open(filename, "r") do io
        return ystr2par(read(io, String), par)
    end
end

# ==== # 
# JSON #
# ==== # 

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
    json2par(filename::AbstractString, par::AbstractParameters)

Loads AbstractParameters from JSON
"""
function json2par(filename::AbstractString, par::AbstractParameters)
    open(filename, "r") do io
        return jstr2par(read(io, String), par)
    end
end

"""
    jstr2par(json_string::String, par::AbstractParameters)

Loads AbstractParameters from JSON string
"""
function jstr2par(json_string::String, par::AbstractParameters)
    data = JSON.parse(json_string; dicttype=OrderedCollections.OrderedDict)
    data = replace_colon_strings_to_symbols(data)
    dict2par!(data, par)
    setup_parameters!(par)
    return par
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

# ==== #
# Dict #
# ==== #

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
            value = string_encode_value(par, field)
            if value !== missing
                dct[field] = value
            end
        else
            error("par2dict! $(field) should not be here, with $(typeof(parameter))")
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
        try
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
                value = string_decode_value(par, field, dct[field])                
                setproperty!(par, field, value)
            end
        catch e
            println(stderr, "Error setting parameter `$(spath(parameter))` with: $(repr(dct[field]))")
            rethrow(e)
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

# ==== #
# HDF5 #
# ==== #

"""
    par2hdf(@nospecialize(par::AbstractParameters), filename::String; kw...)

Save AbstractParameters to HDF5

NOTE: kw arguments are passed to HDF5.h5open
"""
function par2hdf(@nospecialize(par::AbstractParameters), filename::String; kw...)
    HDF5.h5open(filename, "w"; kw...) do fid
        return par2hdf!(par, fid)
    end
end

function par2hdf!(@nospecialize(par::AbstractParameters), gparent::Union{HDF5.File,HDF5.Group})
    for field in keys(par)
        parameter = getfield(par, field)
        if typeof(parameter) <: Union{AbstractParameters,AbstractParametersVector}
            g = HDF5.create_group(gparent, string(field))
            par2hdf!(parameter, g)
        elseif typeof(parameter) <: AbstractParameter
            value = string_encode_value(par, field)
            if value === missing
                continue
            elseif typeof(value) <: AbstractString
                HDF5.write(gparent, string(field), value)
            else
                dset = HDF5.create_dataset(gparent, string(field), eltype(value), size(value))
                HDF5.write(dset, value)
            end
        else
            error("par2hdf! $(field) should not be here, with $(typeof(parameter))")
        end
    end
end

function par2hdf!(@nospecialize(par::AbstractParametersVector), gparent::Union{HDF5.File,HDF5.Group})
    for (index, parameter) in enumerate(par)
        g = HDF5.create_group(gparent, string(index))
        par2hdf!(parameter, g)
    end
end

function hdf2par(@nospecialize(par::AbstractParameters), filename::String; kw...)
    HDF5.h5open(filename, "w"; kw...) do fid
        return par2hdf!(par, fid)
    end
end

"""
    hdf2par(filename::AbstractString, par::AbstractParameters; kw...)

Loads AbstractParameters from HDF5
"""
function hdf2par(filename::AbstractString, par::AbstractParameters; kw...)
    HDF5.h5open(filename, "r"; kw...) do fid
        hdf2par(fid, par)
    end
end

function hdf2par(gparent::Union{HDF5.File,HDF5.Group}, @nospecialize(par::AbstractParameters))
    for field in keys(gparent)
        if typeof(gparent[field]) <: HDF5.Dataset
            value = string_decode_value(par, Symbol(field), read(gparent, field))
            setproperty!(par, Symbol(field), value)
        else
            hdf2par(gparent[field], getproperty(par, Symbol(field)))
        end
    end
    return par
end

function hdf2par(gparent::Union{HDF5.File,HDF5.Group}, @nospecialize(par::AbstractParametersVector))
    indexes = sort!(collect(map(x -> parse(Int64, x), keys(gparent))))
    if isempty(par)
        resize!(par, length(indexes))
    end
    for (k, index) in enumerate(indexes)
        hdf2par(gparent[string(index)], par[k])
    end
    return par
end

# ===== #
# Utils #
# ===== #

function string_encode_value(par::AbstractParameters, field::Symbol)
    parameter = getfield(par, field)
    tp = typeof(parameter).parameters[1]
    value = getfield(parameter, :value)
    if value === missing
        return missing
    elseif typeof(value) <: Union{Function,TimeData}
        # NOTE: For now parameters are saved to JSON not time dependent
        time0 = global_time(par)
        return value(time0)::tp
    elseif tp <: Enum
        str_enum = string(value)
        return ":$(str_enum[2:end-1])"
    elseif tp <: AbstractRange || typeof(value) <: AbstractRange
        return "$(Float64(value.offset)):$(Float64(value.step)):$(Float64(value.offset+value.len))"
    elseif tp <: Symbol || typeof(value) <: Symbol
        return ":$value"
    elseif tp <: Vector{Symbol}
        return [":$val" for val in value]
    elseif tp <: Tuple
        return collect(value)
    elseif tp <: Measurement
        return "$value"
    else
        return value
    end
end

function string_decode_value(par::AbstractParameters, field::Symbol, value::Any)
    parameter = getfield(par, field)
    tp = typeof(parameter).parameters[1]
    if tp <: Enum
        if typeof(value) <: Int
            value = Symbol(string(tp(value))[2:end-1])
        elseif typeof(value) <: String
            value = Symbol(value[2:end])
        end
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
            if typeof(tp) <: Union
                etp = eltype([etp for etp in Base.uniontypes(tp) if etp <: AbstractVector][1])
            else
                etp = eltype(tp)
            end
            if !isempty(value)
                value = etp.(value)
            else
                value = Vector{etp}()
            end
            if tp <: Tuple
                value = tuple(map((val, target_type) -> convert(target_type, val), value, tp.parameters)...)
            end
        elseif typeof(value) <: String && !isempty(value) && startswith(value, ':')
            value = Symbol(value[2:end])
        elseif tp <: Tuple
            expr = Meta.parse(value)
            value = tuple(map((x, target_type) -> convert(target_type, eval(x)), expr.args, tp.parameters)...)
        elseif tp <: Bool && typeof(value) <: Int
            value = Bool(value)
        end
    end
    return value
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
