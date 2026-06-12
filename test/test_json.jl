# JSON serialization of non-finite floats across JSON.jl v0.21 and v1.
# v1 throws on NaN/Infinity/-Infinity (parse and write) unless allownan=true,
# while v0.21 parsed them by default and wrote them as `null`.

using SimulationParameters
using Test

import SimulationParameters: JSON

const JSON_IS_V1 = pkgversion(JSON) >= v"1"

Base.@kwdef mutable struct JSONTestParameters__phys{T<:Real} <: AbstractParameters{T}
    _parent::WeakRef = WeakRef(nothing)
    _name::Symbol = :phys
    nan_scalar::Entry{T} = Entry{T}("-", "scalar holding NaN")
    inf_scalar::Entry{T} = Entry{T}("-", "scalar holding Inf")
    ninf_scalar::Entry{T} = Entry{T}("-", "scalar holding -Inf")
    finite_scalar::Entry{T} = Entry{T}("-", "scalar holding a finite value")
    mixed_vector::Entry{Vector{Float64}} = Entry{Vector{Float64}}("-", "vector with non-finite elements")
end

mutable struct JSONTestParameters{T<:Real} <: AbstractParameters{T}
    _parent::WeakRef
    _name::Symbol
    phys::JSONTestParameters__phys{T}
end

function JSONTestParameters()
    par = JSONTestParameters{Float64}(WeakRef(nothing), :jsontest, JSONTestParameters__phys{Float64}())
    setup_parameters!(par)
    return par
end

@testset "json_nonfinite" begin
    @info "json_nonfinite testset running with JSON.jl v$(pkgversion(JSON))"

    @testset "parse non-finite tokens" begin
        # IMAS-convention JSON, as written by FUSE/IMASdd environments
        json_string = """
        {
            "phys": {
                "nan_scalar": NaN,
                "inf_scalar": Infinity,
                "ninf_scalar": -Infinity,
                "finite_scalar": 1.5,
                "mixed_vector": [1.0, NaN, Infinity, -Infinity, 2.5]
            }
        }
        """
        par = jstr2par(json_string, JSONTestParameters())
        @test isnan(par.phys.nan_scalar)
        @test par.phys.inf_scalar == Inf
        @test par.phys.ninf_scalar == -Inf
        @test par.phys.finite_scalar == 1.5
        @test isequal(par.phys.mixed_vector, [1.0, NaN, Inf, -Inf, 2.5])
    end

    @testset "write non-finite values" begin
        par = JSONTestParameters()
        par.phys.nan_scalar = NaN
        par.phys.inf_scalar = Inf
        par.phys.ninf_scalar = -Inf
        par.phys.finite_scalar = 1.5
        par.phys.mixed_vector = [1.0, NaN, Inf, -Inf, 2.5]

        # must not throw on either JSON version
        json_string = par2jstr(par)
        @test json_string isa String

        if JSON_IS_V1
            # v1 writes IMAS-convention tokens, so the roundtrip preserves values
            @test contains(json_string, "NaN")
            @test contains(json_string, "Infinity")
            par2 = jstr2par(json_string, JSONTestParameters())
            @test isnan(par2.phys.nan_scalar)
            @test par2.phys.inf_scalar == Inf
            @test par2.phys.ninf_scalar == -Inf
            @test par2.phys.finite_scalar == 1.5
            @test isequal(par2.phys.mixed_vector, [1.0, NaN, Inf, -Inf, 2.5])
        else
            # v0.21 writes non-finite floats as null; on load a null scalar is skipped (stays missing)
            @test contains(json_string, "null")
            par_scalar = JSONTestParameters()
            par_scalar.phys.nan_scalar = NaN
            par_scalar.phys.finite_scalar = 1.5
            par2 = jstr2par(par2jstr(par_scalar), JSONTestParameters())
            @test ismissing(par2.phys, :nan_scalar)
            @test par2.phys.finite_scalar == 1.5
        end
    end

    @testset "par2json/json2par file roundtrip" begin
        par = JSONTestParameters()
        par.phys.finite_scalar = 2.5
        if JSON_IS_V1
            par.phys.nan_scalar = NaN
        end
        filename = tempname() * ".json"
        try
            par2json(par, filename)
            par2 = json2par(filename, JSONTestParameters())
            @test par2.phys.finite_scalar == 2.5
            if JSON_IS_V1
                @test isnan(par2.phys.nan_scalar)
            end
        finally
            isfile(filename) && rm(filename)
        end
    end
end
