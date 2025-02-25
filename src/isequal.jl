
"""
    fieldwise_isequal(x, y)
"""
function fieldwise_isequal(x, y)
    if typeof(x) !== typeof(y)
        return false
    end
    for f in fieldnames(typeof(x))
        v1 = getfield(x, f)
        v2 = getfield(y, f)
        if !((ismissing(v1) && ismissing(v2)) || fieldwise_isequal(v1, v2))
            return false
        end
    end
    return true
end

Base.:(==)(o1::OptParameter, o2::OptParameter) = isequal(o1, o2)
Base.isequal(o1::OptParameter, o2::OptParameter) = fieldwise_isequal(o1, o2)
Base.isequal(p1::AbstractParameter, p2::AbstractParameter) = fieldwise_isequal(p1, p2)

