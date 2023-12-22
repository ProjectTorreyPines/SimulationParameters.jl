struct InexistentParameterException <: Exception
    path::Vector{Symbol}
end

Base.showerror(io::IO, e::InexistentParameterException) = print(io, "$(join(e.path,".")) does not exist")

struct NotsetParameterException <: Exception
    path::Vector{Symbol}
    units::String
    options::Vector{Any}
end

NotsetParameterException(path::Vector{Symbol}, units::String) = NotsetParameterException(path, units, [])

function Base.showerror(io::IO, e::NotsetParameterException)
    units = ""
    if length(replace(e.units, "-" => "")) > 0
        units = " [$(e.units)]"
    end
    if length(e.options) > 0
        print(io, "Parameter $(spath(e.path))$units is not set. Valid options are $(join(map(repr,e.options),", "))")
    else
        print(io, "Parameter $(spath(e.path))$units is not set")
    end
end

struct BadParameterException <: Exception
    path::Vector{Symbol}
    value::Any
    units::String
    options::Vector{Any}
end

function Base.showerror(io::IO, e::BadParameterException)
    units = ""
    if length(replace(e.units, "-" => "")) > 0
        units = " [$(e.units)]"
    end
    return print(io, "Parameter $(spath(e.path)) = $(repr(e.value))$units is not one of the valid options $(join(map(repr, e.options),", "))")
end