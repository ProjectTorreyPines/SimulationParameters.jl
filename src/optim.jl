# ================= #
# OptParameterRange #
# ================= #
struct OptParameterRange{T} <: OptParameter where {T<:Real}
    nominal::T
    lower::T
    upper::T
    n::Int
    choices::Missing
end

function OptParameterRange(nominal::T, lower::T, upper::T) where {T}
    if nominal < lower
        error("Optimization parameter: nominal value < lower bound")
    elseif nominal > upper
        error("Optimization parameter: nominal value > lower bound")
    end
    return OptParameterRange(nominal, lower, upper, 1, missing)
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameterRange
"""
function ↔(x::Real, r::AbstractVector)
    @assert length(r) == 2
    @assert typeof(x) === typeof(r[1]) === typeof(r[2]) "OptParameterRange `P ↔ [L, U]` must have the same type for `P`, `L`, and `U`"
    return OptParameterRange(x, r[1], r[2])
end

# ================== #
# OptParameterChoice #
# ================== #
struct OptParameterChoice{T} <: OptParameter where {T<:Any}
    nominal::T
    lower::Missing
    upper::Missing
    n::Int
    choices::AbstractVector{T}
end

"""
    ↔(x::Real, r::AbstractVector)

"leftrightarrow" unicode constructor for OptParameterChoice
"""
function ↔(x::Any, r::Tuple)
    @assert eltype(collect(r)) === typeof(x) "OptParameterChoice `P ↔ (O1, O2, ...)` must have the same type for `P` and all the choices `Os`"
    return OptParameterChoice(x, collect(r))
end

function OptParameterChoice(nominal::T, choices::AbstractVector{T}) where {T}
    return OptParameterChoice(nominal, missing, missing, 1, choices)
end

# ==================== #
# OptParameterFunction #
# ==================== #
struct OptParameterFunction <: OptParameter
    nominal::Function
    lower::Function
    upper::Function
    t_range::Tuple{Float64,Float64}
    n::Int
    nodes::Int
    choices::Missing
end

function OptParameterFunction(nominal::Function, lower::Function, upper::Function, nodes::Int; t_range::Tuple{Float64,Float64})
    n = nodes * 2
    return OptParameterFunction(nominal, lower, upper, t_range, n, nodes, missing)
end

function OptParameterFunction(nominal::Function, bounds::Function, nodes::Int; t_range::Tuple{Float64,Float64})
    return OptParameterFunction(nominal, t -> -bounds(t), bounds, nodes; t_range)
end

# ============ #
# float_bounds #
# ============ #
"""
    float_bounds(parameter::AbstractParameter)

Returns optimization bounds of a parameter (if it has one)
"""
function float_bounds(parameter::AbstractParameter)
    if parameter.opt === missing
        error("$(parameter.name) does not have a optimization range defined")
    end
    return float_bounds(parameter.opt)
end

function float_bounds(opt::OptParameterRange)
    tp = typeof(opt.nominal)
    if tp <: Union{Bool,Integer}
        lower = Int(opt.lower) - 0.5
        upper = Int(opt.upper) + 0.5
    else
        lower = opt.lower
        upper = opt.upper
    end
    return [[lower, upper];;]
end

function float_bounds(opt::OptParameterChoice)
    lower = 0.5
    upper = length(opt.choices) + 0.5
    return [[lower, upper];;]
end

function float_bounds(opt::OptParameterFunction)
    return [[fill(1E-3, opt.nodes);; fill(1.0 - 1E-3, opt.nodes)]; [fill(-1.0, opt.nodes);; fill(1.0, opt.nodes)]]'
end

function float_bounds(opts::Vector{AbstractParameter})
    return hcat([float_bounds(optpar) for optpar in opts]...)
end

# ==== #
# call #
# ==== #
# Translates floats into the right type of the OptParameter.
# This is used when running an optimizer. The optimizer generates
# new values (Float64) for the optimization array.
# The Float64 then needs to be translated to the proper type

function (opt::OptParameterRange)(X::Vector{Float64})
    @assert length(X) == 1
    x = X[1]
    tp = typeof(opt.nominal)
    lower, upper = float_bounds(opt)
    @assert (lower <= x) && (x <= upper) "OptParameter exceeded bounds"
    if tp <: Union{Integer,Bool}
        if x == lower
            return tp(ceil(x))
        elseif x == upper
            return tp(floor(x))
        else
            return tp(round(x))
        end
    else
        return x
    end
end

function (opt::OptParameterChoice)(X::Vector{Float64})
    @assert length(X) == 1
    x = X[1]
    lower, upper = float_bounds(opt)
    @assert (lower <= x) && (x <= upper) "OptParameter exceeded bounds"
    if x == lower
        index = Int(ceil(x))
    elseif x == upper
        index = Int(floor(x))
    else
        index = Int(round(x))
    end
    return opt.choices[index]
end

function (opt::OptParameterFunction)(X::Vector{T}; clip::Bool=false, transform::Bool=false) where {T<:Float64}
    @assert length(X) == opt.n
    t0 = X[1:Int(end / 2)]
    v0 = X[Int(end / 2)+1:end]
    return opt(t0, v0; clip, transform)
end

"""
    (opt::OptParameterFunction)(t0::Vector{T}, v0::Vector{T}) where {T<:Float64}

Returns a function that stays within the envelope defined by opt, where t0 and v0 are normalized vector within the envelope

    0.0  .<  t0 .<  1.0
    -1.0 .<= v0 .<= 1.0
"""
function (opt::OptParameterFunction)(t0::Vector{T}, v0::Vector{T}; clip::Bool=false, transform::Bool=false) where {T<:Float64}
    @assert length(t0) == length(v0)
    @assert !(transform && clip) "Cannot have both clipping and transform"

    index = sortperm(t0)
    t0 = t0[index]
    v0 = v0[index]

    if clip
        t0 = mirror_bound.(t0, 1E-6, 1.0 - 1E-6)
        v0 = mirror_bound.(v0, -1.0, 1.0)
    end

    # before this point t0 is between 0 and 1 and v0 is between -1 and 1

    if transform
        t0 = (t0 .* 2.0) .- 1.0
        t0 = atan.(t0) / pi * 2.0
        t0 = (t0 .+ 1.0) / 2.0
        v0 = atan.(v0) / pi * 2
    end

    # after this point both t0 and v0 are between 0 and 1

    v0 = (v0 .+ 1.0) / 2.0

    @assert all(0.0 .< t0 .< 1.0) "t0=$t0 but it should be 0.0 .< t0 .< 1.0"
    @assert all(-1.0 .<= v0 .<= 1.0) "v0=$v0 but it should be -1.0 .<= v0 .<= 1.0"

    t = t0 .* (opt.t_range[2] .- opt.t_range[1]) .+ opt.t_range[1]
    fu(t) = opt.nominal(t) + opt.upper(t)
    fl(t) = opt.nominal(t) + opt.lower(t)
    v = v0 .* fu.(t) .+ (1.0 .- v0) .* fl.(t)

    tt = [opt.t_range[1]; t; opt.t_range[2]]
    vv = [opt.nominal(opt.t_range[1]); v; opt.nominal(opt.t_range[2])]

    return t -> begin
        if t < opt.t_range[1] || t > opt.t_range[2]
            return opt.nominal(t)
        else
            return simple_interp1d(tt, vv, t)
        end
    end
end

function (opt::OptParameterFunction)(; uniform::Bool=false)
    if uniform
        t0 = collect(range(0.0, 1.0, opt.nodes + 2)[2:end-1])
        v0 = fill(0.0, opt.nodes)
    else
        t0 = sort!(rand(opt.nodes))
        v0 = rand(opt.nodes) .* 2.0 .- 1.0
    end
    return (opt)(t0, v0)
end

# ========= #
# opt2value #
# ========= #
"""
    opt2value(opt::OptParameterRange, tp::Type)

Samples the OptParameterRange for a value
"""
function opt2value(opt::OptParameterRange, tp::Type)
    if tp <: Integer
        lower = Int(opt.lower)
        upper = Int(opt.upper)
        return rand(range(opt.lower; stop=opt.upper))
    else
        lower = opt.lower
        upper = opt.upper
        return lower + rand() * (upper - lower)
    end
end

"""
    opt2value(opt::OptParameterChoice, tp::Type)

Samples the OptParameterChoice for a value
"""
function opt2value(opt::OptParameterChoice, tp::Type)
    index = rand(range(1; stop=length(opt.choices)))
    return opt.choices[index]
end

"""
    opt2value(opt::OptParameterFunction, tp::Type)

Samples the OptParameterFunction for a function
"""
function opt2value(opt::OptParameterFunction, tp::Type)
    return opt()
end

# ==== #
# rand #
# ==== #
"""
    Base.rand(parameters::AbstractParameters, field::Symbol)

Generates a new random sample within the OptParameter distribution
"""
function Base.rand(parameters::AbstractParameters, field::Symbol)
    return rand(getfield(parameters, field))
end

"""
    Base.rand(parameter::AbstractParameter)

Generates a new random sample within the OptParameter distribution
"""
function Base.rand(parameter::AbstractParameter)
    return opt2value(parameter.opt, typeof(parameter.value))
end

"""
    rand!(parameters::AbstractParameters, field::Symbol)

Generates a new random sample within the OptParameter distribution and updates the parameter value
"""
function rand!(parameters::AbstractParameters, field::Symbol)
    return rand!(getfield(parameters, field))
end

"""
    rand!(parameter::AbstractParameter)

Generates a new random sample within the OptParameter distribution and updates the parameter value
"""
function rand!(parameter::AbstractParameter)
    return setfield!(parameter, :value, rand(parameter))
end

# ===================================== #
# opt_parameters & parameters_from_opt! #
# ===================================== #
# these functions are used to pack and unpack an optimization array
# starting from a high-level AbstractParameters (like `ini` or `act` in FUSE)
"""
    opt_parameters(parameters::AbstractParameters, optimization_vector::Vector{AbstractParameter}=AbstractParameter[])

Pack the optimization parameters contained in a high-level `parameters` AbstractParameters into a `optimization_values` vector
"""
function opt_parameters(parameters::AbstractParameters, optimization_vector::Vector{AbstractParameter}=AbstractParameter[])
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            opt_parameters(parameter, optimization_vector)
        elseif typeof(parameter) <: AbstractParametersVector
            for kk in eachindex(parameter)
                opt_parameters(parameter[kk], optimization_vector)
            end
        elseif typeof(parameter.opt) <: OptParameter
            push!(optimization_vector, parameter)
        end
    end
    return optimization_vector
end

"""
    parameters_from_opt!(parameters::AbstractParameters, optimization_values::AbstractVector)

Unpack a `optimization_values` vector into a high-level `parameters` AbstractParameters
"""
function parameters_from_opt!(parameters::AbstractParameters, optimization_values::AbstractVector)
    parameters_from_opt!(parameters, optimization_values, 1)
    return parameters
end

function parameters_from_opt!(parameters::AbstractParameters, optimization_values::AbstractVector, k::Int)
    for field in keys(parameters)
        parameter = getfield(parameters, field)
        if typeof(parameter) <: AbstractParameters
            _, k = parameters_from_opt!(parameter, optimization_values, k)
        elseif typeof(parameter) <: AbstractParametersVector
            for kk in eachindex(parameter)
                _, k = parameters_from_opt!(parameter[kk], optimization_values, k)
            end
        elseif typeof(parameter.opt) <: OptParameter
            n = parameter.opt.n
            value = parameter.opt(optimization_values[k:k+n-1])
            setproperty!(parameter, :value, value)
            k += n
        end
    end
    return parameters, k
end
