"""
    par2dict(par::AbstractParameters)

Convert FUSE parameters to dictionary
"""
function par2dict(par::AbstractParameters)
    dct = Dict()
    return par2dict!(par, dct)
end

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

function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    open(filename, "w") do io
        JSON.print(io, par2dict(par), 1; kw...)
    end
end

function dict2par!(dct::AbstractDict, par::AbstractParameters)
    for field in keys(par)
        value = getfield(par, field)
        if field ∈ keys(dct)
            # this is if dct was par2dict function
            dkey = Symbol
        else
            # this is if dct was generated from json
            dkey = string
        end
        if dkey(field) ∉ keys(dct)
            # this can happen when par is newer than dct
            continue
        end
        if typeof(value) <: AbstractParameters
            dict2par!(dct[dkey(field)], value)
        else
            tp = typeof(value).parameters[1]
            if typeintersect(tp, AbstractDict) == Union{} && typeof(dct[dkey(field)]) <: AbstractDict
                tmp = dct[dkey(field)][dkey(:value)] # legacy way of saving data
            else
                tmp = dct[dkey(field)]
            end
            try
                if tmp === nothing
                    tmp = missing
                elseif tp <: Enum
                    tmp = tp(tmp)
                elseif typeintersect(tp, Symbol) != Union{} && typeof(tmp) <: AbstractString
                    tmp = Symbol(tmp)
                elseif typeof(tmp) <: AbstractVector
                    tmp = Float64[k for k in tmp]
                end
                setfield!(value, :value, tmp)
            catch e
                @error("reading $(join(path(par),".")).$field : $e")
            end
        end
    end
    return par
end

function json2par(filename::AbstractString, par_data::AbstractParameters)
    json_data = JSON.parsefile(filename, dicttype=OrderedCollections.OrderedDict)
    return dict2par!(json_data, par_data)
end

"""
    diff(p1::AbstractParameters, p2::AbstractParameters)

Look for differences between two `ini` or `act` sets of parameters
"""
function Base.diff(p1::AbstractParameters, p2::AbstractParameters)
    k1 = keys(p1)
    k2 = keys(p2)
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
end