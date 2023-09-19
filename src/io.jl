"""
    par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)

Save AbstractParameters to JSON

NOTE: kw arguments are passed to JSON.print
"""
function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    json_data = par2dict(par)
    json_data = replace_symbols_to_colon_strings(json_data)
    open(filename, "w") do io
        return JSON.print(io, json_data, 1; kw...)
    end
end

"""
    json2par(filename::AbstractString, par_data::AbstractParameters)

Loads AbstractParameters from JSON
"""
function json2par(filename::AbstractString, par_data::AbstractParameters)
    json_data = JSON.parsefile(filename; dicttype=OrderedCollections.OrderedDict)
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
        parameter = getfield(par, field)
        if typeof(parameter) <: AbstractParameters
            # NOTE: For now parameters are saved to JSON not time dependent
            if field == :time
                continue
            end
            dct[field] = Dict()
            par2dict!(parameter, dct[field])
        elseif typeof(parameter) <: AbstractParameter
            tp = typeof(parameter).parameters[1]
            value = getfield(parameter, :value)
            if typeof(value) <: Function
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
