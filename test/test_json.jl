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
    int_scalar::Entry{Int} = Entry{Int}("-", "integer scalar")
    int_vector::Entry{Vector{Int}} = Entry{Vector{Int}}("-", "integer vector")
    f32_scalar::Entry{Float32} = Entry{Float32}("-", "Float32 scalar (narrower than JSON's Float64)")
    f32_vector::Entry{Vector{Float32}} = Entry{Vector{Float32}}("-", "Float32 vector")
    union_scalar::Entry{Union{Int64,Vector}} = Entry{Union{Int64,Vector}}("-", "Int-or-Vector (cf. act.ActorCoreRadHeatFlux.levels)")
    union_vector::Entry{Union{Int64,Vector}} = Entry{Union{Int64,Vector}}("-", "Int-or-Vector holding a vector")
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
                "mixed_vector": [1.0, NaN, Infinity, -Infinity, 2.5],
                "int_scalar": 101,
                "int_vector": [1, 2, 3],
                "f32_scalar": 1.25,
                "f32_vector": [1.25, 2.5],
                "union_scalar": 20
            }
        }
        """
        par = jstr2par(json_string, JSONTestParameters())
        @test isnan(par.phys.nan_scalar)
        @test par.phys.inf_scalar == Inf
        @test par.phys.ninf_scalar == -Inf
        @test par.phys.finite_scalar == 1.5
        @test isequal(par.phys.mixed_vector, [1.0, NaN, Inf, -Inf, 2.5])
        # JSON v1 with allownan=true parses all numbers as Float64 (JuliaIO/JSON.jl#397):
        # integer parameters must still decode to their declared type
        @test par.phys.int_scalar === 101
        @test par.phys.int_vector == [1, 2, 3] && par.phys.int_vector isa Vector{Int}
        # more generally, ANY Real field narrower than JSON's Float64 (e.g. Float32) must
        # decode to its declared type, not just Integer
        @test par.phys.f32_scalar === 1.25f0
        @test par.phys.f32_vector == Float32[1.25, 2.5] && par.phys.f32_vector isa Vector{Float32}
        # Union eltype: a scalar Int written for an Int-or-Vector field must decode to Int64,
        # not Float64 (reproduces FUSE act.ActorCoreRadHeatFlux.levels::Union{Int64, Vector})
        @test par.phys.union_scalar === 20
    end

    @testset "write non-finite values" begin
        par = JSONTestParameters()
        par.phys.nan_scalar = NaN
        par.phys.inf_scalar = Inf
        par.phys.ninf_scalar = -Inf
        par.phys.finite_scalar = 1.5
        par.phys.mixed_vector = [1.0, NaN, Inf, -Inf, 2.5]
        par.phys.int_scalar = 101
        par.phys.int_vector = [1, 2, 3]
        par.phys.f32_scalar = 1.25f0
        par.phys.f32_vector = Float32[1.25, 2.5]

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
            @test par2.phys.int_scalar === 101
            @test par2.phys.int_vector == [1, 2, 3] && par2.phys.int_vector isa Vector{Int}
            @test par2.phys.f32_scalar === 1.25f0
            @test par2.phys.f32_vector == Float32[1.25, 2.5] && par2.phys.f32_vector isa Vector{Float32}
        else
            # v0.21 writes non-finite floats as null; on load a null scalar is skipped (stays missing)
            @test contains(json_string, "null")
            par_scalar = JSONTestParameters()
            par_scalar.phys.nan_scalar = NaN
            par_scalar.phys.finite_scalar = 1.5
            par_scalar.phys.int_scalar = 101
            par2 = jstr2par(par2jstr(par_scalar), JSONTestParameters())
            @test ismissing(par2.phys, :nan_scalar)
            @test par2.phys.finite_scalar == 1.5
            @test par2.phys.int_scalar === 101
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

    @testset "full-tree JSON roundtrip (FUSE ini_json/act_json pattern)" begin
        # Mirrors FUSE's test_ini_act_save_load act_json/ini_json:
        #     str  = SimulationParameters.par2jstr(par)
        #     par2 = SimulationParameters.jstr2par(str, fresh())
        # Populating a tree with the types that broke FUSE lets SimulationParameters catch the
        # JSON-v1 Float64-flattening regressions (Int, Float32, Union{Int,Vector}) in its own
        # ~1-minute test suite, instead of only in FUSE's hours-long CI.
        par = JSONTestParameters()
        par.phys.finite_scalar = 1.5
        par.phys.int_scalar = 101
        par.phys.int_vector = [1, 2, 3]
        par.phys.f32_scalar = 1.25f0
        par.phys.f32_vector = Float32[1.25, 2.5]
        par.phys.union_scalar = 20            # Int side of Union{Int64, Vector}
        par.phys.union_vector = [4, 5, 6]     # Vector side of the same field
        if JSON_IS_V1
            par.phys.nan_scalar = NaN
            par.phys.mixed_vector = [1.0, NaN, Inf, -Inf, 2.5]
        end

        # the round-trip must not throw, and must preserve each declared type
        par2 = jstr2par(par2jstr(par), JSONTestParameters())
        @test par2.phys.finite_scalar === 1.5
        @test par2.phys.int_scalar === 101
        @test par2.phys.int_vector == [1, 2, 3] && par2.phys.int_vector isa Vector{Int}
        @test par2.phys.f32_scalar === 1.25f0
        @test par2.phys.f32_vector == Float32[1.25, 2.5] && par2.phys.f32_vector isa Vector{Float32}
        @test par2.phys.union_scalar === 20
        @test par2.phys.union_vector == [4, 5, 6] && par2.phys.union_vector isa Vector
    end
end
