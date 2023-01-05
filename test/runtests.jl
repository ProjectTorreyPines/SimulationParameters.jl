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
        ], "", "Initialize run from")
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
    par = ParametersInits()

    println(getfield(par.equilibrium, :casename))

    @test typeof(par.equilibrium) <: AbstractParameters

    @test_throws NotsetParameterException par.equilibrium.R0

    par.equilibrium.R0 = 1.0
    @test par.equilibrium.R0 == 1.0

    ini = ParametersInits()
    ini1 = ParametersInits()

    @test_throws Exception par.equilibrium.R0 = "a string"

    par.equilibrium.R0 = missing
    @test_throws NotsetParameterException par.equilibrium.R0

    @test_throws InexistentParameterException par.equilibrium.does_not_exist = 1.0

    @test fieldnames(typeof(par.equilibrium)) == fieldnames(typeof(FUSEparameters__equilibrium{Float64}()))

    @test typeof(ini) <: AbstractParameters

    ini.equilibrium.R0 = 5.3
    @test ini.equilibrium.R0 == 5.3

    @test (ini.equilibrium.init_from = :ods) == :ods

    @test_throws BadParameterException ini.equilibrium.init_from = :odsa

    # save load
    dict2par!(par2dict(ini), ParametersInits())
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