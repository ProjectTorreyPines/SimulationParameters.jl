import DataStructures

"""
    par2dict(par::AbstractParameters)

Convert FUSE parameters to dictionary
"""
function par2dict(par::AbstractParameters)
    ret = Dict()
    return par2dict!(par, ret)
end

function par2dict!(par::AbstractParameters, ret::AbstractDict)
    for item in keys(par)
        value = getfield(par, item)
        if typeof(value) <: AbstractParameters
            ret[item] = Dict()
            par2dict!(value, ret[item])
        elseif typeof(value) <: AbstractParameter
            ret[item] = Dict()
            for field in keys(value)
                ret[item][field] = getfield(value, field)
            end
        end
    end
    return ret
end

function par2json(@nospecialize(par::AbstractParameters), filename::String; kw...)
    open(filename, "w") do io
        JSON.print(io, par2dict(par), 1; kw...)
    end
end

function dict2par!(dct::AbstractDict, par::AbstractParameters)
    for field in keys(par)
        val = getfield(par, field)
        if field ∈ keys(dct)
            # this is if dct was par2dict function
            dkey = field
            dvalue = :value
        else
            # this is if dct was generated from json
            dkey = string(field)
            dvalue = "value"
        end
        if typeof(val) <: AbstractParameters
            dict2par!(dct[dkey], val)
        elseif dct[dkey][dvalue] === nothing
            setproperty!(par, field, missing)
        elseif typeof(dct[dkey][dvalue]) <: AbstractVector # this could be done more generally
            setproperty!(par, field, Float64[k for k in dct[dkey][dvalue]])
        else
            try
                setproperty!(par, field, Symbol(dct[dkey][dvalue]))
            catch e
                try
                    setproperty!(par, field, dct[dkey][dvalue])
                catch e
                    display((field, e))
                end
            end
        end
    end
    return par
end

function json2par(filename::AbstractString, par_data::AbstractParameters)
    json_data = JSON.parsefile(filename, dicttype=DataStructures.OrderedDict)
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