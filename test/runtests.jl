using Revise
using SimulationParameters
using Test
import AbstractTrees

abstract type ParametersInit <: AbstractParameters end # container for all parameters of a init
abstract type ParametersAllInits <: AbstractParameters end # --> abstract type of ParametersInits, container for all parameters of all inits

Base.@kwdef struct FUSEparameters__equilibrium{T} <: ParametersInit where {T<:Real}
    R0::Entry{T} = Entry(T, "m", "Geometric genter of the plasma. NOTE: This also scales the radial build layers.")
    casename::Entry{String} = Entry(String, "", "Mnemonic name of the case being run")
    init_from::Switch{Symbol} = Switch(Symbol, [
            :ods => "Load data from ODS saved in .json format (where possible, and fallback on scalars otherwise)",
            :scalars => "Initialize FUSE run from scalar parameters"
        ], "myunits", "Initialize run from")
end

struct ParametersInits{T} <: ParametersAllInits where {T<:Real}
    equilibrium::FUSEparameters__equilibrium{T}
end

function ParametersInits{T}() where {T<:Real}
    ini = ParametersInits{T}(
        FUSEparameters__equilibrium{T}()
    )
    setup_parameters(ini)
    return ini
end

function ParametersInits()
    return ParametersInits{Float64}()
end

#=============#

@testset "BasicTests" begin
    ini = ParametersInits()

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

    println(ini)
    println(ini.equilibrium.R0)

    dict2par!(par2dict(ini), ParametersInits())
end

@testset "OptTests" begin
    ini = ParametersInits()
    ini.equilibrium.R0 = 1.5 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 1.5
    ini.equilibrium.R0 = 1.2 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 1.2
    ini.equilibrium.R0 = 2.5 ↔ [1.2, 2.5]
    @test ini.equilibrium.R0 == 2.5
    @test_throws ErrorException ini.equilibrium.R0 = 1.0 ↔ [1.2, 2.5]
    @test_throws ErrorException ini.equilibrium.R0 = 3.0 ↔ [1.2, 2.5]

    ini = ParametersInits{Int}()
    ini.equilibrium.R0 = 2 ↔ [1, 3]
    @test ini.equilibrium.R0 == 2
    ini.equilibrium.R0 = 2.0 ↔ [1, 3]
    @test ini.equilibrium.R0 == 2
    ini.equilibrium.R0 = 1 ↔ [1, 3]
    @test ini.equilibrium.R0 == 1
    ini.equilibrium.R0 = 3 ↔ [1, 3]
    @test ini.equilibrium.R0 == 3
    @test_throws ErrorException ini.equilibrium.R0 = 0 ↔ [1, 3]
    @test_throws ErrorException ini.equilibrium.R0 = 4 ↔ [1, 3]

    ini = ParametersInits{Bool}()
    ini.equilibrium.R0 = 0 ↔ [0, 1]
    @test ini.equilibrium.R0 == 0
    ini.equilibrium.R0 = 0.5 ↔ [0, 1]
    @test ini.equilibrium.R0 == 0
    ini.equilibrium.R0 = 0.0 ↔ [0, 1]
    @test ini.equilibrium.R0 == 0
    ini.equilibrium.R0 = 1.0 ↔ [0, 1]
    @test ini.equilibrium.R0 == 1
    @test_throws ErrorException ini.equilibrium.R0 = -1 ↔ [0, 1]
    @test_throws ErrorException ini.equilibrium.R0 = 2 ↔ [0, 1]

    @test opt_parameters(ini) == AbstractParameter[getfield(ini.equilibrium, :R0)]
end

@testset "ConcreteTypes" begin
    ini = ParametersInits()
    ini.equilibrium.R0 = 5.0

    function test_me(ini)
        return ini.equilibrium.R0
    end

    test_me(ini)
    @code_warntype test_me(ini)
end