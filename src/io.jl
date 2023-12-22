"""
    par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)

Save AbstractParameters to JSON

NOTE: kw arguments are passed to JSON.print
"""
function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    json_string = string(par; kw...)
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
        return str2par(read(io, String), par_data)
    end
end

"""
    str2par(json_string::String, par_data::AbstractParameters)

Loads AbstractParameters from JSON string
"""
function str2par(json_string::String, par_data::AbstractParameters)
    data = JSON.parse(json_string; dicttype=OrderedCollections.OrderedDict)
    data = replace_colon_strings_to_symbols(data)
    dict2par!(data, par_data)
    setup_parameters!(par_data)
    return par_data
end

"""
    Base.string(@nospecialize(par::AbstractParameters); indent::Int=1, kw...)

Returns JSON serialization of AbstractParameters
"""
function Base.string(@nospecialize(par::AbstractParameters); indent::Int=1, kw...)
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
                dct[field] = value(top(par).time.simulation_start)::tp
            elseif tp <: Enum
                dct[field] = Int(value)
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
    for parameter in getfield(par, :_aop)
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
        if typeof(parameter) <: AbstractParameters
            dict2par!(dct[field], parameter)
        elseif typeof(parameter) <: AbstractParametersVector
            for kk in eachindex(dct[field])
                subpar = eltype(parameter)()
                push!(parameter, subpar)
                dict2par!(dct[field][kk], subpar)
            end
        else
            tp = typeof(parameter).parameters[1]
            tmp = dct[field]
            try
                if tmp === nothing
                    tmp = missing
                elseif tp <: Enum
                    tmp = tp(tmp)
                elseif typeof(tmp) <: AbstractVector
                    if !isempty(tmp)
                        tmp = eltype(tp).(tmp)
                    else
                        tmp = Vector{eltype(tp)}()
                    end
                end
                setfield!(parameter, :value, tmp)
            catch e
                @error("reading $(spath(par)).$(field) : $e")
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

NOTE: does not modify the original obj but insteady makes a copy of the data
"""
function replace_colon_strings_to_symbols(obj::Any)
    if isa(obj, AbstractDict)
        kk = [isa(k, String) && startswith(k, ":") ? Symbol(lstrip(k, ':')) : k for k in keys(obj)]
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
