using SimulationParameters
import InteractiveUtils
using Test

abstract type ParametersInit <: AbstractParameters end # container for all parameters of a init
abstract type ParametersAllInits <: AbstractParameters end # --> abstract type of ParametersInits, container for all parameters of all inits

options = Dict(
    :1 => SwitchOption(1, "1"),
    :2 => SwitchOption(2, "2"),
    :3 => SwitchOption(3, "3"))

Base.@kwdef mutable struct FUSEparameters__ece{T} <: ParametersInit where {T<:Real}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = :ece
    power::Entry{T} = Entry{T}("W", "launched power")
end

Base.@kwdef mutable struct FUSEparameters__equilibrium{T} <: ParametersInit where {T<:Real}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = :equilibrium
    R0::Entry{T} = Entry{T}("m", "Geometric genter of the plasma. NOTE: This also scales the radial build layers."; check=x -> (@assert x > 0 "R0 must be >0"))
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

mutable struct ParametersInits{T} <: ParametersAllInits where {T<:Real}
    _parent::WeakRef
    _name::Symbol
    equilibrium::FUSEparameters__equilibrium{T}
end

function ParametersInits{T}(; n_ece::Int=0) where {T<:Real}
    ini = ParametersInits{T}(
        WeakRef(nothing),
        :ini,
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

    @test_throws InexistentParameterException ini.equilibrium.does_not_exist = 1.0

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
    ini = ParametersInits()
    ini.equilibrium.R0 = 1.5 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 1.5
    ini.equilibrium.R0 = 1.2 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 1.2
    ini.equilibrium.R0 = 2.5 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 2.5
    @test_throws ErrorException ini.equilibrium.R0 = 1.0 ↔ [1.2, 2.5]
    @test_throws ErrorException ini.equilibrium.R0 = 3.0 ↔ [1.2, 2.5]

    parameters_from_opt!(ini, [1.3])
    @test ini.equilibrium.R0 == 1.3

    ini = ParametersInits{Int}()
    ini.equilibrium.R0 = 2 ↔ [1, 3]
    @test ini.equilibrium.R0 == 2
    ini.equilibrium.R0 = 1 ↔ [1, 3]
    @test ini.equilibrium.R0 == 1
    ini.equilibrium.R0 = 3 ↔ [1, 3]
    @test ini.equilibrium.R0 == 3
    @test_throws ErrorException ini.equilibrium.R0 = 0 ↔ [1, 3]
    @test_throws ErrorException ini.equilibrium.R0 = 4 ↔ [1, 3]

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

@testset "checks" begin
    ini = ParametersInits()
    @test (ini.equilibrium.R0 = 1.0) === 1.0
    @test_throws AssertionError ini.equilibrium.R0 = -5.0
    @test (ini.equilibrium.R0 = missing) === missing
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
