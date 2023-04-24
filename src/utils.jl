"""
    par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)

Save AbstractParameters to JSON

NOTE: kw arguments are passed to JSON.print
"""
function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    json_data = par2dict(par)
    json_data = replace_symbols_to_colon_strings(json_data)
    open(filename, "w") do io
        JSON.print(io, json_data, 1; kw...)
    end
end

"""
    json2par(filename::AbstractString, par_data::AbstractParameters)

Loads AbstractParameters from JSON
"""
function json2par(filename::AbstractString, par_data::AbstractParameters)
    json_data = JSON.parsefile(filename, dicttype=OrderedCollections.OrderedDict)
    json_data = replace_colon_strings_to_symbols(json_data)
    return dict2par!(json_data, par_data)
end

"""
    par2dict(par::AbstractParameters)

Convert AbstractParameters to dictionary
"""
function par2dict(par::AbstractParameters)
    dct = Dict()
    return par2dict!(par, dct)
end

"""
    par2dict!(par::AbstractParameters, dct::AbstractDict)

Convert AbstractParameters to dictionary
"""
function par2dict!(par::AbstractParameters, dct::AbstractDict)
    for field in keys(par)
        value = getfield(par, field)
        if typeof(value) <: AbstractParameters
            dct[field] = Dict()
            par2dict!(value, dct[field])
        elseif typeof(value) <: AbstractParameter
            tp = typeof(value).parameters[1]
            if tp <: Enum
                dct[field] = Int(getfield(value, :value))
            else
                dct[field] = getfield(value, :value)
            end
        else
            error("par2dict! should not be here")
        end
    end
    return dct
end

"""
    dict2par!(dct::AbstractDict, par::AbstractParameters)

Convert dictionary to AbstractParameters
"""
function dict2par!(dct::AbstractDict, par::AbstractParameters)
    for field in keys(par)
        value = getfield(par, field)
        if field ∉ keys(dct)
            # this can happen when par is newer than dct
            continue
        end
        if typeof(value) <: AbstractParameters
            dict2par!(dct[field], value)
        else
            tp = typeof(value).parameters[1]
            tmp = dct[field]
            try
                if tmp === nothing
                    tmp = missing
                elseif tp <: Enum
                    tmp = tp(tmp)
                elseif typeof(tmp) <: AbstractVector
                    try
                        tmp = Float64[k for k in tmp]
                    catch
                    end
                end
                setfield!(value, :value, tmp)
            catch e
                @error("reading $(join(path(par),".")).$(field) : $e")
            end
        end
    end
    return par
end

"""
    replace_symbols_to_colon_strings(obj::Any)

Recursively converts all Symbol in a data structure to strings preceeded by column `:`

NOTE: does not modify the original obj but insteady makes a copy of the data
"""
function replace_symbols_to_colon_strings(obj::Any)
    if isa(obj, AbstractDict)
        new_dict = Dict()
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

NOTE: does not modify the original obj but insteady makes a copy of the data
"""
function replace_colon_strings_to_symbols(obj::Any)
    if isa(obj, AbstractDict)
        new_dict = Dict()
        for (k, v) in obj
            new_key = isa(k, String) && startswith(k, ":") ? Symbol(lstrip(k, ':')) : k
            new_value = isa(v, String) && startswith(v, ":") ? Symbol(lstrip(v, ':')) : replace_colon_strings_to_symbols(v)
            new_dict[new_key] = new_value
        end
        return new_dict
    elseif isa(obj, AbstractVector)
        return [replace_colon_strings_to_symbols(elem) for elem in obj]
    elseif isa(obj, String) && startswith(obj, ":")
        return Symbol(lstrip(obj, ':'))
    else
        return obj
    end
end

"""
    diff(p1::AbstractParameters, p2::AbstractParameters)

Raises error there's a difference between two AbstractParameters
"""
function Base.diff(p1::AbstractParameters, p2::AbstractParameters)
    k1 = collect(keys(p1))
    k2 = collect(keys(p2))
    commonkeys = intersect(Set(k1), Set(k2))
    if length(commonkeys) != length(k1)
        error("p1 has more keys")
    elseif length(commonkeys) != length(k2)
        error("p2 has more keys")
    end
    for key in commonkeys
        v1 = getfield(p1, key)
        v2 = getfield(p2, key)
        if typeof(v1) !== typeof(v2)
            error("$key is of different type")
        elseif typeof(v1) <: AbstractParameters
            diff(v1, v2)
        elseif typeof(v1.value) === typeof(v2.value) === Missing
            continue
        elseif v1.value != v2.value
            error("$key had different value:\n$v1\n\n$v2")
        end
    end
    return false
end
