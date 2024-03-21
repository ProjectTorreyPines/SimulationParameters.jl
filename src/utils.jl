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
        elseif !equals_with_missing(v1.value, v2.value)
            error("$key had different value:\n$v1\n\n$v2")
        end
    end
    return false
end

function Base.diff(p1::AbstractParametersVector, p2::AbstractParametersVector)
    k1 = 1:length(p1)
    k2 = 1:length(p2)
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

"""
    encode_array(arr::AbstractVector{T})::Tuple{Vector{Int},Vector{T}} where {T}

Encode an "array of something" (typically symbols) into an array of integers

Returns a tuple with encoded array and mapping used to perform the encoding
"""
function encode_array(arr::AbstractVector{T})::Tuple{Vector{Int},Vector{T}} where {T}
    # Identify unique elements and create a mapping
    mapping = OrderedCollections.OrderedDict(elem => idx for (idx, elem) in enumerate(unique(arr)))

    # Encode the original array
    encoded = Int[mapping[item] for item in arr]

    return encoded, collect(keys(mapping))
end

function mirror_bound(x::T, l::T, u::T) where {T<:Real}
    d = (u - l) / 2.0
    c = (u + l) / 2.0
    x0 = (x - c) / d
    while abs(x0) > 1.0
        if x0 < 1.0
            x0 = -2.0 - x0
        else
            x0 = 2.0 - x0
        end
    end
    return x0 * d + c
end

function simple_interp1d(x, y, xi::Real)
    return simple_interp1d(x, y, [xi])[1]
end

function simple_interp1d(x, y, xi)
    yi = similar(xi)
    for (i, xval) in enumerate(xi)
        if x[1] <= xval <= x[end]
            for j in 1:length(x)-1
                if x[j] <= xval <= x[j+1]
                    fraction = (xval - x[j]) / (x[j+1] - x[j])
                    yi[i] = y[j] + fraction * (y[j+1] - y[j])
                    break
                end
            end
        else
            error("simple_interp1d Outside of interpolation range")
        end
    end
    return yi
end
