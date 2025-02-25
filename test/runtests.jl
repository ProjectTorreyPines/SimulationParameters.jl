using SimulationParameters
import InteractiveUtils
using Test
using Statistics
using SimulationParameters.Plots

abstract type ParametersInit{T} <: AbstractParameters{T} end # container for all parameters of a init
abstract type ParametersAllInits{T} <: AbstractParameters{T} end # --> abstract type of ParametersInits, container for all parameters of all inits

function SimulationParameters.global_time(parameters::ParametersInit)
    return SimulationParameters.top(parameters).time.simulation_start
end

options = Dict(
    :1 => SwitchOption(1, "1"),
    :2 => SwitchOption(2, "2"),
    :3 => SwitchOption(3, "3"))

Base.@kwdef mutable struct FUSEparameters__ece{T<:Real} <: ParametersInit{T}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = :ece
    power::Entry{T} = Entry{T}("W", "launched power")
end

Base.@kwdef mutable struct FUSEparameters__time{T<:Real} <: ParametersInit{T}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = :time
    pulse_shedule_time_basis::Entry{AbstractRange{Float64}} = Entry{AbstractRange{Float64}}("s", "Time basis used to discretize the pulse schedule")
    simulation_start::Entry{Float64} = Entry{Float64}("s", "Time at which the simulation starts"; default=0.0)
end

Base.@kwdef mutable struct FUSEparameters__equilibrium{T<:Real} <: ParametersInit{T}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = :equilibrium
    R0::Entry{T} = Entry{T}("m", "Geometric center of the plasma"; check=x -> (@assert x > 0 "R0 must be >0"))
    Z0::Entry{T} = Entry{T}("m", "Geometric center of the plasma")
    casename::Entry{String} = Entry{String}("-", "Mnemonic name of the case being run")
    init_from::Switch{Symbol} = Switch{Symbol}(
        [
            :ods => "Load data from ODS saved in .json format (where possible, and fallback on scalars otherwise)",
            :scalars => "Initialize FUSE run from scalar parameters",
            :my_own => "dummy"
        ], "myunits", "Initialize run from")
    dict_option::Switch{Int} = Switch{Int}(options, "-", "My switch with SwitchOption")
    a_symbol::Entry{Symbol} = Entry{Symbol}("-", "something"; default=:hello)
    a_vector_symbol::Entry{Vector{Symbol}} = Entry{Vector{Symbol}}("-", "something symbol vector"; default=[:hello, :world])
    b_vector_float::Entry{Vector{Float64}} = Entry{Vector{Float64}}("-", "something float64 vector"; default=[0.1, 0.2, 0.3])
    v_params::ParametersVector{FUSEparameters__ece{T}} = ParametersVector{FUSEparameters__ece{T}}()
end

mutable struct ParametersInits{T<:Real} <: ParametersAllInits{T}
    _parent::WeakRef
    _name::Symbol
    time::FUSEparameters__time{T}
    equilibrium::FUSEparameters__equilibrium{T}
end

function ParametersInits{T}(; n_ece::Int=0) where {T<:Real}
    ini = ParametersInits{T}(
        WeakRef(nothing),
        :ini,
        FUSEparameters__time{T}(),
        FUSEparameters__equilibrium{T}()
    )
    for k in 1:n_ece
        push!(ini.equilibrium.v_params, FUSEparameters__ece{T}())
    end
    setup_parameters!(ini)
    return ini
end

function ParametersInits(args...; kw...)
    return ParametersInits{Float64}(args...; kw...)
end

#=============#

ini = ParametersInits(; n_ece=2)
ini.equilibrium.init_from = :ods ↔ (:ods, :scalars)
ini

@testset "basic" begin
    ini = ParametersInits(; n_ece=2)

    @test SimulationParameters.path(ini.equilibrium) == Symbol[:ini, :equilibrium]

    println(getfield(ini.equilibrium, :casename))

    @test typeof(ini.equilibrium) <: AbstractParameters

    @test_throws NotsetParameterException ini.equilibrium.R0

    ini.equilibrium.R0 = 1.0
    @test ini.equilibrium.R0 == 1.0

    @test_throws Exception ini.equilibrium.R0 = "a string"

    ini.equilibrium.R0 = missing
    @test_throws NotsetParameterException ini.equilibrium.R0

    @test_throws InexistentParametersFieldException ini.equilibrium.does_not_exist = 1.0

    @test fieldnames(typeof(ini.equilibrium)) == fieldnames(typeof(FUSEparameters__equilibrium{Float64}()))

    ini.equilibrium.R0 = 5.3
    @test ini.equilibrium.R0 == 5.3

    @test (ini.equilibrium.init_from = :ods) == :ods
    @test_throws BadParameterException ini.equilibrium.init_from = :odsa

    @test (ini.equilibrium.dict_option = :1) == 1

    println(ini)
    println(ini.equilibrium.R0)

    # working with vectors of parameters
    println(ini.equilibrium.v_params)
    println(ini.equilibrium.v_params[1])
    ini.equilibrium.v_params[1].power = 1.0
    @assert ini.equilibrium.v_params[1].power == 1.0
    @assert length(ini.equilibrium.v_params) == 2

    # leaves
    SimulationParameters.leaves(ini)

    # to and from dict for saving to json
    dict2par!(par2dict(ini), ParametersInits())
end

@testset "opt_parameters" begin
    # float
    ini = ParametersInits()
    ini.equilibrium.R0 = 1.5 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 1.5
    ini.equilibrium.R0 = 1.2 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 1.2
    ini.equilibrium.R0 = 2.5 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 2.5
    @test_throws ErrorException ini.equilibrium.R0 = 1.0 ↔ [1.2, 2.5]
    @test_throws ErrorException ini.equilibrium.R0 = 3.0 ↔ [1.2, 2.5]

    # int
    ini = ParametersInits{Int}()
    ini.equilibrium.R0 = 2 ↔ [1, 3]
    @test ini.equilibrium.R0 == 2
    ini.equilibrium.R0 = 1 ↔ [1, 3]
    @test ini.equilibrium.R0 == 1
    ini.equilibrium.R0 = 3 ↔ [1, 3]
    @test ini.equilibrium.R0 == 3
    @test_throws ErrorException ini.equilibrium.R0 = 0 ↔ [1, 3]
    @test_throws ErrorException ini.equilibrium.R0 = 4 ↔ [1, 3]

    # bool
    ini = ParametersInits{Bool}()
    # boolean as range of bools
    ini.equilibrium.R0 = true ↔ [false, true]
    @test ini.equilibrium.R0 == true
    # boolean as boolean options
    ini.equilibrium.R0 = true ↔ (false, true)
    @test ini.equilibrium.R0 == true
    @test_throws ErrorException ini.equilibrium.R0 = -1 ↔ [0, 1]
    @test_throws ErrorException ini.equilibrium.R0 = 2 ↔ [0, 1]

    # check generation of optimization_vector
    @test opt_parameters(ini) == AbstractParameter[getfield(ini.equilibrium, :R0)]

    ini.equilibrium.init_from = :ods ↔ (:ods, :scalars)
    @test ini.equilibrium.init_from == :ods
    @test rand(getfield(ini.equilibrium, :init_from)) in (:ods, :scalars)

    # check generation of optimization_vector
    @test opt_parameters(ini) == AbstractParameter[getfield(ini.equilibrium, :R0), getfield(ini.equilibrium, :init_from)]

    parameters_from_opt!(ini, [0.5, 1])
    @test ini.equilibrium.R0 == false
    @test ini.equilibrium.init_from == :ods

    parameters_from_opt!(ini, [1.49, 1.2])
    @test ini.equilibrium.R0 == false
    @test ini.equilibrium.init_from == :ods

    parameters_from_opt!(ini, [1.5, 1.5])
    @test ini.equilibrium.R0 == true
    @test ini.equilibrium.init_from == :scalars

    parameters_from_opt!(ini, [1.9, 2.0])
    @test ini.equilibrium.R0 == true
    @test ini.equilibrium.init_from == :scalars

    parameters_from_opt!(ini, [2.5, 2.5])
    @test ini.equilibrium.R0 == true
    @test ini.equilibrium.init_from == :scalars

    # with OptParameterFunction
    ini = ParametersInits(; n_ece=1)
    ini.time.simulation_start = 2.0
    ini.equilibrium.R0 = (t -> 10 + t) ↔ (nodes=3, t_range=(0.0, 3.0), bounds=t -> 0.1)
    @test ini.equilibrium.R0 == 12.0 # get the nominal function
    rand!(ini.equilibrium, :R0)
    @test ini.equilibrium.R0 != 12.0
    ini.equilibrium.v_params[1].power = 2.5 ↔ [1.2, 2.5]
    opts = opt_parameters(ini)
    @test opts == AbstractParameter[getfield(ini.equilibrium, :R0), getfield(ini.equilibrium.v_params[1], :power)]
    bounds = float_bounds(opts)
    @test size(bounds) == (2, 7)
    parameters_from_opt!(ini, [0.3, 0.5, 0.8, 0.0, 0.0, 0.0, 2.0])

    # float bc
    ini.equilibrium.R0 = (t -> 10 + t) ↔ (3, (0.0, 3.0), (10.0, 20.0), (:match, :float))
    SimulationParameters.rand!(ini.equilibrium, :R0)

    # opt_labels
    @test opt_labels(opts) == ["ini.equilibrium.R0.t1", "ini.equilibrium.R0.t2", "ini.equilibrium.R0.t3", "ini.equilibrium.R0.v1", "ini.equilibrium.R0.v2", "ini.equilibrium.R0.v3", "ini.equilibrium.v_params[1].power"]

    #
    @test opt_labels(ini) == opt_labels(opts)
    @test nominal_values(ini) == nominal_values(opts)
    @test float_bounds(ini) == float_bounds(opts)

    # Check params with Distribution
    ini = ParametersInits()
    target_mean = 5.0
    target_std = 1.5
    Dist = SimulationParameters.Distributions # alias name
    trunc_Norm_dist = Dist.truncated(Dist.Normal(target_mean, target_std), lower=0.0, upper=10.0)

    @test_throws AssertionError -1.0 ↔ trunc_Norm_dist
    @test_throws AssertionError 15.0 ↔ trunc_Norm_dist

    ini.equilibrium.R0 = 5.0 ↔ trunc_Norm_dist

    sampled_R0 = [rand(getfield(ini.equilibrium, :R0)) for _ in 1:Int(1e6)]

    @test ini.equilibrium.R0 == 5.0
    @test abs((mean(sampled_R0) - target_mean) / target_mean) < 0.01
    @test abs((std(sampled_R0) - target_std) / target_std) < 0.01
end

@testset "time" begin
    ini = ParametersInits()

    time = range(0,1,11)
    ini.equilibrium.R0 = TimeData(time, time * 2)

    ini.time.simulation_start = 1.0
    @assert ini.equilibrium.R0 == 2.0

    ini.time.simulation_start = 0.5
    @assert ini.equilibrium.R0 == 1.0
end

@testset "GC_parent" begin
    ini = ParametersInits()
    @test parent(ini.equilibrium) === ini
    GC.gc()
    @test parent(ini.equilibrium) === ini
end

@testset "deepcopy" begin
    ini = ParametersInits()
    ini.equilibrium.R0 = 0.1
    @test parent(ini.equilibrium) == ini

    ini_eq = deepcopy(ini.equilibrium)
    @test parent(ini_eq) === nothing
    # change value of the copy
    ini_eq.R0 = 1.0

    # make sure that value change of the copy does not affect the original value
    @test ini.equilibrium.R0 == 0.1

    # assign the copy to the original ini
    ini.equilibrium = ini_eq
    # test that the value of the original now matches the copy
    @test ini.equilibrium.R0 == 1.0

    # test that the parent is set properly
    @test parent(ini.equilibrium) === ini
end

@testset "json_save_load" begin
    ini = ParametersInits()
    ini.equilibrium.R0 = 1000.0

    # equivalent of save to JSON without going to file
    json_string = par2jstr(ini)

    # equivalent of load from JSON without loading from file
    ini2 = jstr2par(json_string, ParametersInits())

    @test diff(ini, ini2) === false
end

@testset "yaml_save_load" begin
    ini = ParametersInits()
    ini.equilibrium.R0 = 1000.0

    # equivalent of save to YAML without going to file
    yaml_string = par2ystr(ini)

    # equivalent of load from YAML without loading from file
    ini2 = ystr2par(yaml_string, ParametersInits())

    @test diff(ini, ini2) === false
end

@testset "hdf_save_load" begin
    ini = ParametersInits()

    ini.equilibrium.R0 = 5.0 ↔ [1.0, 10.0]
    ini.equilibrium.Z0 = 0.0 ↔ SimulationParameters.Distributions.Normal(0.0, 2.0)
    ini.equilibrium.init_from = :ods ↔ (:ods, :scalars, :my_own)

    tmp_hdf_filename = tempname()*".h5"
    par2hdf(ini, tmp_hdf_filename)

    ini2 = hdf2par(tmp_hdf_filename, ParametersInits())

    @test diff(ini, ini2) === false

    # Verify that the opt-parameter properties are randomized by `rand(ini2)`.
    # Save original values to compare against random samples.
    ori_R0 = deepcopy(ini2.equilibrium.R0)
    ori_Z0 = deepcopy(ini2.equilibrium.Z0)
    ori_init_from = deepcopy(ini2.equilibrium.init_from)

    # Over N random samples, at least one value should differ from the original,
    # indicating that the parameters are being randomized.
    N=100
    @test any([ori_R0 != rand(ini2).equilibrium.R0 for _ in 1:N])
    @test any([ori_Z0 != rand(ini2).equilibrium.Z0 for _ in 1:N])
    @test any([ori_init_from != rand(ini2).equilibrium.init_from for _ in 1:N])

    isfile(tmp_hdf_filename) && rm(tmp_hdf_filename)
end

@testset "checks" begin
    ini = ParametersInits()

    # R0 should always be > 0.0
    @test (ini.equilibrium.R0 = 1.0) === 1.0
    @test_throws AssertionError ini.equilibrium.R0 = -5.0
    @test (ini.equilibrium.R0 = missing) === missing

    # checks that functions are evaluated at retrieval
    ini.equilibrium.R0 = t -> -5.0
    ini.time.simulation_start = 1.0
    @test_throws AssertionError ini.equilibrium.R0
end

@testset "concrete_types" begin
    ini = ParametersInits()
    ini.equilibrium.R0 = 5.0

    function test_me(ini)
        return ini.equilibrium.R0
    end

    test_me(ini)
    InteractiveUtils.@code_warntype test_me(ini)
end


@testset "plot_recipes" begin
    ini = ParametersInits()
    Dist = SimulationParameters.Distributions
    ini.equilibrium.R0 = 5.0 ↔ [1.0, 10.0]
    ini.equilibrium.Z0 = 0.0 ↔ Dist.Normal(0.0, 2.0)

    ini.equilibrium.init_from = :ods ↔ (:ods, :scalars, :my_own)
    ini.equilibrium.casename="case1"↔("case1", "case2", "case3")
    # plot a single ini
    plot(opt_parameters(ini))

    # generate multiple inis
    inis = [rand(ini) for _ in 1:200]

    plot(ini)
    plot(ini.equilibrium)
    plot(ini.equilibrium,:R0)

    plot(opt_parameters.(inis[1:10]))
    plot(opt_parameters.(inis[1:50]))
    plot(opt_parameters.(inis[1:101]))
    plot(opt_parameters.(inis))

    collected_params = SimulationParameters.grouping_multi_parameters(reduce(vcat,opt_parameters.(inis)))


    # keywords test
    plot(opt_parameters.(inis); flag_nominal_label=false)
    plot(opt_parameters.(inis); nrows=1)
    plot(opt_parameters.(inis); ncols=1)
    plot(opt_parameters.(inis); nrows=2, ncols=2)
    plot(opt_parameters.(inis); layout=Plots.GridLayout(2,2))
    plot(opt_parameters.(inis); layout=(2,2))
    plot(opt_parameters.(inis); layout=length(opt_parameters.(inis)))

    @test_throws Exception plot(collected_params; layout=@layout([a b c])) # @layout is not supported

end