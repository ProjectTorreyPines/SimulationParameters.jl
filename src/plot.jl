using RecipesBase
using Printf
import Plots
"""
    plot_pars(pars::AbstractParameters)

Plot time dependent parameters in a plot layout
"""
@recipe function plot_pars(pars::AbstractParameters)
    N = 0
    for par in leaves(pars)
        if typeof(par.value) <: Union{TimeData,Function}
            N += 1
        end
    end

    if N > 0
        layout := @layout [N]
        k = 0
        for par in leaves(pars)
            if typeof(par.value) <: Union{TimeData,Function}
                k += 1
                @series begin
                    label := ""
                    subplot := k
                    par
                end
            end
        end
    end
end

@recipe function plot_opt_function(opt::OptParameterFunction; t_range=range(opt.t_range[1], opt.t_range[2], 100), bounds_on_nominal=true)
    t_range0 = t_range
    @series begin
        t_range0, opt.nominal.(t_range0)
    end

    t_range = collect(t_range)
    t_range[t_range.<opt.t_range[1].||t_range.>opt.t_range[2]] .= NaN
    @series begin
        primary := false
        alpha := 0.5
        linewidth := 0
        if bounds_on_nominal
            fillrange := opt.nominal.(t_range) .+ opt.lower.(t_range)
            t_range, opt.nominal.(t_range) .+ opt.upper.(t_range)
        else
            fillrange := opt.lower.(t_range)
            t_range, opt.upper.(t_range)
        end
    end
end

"""
    plot_par(par::AbstractParameter; time0=global_time(par), t_range=time_range(par))

Plot individual time dependent parameter
"""
@recipe function plot_par(par::AbstractParameter; time0=global_time(par), t_range=time_range(par))
    @assert typeof(time0) <: Float64
    @assert typeof(t_range) <: Union{AbstractVector{<:Float64},AbstractRange{<:Float64}} "must specify a `t_range=range(...)` to plot $(spath(par))"

    if typeof(par.value) <: Function
        time = t_range
        time_data = par.value.(t_range)
    elseif typeof(par.value) <: TimeData
        time = par.value.time
        time_data = par.value.data
    else
        error("Parameter $(spath(par)) is not defined as a time dependent function")
    end

    # data at time0
    if !isnan(time0)
        data0 = par.value(time0)
    end

    # encoding for non-numerical data
    if eltype(time_data) <: Number
        yticks = :auto
    else
        time_data, mapping = encode_array(time_data)
        if !isnan(time0)
            data0 = findfirst(x -> x == data0, mapping)
        end
        yticks = (collect(keys(mapping)), collect(values(mapping)))
    end

    # plot time trace
    @series begin
        xlim := (t_range[1], t_range[end])
        yticks := yticks
        label --> ""
        time, time_data
    end

    # shaded area for time-optimization parameters
    if par.opt !== missing
        @series begin
            ls := :dash
            primary := false
            par.opt
        end
    end

    # dot at current time
    if !isnan(time0)
        @series begin
            seriestype := :scatter
            primary := false
            marker := :circle
            markerstrokewidth := 0.0
            title := replace(spath(path(par)[2:end]), "𝚶"=>"O")
            titlefontsize := 8
            link := :x
            ylabel := "[$(par.units)]"
            xlabel := "[s]"
            yticks := yticks
            [time0], [data0]
        end
    end
end

@recipe function plot_par(pars::AbstractParameters, field::Symbol)
    @series begin
        getfield(pars, field)
    end
end

mutable struct CollectedParameter{T}
    parameter::AbstractParameter
    values::Vector{T}
end

function grouping_multi_parameters(multi_pars::Vector{<:AbstractParameter})
    collected = CollectedParameter[]

    # Dictionaries to store values and the corresponding parameter for each key
    values_map = Dict{String, Vector{<:Real}}()
    parameter_map = Dict{String, AbstractParameter}()

    # Iterate over each vector of parameters
    for par in multi_pars
        key_name = spath(par)
        if typeof(par.value) <: Real
            push!(get!(values_map, key_name, Vector{Real}()), par.value)
        elseif typeof(par.value) <: Symbol
            idx = findfirst(par.opt.choices.==par.value)
            isempty(idx) ? error("$(spath(par)) value $(par.value) not found in $(par.opt.choices)") : nothing

            push!(get!(values_map, key_name, Vector{Real}()),idx)
        end
        parameter_map[key_name] = par
    end

    # Build the collected parameters vector from the dictionaries
    sorted_keys = sort(collect(keys(values_map)))
    for key in sorted_keys
        push!(collected, CollectedParameter(parameter_map[key], values_map[key]))
    end

    return collected
end

@recipe function plot_CollectedParameters(CPs::Vector{CollectedParameter}; nrows=:auto, ncols=:auto, each_size=(500, 400))

    layout_val, size_val = compute_layout(length(CPs), nrows, ncols, each_size, plotattributes)
    layout := layout_val
    size := size_val
    left_margin --> [10 * Plots.Measures.mm 10 * Plots.Measures.mm]
    bottom_margin --> 10 * Plots.Measures.mm
    legend_position --> :best

    # legend_foreground_color := :red
    for (k, CP) in pairs(CPs)
        @series begin
            subplot := k
            CP
        end
    end
end

@recipe function plot_CollectedParameter(CP::CollectedParameter)
    @series begin
        CP.parameter, CP.values
    end
end

@recipe function plot_parameters_multi(pars_vec_vec::Vector{<:Vector{<:AbstractParameter}})
    collected_parameters = grouping_multi_parameters(reduce(vcat,pars_vec_vec))
    @series begin
        collected_parameters
    end
end

@recipe function plot_parameters(pars_vec::Vector{<:AbstractParameter})
    collected_parameters = grouping_multi_parameters(pars_vec)
    @series begin
        collected_parameters
    end
end

@recipe function plot_Entry(ety::Entry, multi_values::Vector{<:Real}=[])

    title --> spath(ety)
    yguide --> "Probability Density"

    if ety.opt isa Union{OptParameterRange,OptParameterDistribution}
        xtickfontsize --> 10
        ytickfontsize --> 10
        @series begin
            ety.opt
        end

        if isempty(multi_values)
            x_vals = [ety.value]
        else
            x_vals = multi_values
        end

        if ety.opt isa OptParameterRange
            y_vals = ones(size(x_vals)).*[1.0./(ety.opt.upper-ety.opt.lower)]
            ylims--> (0, 1.5*maximum(y_vals))
        elseif ety.opt isa OptParameterDistribution
            y_vals = Distributions.pdf.(ety.opt.dist, x_vals)
            ylims--> (0, 1.3*maximum(y_vals))
        end

        if get(plotattributes, :flag_sampled_label, true)
            if length(multi_values)==1
                label_name = "sampled value (≈"*@sprintf("%.3g",ety.value)*")"
            else
                label_name = "$(length(x_vals)) samples"
            end
        end

        if length(x_vals) <= 100
            @series begin
                seriestype --> :scatter
                marker --> :circle
                markersize --> compute_marker_size(length(multi_values))
                markeralpha --> compute_marker_alpha(length(multi_values))
                markercolor --> :blue
                label --> label_name
                x_vals, y_vals
            end
        end

        if length(x_vals) >= 20

            nbins = min(30, ceil(Int,length(x_vals)/5))
            my_bin_edges = range(minimum(x_vals), stop=maximum(x_vals), length=nbins+1)
            @series begin
                seriestype --> :histogram
                normalize --> :pdf
                bins --> my_bin_edges
                color --> :green
                alpha --> 0.4
                label --> label_name
                label --> ""
                z_order --> 1
                ylims := (0, :auto)
                x_vals
            end
        end

    elseif ety.opt isa OptParameterChoice
        yguide := "Counts"
        xtickfontsize --> 14
        ytickfontsize --> 10
        if isempty(multi_values)
            N_choices = length(ety.opt.choices)
            counts_vec = zeros(Int, N_choices)
            counts_vec[findfirst(ety.opt.choices.==ety.value)] = 1
        else
            counts_vec = [count(==(idx), multi_values) for idx in 1:length(ety.opt.choices)]
        end

        @series begin
            ety.opt, counts_vec
        end
    end
end

@recipe function plot_Switch(sw::Switch, multi_values::Vector{<:Real}=[])
    title --> spath(sw)
    yguide := "Counts"
    if isempty(multi_values)
        N_choices = length(sw.opt.choices)
        counts_vec = zeros(Int, N_choices)
        counts_vec[findfirst(sw.opt.choices.==sw.value)] = 1
    else
        counts_vec = [count(==(idx), multi_values) for idx in 1:length(sw.opt.choices)]
    end

    xtickfontsize --> 14
    ytickfontsize --> 10
    @series begin
        sw.opt, counts_vec
    end
end


@recipe function plot_OptParameterChoice(opt::OptParameterChoice, Nsamples::Int=1)
    N_choices = length(opt.choices)

    xlims --> (0.5, N_choices+0.5)
    ylims --> (0, min(1.0, 1.5/N_choices))
    yguide := "Counts"

    xticks --> (1:N_choices, opt.choices)

    xtickfontsize --> 14
    ytickfontsize --> 10

    if get(plotattributes, :flag_pdf, true)
        @series begin
            seriestype --> :hline
            linewidth --> 3.5
            color --> :red
            label --> "PDF"
            [1/N_choices]*Nsamples
        end
    end

    nominal_value = findfirst(opt.choices.==opt.nominal)
    @series begin
        if get(plotattributes, :flag_nominal_label, true)
            label --> "nominal value ($(opt.nominal))"
        else
            label --> ""
        end
        nominal_value, Val{:nominal}
    end
end

@recipe function plot_OptParameterChoice_with_counts(opt::OptParameterChoice, counts_vec::Vector{<:Integer})

    N_choices = length(opt.choices)

    xlims --> (0.5, N_choices+0.5)
    ylims --> (0, 1.3*maximum(counts_vec))
    xticks --> (1:N_choices, opt.choices)

    annotations --> [ (i, 0.5*v , Plots.text(string(v), :center, 10, "black")) for (i, v) in enumerate(counts_vec) if v > 0]
    @series begin
        seriestype --> :bar
        label --> ""
        bar_width --> 0.3
        fillalpha --> 0.6
        z_order --> 1
        1:N_choices, counts_vec
    end

    @series begin
        opt, sum(counts_vec)
    end
end

@recipe function plot_nominal_value(value::Real, ::Type{Val{:nominal}})
    @series begin
        seriestype --> :vline
        if get(plotattributes, :flag_nominal_label, true)
            label --> "nominal value (≈"*@sprintf("%.3g",value)*")"
        else
            label --> ""
        end
        linestyle --> :dash
        linewidth --> 1.5
        color --> :gray
        [value]
    end
end


@recipe function plot_OptParameterRange(opt::OptParameterRange)

    uniform_pdf_val = 1.0./(opt.upper-opt.lower)

    xx = [opt.lower, opt.lower, opt.upper, opt.upper]
    yy = [0.0, uniform_pdf_val, uniform_pdf_val, 0.0]

    ylims --> (0, :auto)
    yguide --> "Probability Density"

    xtickfontsize --> 10
    ytickfontsize --> 10

    if get(plotattributes, :flag_pdf, true)
        @series begin
            linewidth --> 3.5
            color --> :red
            label --> "PDF"
            ylims --> (0, :auto)
            xx, yy
        end
    end

    @series begin
        opt.nominal, Val{:nominal}
    end
end


@recipe function plot_OptParameterDistribution(opt::OptParameterDistribution)

    lbound = isfinite(opt.dist.lower) ? opt.dist.lower : Distributions.quantile(opt.dist, 0.001)
    rbound = isfinite(opt.dist.upper) ? opt.dist.upper : Distributions.quantile(opt.dist, 0.999)

    xx = collect(range(lbound, rbound, length=200))
    yy = Distributions.pdf(opt.dist, xx)

    xx = isfinite(opt.dist.lower) ? vcat(opt.dist.lower, xx) : xx
    yy = isfinite(opt.dist.lower) ? vcat(0.0, yy) : yy
    xx = isfinite(opt.dist.upper) ? vcat(xx, opt.dist.upper) : xx
    yy = isfinite(opt.dist.upper) ? vcat(yy, 0.0) : yy

    xtickfontsize --> 10
    ytickfontsize --> 10

    ylims --> (0, :auto)
    yguide --> "Probability Density"
    if get(plotattributes, :flag_pdf, true)
        @series begin
            linewidth --> 3.5
            color --> :red
            label --> "PDF"
            xx, yy
        end
    end

    @series begin
        opt.nominal, Val{:nominal}
    end
end

function compute_layout(Nlength, nrows, ncols, each_size, plotattributes)
    my_layout = get(plotattributes, :layout) do
        # Fallback: Compute my_layout using nrows or ncols if provided
        layout_spec = Nlength
        if nrows !== :auto && ncols == :auto
            layout_spec = (layout_spec, (nrows, :))
        elseif ncols !== :auto && nrows == :auto
            layout_spec = (layout_spec, (:, ncols))
        elseif nrows !== :auto || ncols !== :auto
            layout_spec = (layout_spec, (nrows, ncols))
        end
        return Plots.layout_args(layout_spec...)
    end

    # Define layout and compute nrows & ncols
    if my_layout isa Tuple{Plots.GridLayout,Int}
        layout_val = (nrows == :auto && ncols == :auto) ? my_layout[2] : my_layout[1]
        nrows_val = size(my_layout[1].grid)[1]
        ncols_val = size(my_layout[1].grid)[2]
    elseif my_layout isa Plots.GridLayout
        layout_val = my_layout
        nrows_val = size(my_layout.grid)[1]
        ncols_val = size(my_layout.grid)[2]
    elseif my_layout isa Int
        layout_val = my_layout
        tmp_grid = Plots.layout_args(plotattributes, my_layout)[1].grid
        nrows_val = size(tmp_grid)[1]
        ncols_val = size(tmp_grid)[2]
    else
        error("Unsupported layout type")
    end

    size_val = (ncols_val * each_size[1], nrows_val * each_size[2])
    return layout_val, size_val
end

function compute_marker_size(nsample::Integer; max_size::Float64=15.0, min_size::Float64=7.0, max_Nsample::Integer=60)
    s = max_size - (max_size-min_size)/max_Nsample* nsample
    return clamp(s, min_size, max_size)
end

function compute_marker_alpha(nsample::Integer; max_α::Float64=0.6, min_α::Float64=0.15, max_Nsample::Integer=60)
    a = max_α - (max_α-min_α)/max_Nsample * nsample
    return clamp(a, min_α, max_α)
end