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
        elseif typeof(v1) <: AbstractParametersVector
            diff(v1, v2)
        elseif typeof(v1.value) === typeof(v2.value) === Missing
            continue
        elseif v1.value != v2.value
            error("$key had different value:\n$v1\n\n$v2")
        end
    end
    return false
end

function Base.diff(p1::AbstractParametersVector, p2::AbstractParametersVector)
    k1 = 1:length(getfield(p1, :_aop))
    k2 = 1:length(getfield(p2, :_aop))
    commonkeys = intersect(Set(k1), Set(k2))
    if length(commonkeys) != length(k1)
        error("p1 has more elements")
    elseif length(commonkeys) != length(k2)
        error("p2 has more elements")
    end
    for key in commonkeys
        v1 = p1[key]
        v2 = p1[key]
        if typeof(v1) !== typeof(v2)
            error("$key is of different type")
        elseif typeof(v1) <: AbstractParameters
            diff(v1, v2)
        else
            error("Diff should not be here")
        end
    end
    return false
end

"""
    word_wrap(s::String, n=92; i=n, p=1, w=1)

Wraps a string at spaces at `n` characters
"""
function word_wrap(s::String, n=92; i=n, p=1, w=1)
    s = deepcopy(s)
    for c in s
        (i -= 1) < -1 && (i = w - p + n; unsafe_store!(pointer(s, w), 10))
        c == ' ' && (w = p)
        p += 1
    end
    return s
end

function encode_array(arr::Vector{<:Any})
    # Identify unique elements and create a mapping
    mapping = OrderedCollections.OrderedDict(elem => idx for (idx, elem) in enumerate(unique(arr)))

    # Encode the original array
    encoded = [mapping[item] for item in arr]

    return encoded, mapping
end