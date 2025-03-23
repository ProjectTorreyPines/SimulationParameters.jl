
"""
    fieldwise_isequal(x, y)
"""
function fieldwise_isequal(x::T, y::T; verbose::Bool=false) where {T<:Union{<:AbstractParameter,<:OptParameter}}
    if typeof(x) !== typeof(y)
        if verbose
            println("Type difference:")
            println("  x --> $(typeof(x))")
            println("  y --> $(typeof(y))")
        end
        return false
    end
    for f in fieldnames(typeof(x))
        v1 = getfield(x, f)
        v2 = getfield(y, f)

        if v1 isa WeakRef && v2 isa WeakRef
            continue
        end

        if !((ismissing(v1) && ismissing(v2)) || isequal(v1, v2))
            if verbose
                printstyled("$f"; bold=true)
                print(" is different:\n")
                print("   [$(summary(v1))]: ")
                printstyled("$v1\n"; color=:red)
                print("   [$(summary(v2))]: ")
                printstyled("$v2\n"; color=:green)
            end
            return false
        end
    end
    return true
end

Base.:(==)(o1::OptParameter, o2::OptParameter) = isequal(o1, o2)
Base.isequal(o1::OptParameter, o2::OptParameter; verbose=false) = fieldwise_isequal(o1, o2; verbose)
Base.:(==)(o1::AbstractParameter, o2::AbstractParameter) = isequal(o1, o2)
Base.isequal(p1::AbstractParameter, p2::AbstractParameter; verbose=false) = fieldwise_isequal(p1, p2; verbose)

