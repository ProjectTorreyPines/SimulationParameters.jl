using RecipesBase
using Printf
import Measures

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
@recipe function plot_par(par::AbstractParameter, ::Missing; time0=global_time(par), t_range=time_range(par))
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
            title := replace(spath(path(par)[2:end]), "𝚶" => "O")
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

@recipe function plot_inis_acts(inis_and_acts::AbstractVector{<:AbstractParameters}...)
    GPs = grouping_parameters(inis_and_acts...)
    @series begin
        GPs
    end
end

@recipe function plot_GroupedParameters(GPs::Vector{GroupedParameter}; nrows=:auto, ncols=:auto, each_size=(500, 400))
    name = "Grouped Parameters"
    HelpPlots.assert_type_and_record_argument(name, Tuple{Integer,Integer}, "Size of each subplot. (Default=(500, 400))"; each_size)
    HelpPlots.assert_type_and_record_argument(name, Union{Integer,Symbol}, "Number of rows for subplots' layout (Default = :auto)"; nrows)
    HelpPlots.assert_type_and_record_argument(name, Union{Integer,Symbol}, "Number of columns for subplots' layout (Default = :auto)"; ncols)

    # Set overall plot attributes.
    left_margin --> [10 * Measures.mm 10 * Measures.mm]
    bottom_margin --> 10 * Measures.mm
    legend_position --> :best

    layout_val, size_val, total_cells = compute_layout(length(GPs), nrows, ncols, each_size, plotattributes)

    layout := layout_val
    size --> size_val

    # Now, add series: if a cell index exceeds length(GPs), create a blank series.
    for k in 1:total_cells
        if k <= length(GPs)
            @series begin
                subplot := k
                GPs[k]
            end
        else
            # Create a blank plot for empty grid cells.
            @series begin
                subplot := k
                label --> ""
                framestyle --> :none
                xticks --> ([], [])
                yticks --> ([], [])
                []  # Empty data produces no content.
            end
        end
    end
end

@recipe function plot_GroupedParameter(GP::GroupedParameter)
    @series begin
        GP.parameter, GP.values
    end
end

@recipe function plot_args_of_parameters(args::Union{AbstractVector{<:AbstractParameters},AbstractParameters}...)
    GPs = grouping_parameters(args...)
    @series begin
        GPs
    end
end

@recipe function plot_parameters_multi(pars_vec_vec::Vector{<:Vector{<:AbstractParameters}})
    GPs = grouping_parameters(pars_vec_vec)
    @series begin
        GPs
    end
end

@recipe function plot_parameters(pars_vec::Vector{<:AbstractParameter})
    GPs = grouping_parameters(pars_vec)
    @series begin
        GPs
    end
end

@recipe function plot_Entry(ety::Entry, multi_values::Vector{<:Real}=[])
    @series begin
        multi_values := multi_values
        ety, ety.opt
    end
end

@recipe function plot_Entry(ety::Entry, opt::OptParameterChoice, multi_values::Vector{<:Real}=[])
    yguide := "Counts"
    if isempty(multi_values)
        N_choices = length(ety.opt.choices)
        counts_vec = zeros(Int, N_choices)
        counts_vec[findfirst(opt.choices .== ety.value)] = 1
    else
        counts_vec = [count(==(idx), multi_values) for idx in 1:length(opt.choices)]
    end

    @series begin
        opt, counts_vec
    end
end

@recipe function plot_Entry(ety::Entry, opt::Union{OptParameterRange,OptParameterDistribution}, multi_values::Vector{<:Real}=[])
    if isempty(ety.units) || ety.units == "-"
        unit_name = ""
    else
        unit_name = "[$(ety.units)]"
    end
    title --> spath(ety) * " $unit_name"
    yguide --> "Probability Density"

    @series begin
        opt
    end

    if isempty(multi_values)
        x_vals = [ety.value]
    else
        x_vals = multi_values
    end

    if opt isa OptParameterRange
        y_vals = ones(size(x_vals)) .* [1.0 ./ (opt.upper - opt.lower)]
        ylims --> (0, 1.5 * maximum(y_vals))
    elseif opt isa OptParameterDistribution
        y_vals = Distributions.pdf.(opt.dist, x_vals)

        # Calculate maximum ylim to enusre that graph can show the whole distribution
        dist = opt.dist
        lower = Distributions.minimum(dist)
        upper = Distributions.maximum(dist)
        lbound = isfinite(lower) ? lower : Distributions.quantile(dist, 0.001)
        rbound = isfinite(upper) ? upper : Distributions.quantile(dist, 0.999)
        test_xx = collect(range(lbound, rbound; length=200))
        test_yy = Distributions.pdf.(dist, test_xx)

        ylims --> (0, 1.3 * maximum(test_yy))
    end

    if get(plotattributes, :flag_sampled_label, true)
        if length(multi_values) == 1
            label_name = "sampled value (≈" * @sprintf("%.3g", ety.value) * ")"
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
        nbins = min(30, ceil(Int, length(x_vals) / 5))
        my_bin_edges = range(minimum(x_vals); stop=maximum(x_vals), length=nbins + 1)
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
end

@recipe function plot_Switch(sw::Switch, multi_values::Vector{<:Real}=[])
    @series begin
        multi_values := multi_values
        sw, sw.opt
    end
end

@recipe function plot_Switch(sw::Switch, opt::OptParameterChoice, multi_values::Vector{<:Real}=[])
    if isempty(sw.units) || sw.units == "-"
        unit_name = ""
    else
        unit_name = "[$(sw.units)]"
    end
    title --> spath(sw) * " $unit_name"
    titlefontsize --> 16
    yguide := "Counts"
    if isempty(multi_values)
        N_choices = length(opt.choices)
        counts_vec = zeros(Int, N_choices)
        counts_vec[findfirst(opt.choices .== sw.value)] = 1
    else
        counts_vec = [count(==(idx), multi_values) for idx in 1:length(opt.choices)]
    end

    @series begin
        opt, counts_vec
    end
end

@recipe function plot_OptParameterChoice(opt::OptParameterChoice, Nsamples::Int=1)
    N_choices = length(opt.choices)

    xlims --> (0.5, N_choices + 0.5)
    ylims --> (0, min(1.0, 1.5 / N_choices))
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
            [1 / N_choices] * Nsamples
        end
    end

    nominal_value = findfirst(opt.choices .== opt.nominal)
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

    xlims --> (0.5, N_choices + 0.5)
    ylims --> (0, 1.3 * maximum(counts_vec))
    xticks --> (1:N_choices, opt.choices)

    annotations --> [(i, 0.5 * v, string(v)) for (i, v) in enumerate(counts_vec) if v > 0]
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
            label --> "nominal value (≈" * @sprintf("%.3g", value) * ")"
        else
            label --> ""
        end
        linestyle --> :dash
        linewidth --> 2.0
        color --> :gray
        [value]
    end
end

@recipe function plot_OptParameterRange(opt::OptParameterRange)
    uniform_pdf_val = 1.0 ./ (opt.upper - opt.lower)

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
    lower = Distributions.minimum(opt.dist)
    upper = Distributions.maximum(opt.dist)

    lbound = isfinite(lower) ? lower : Distributions.quantile(opt.dist, 0.001)
    rbound = isfinite(upper) ? upper : Distributions.quantile(opt.dist, 0.999)

    xx = collect(range(lbound, rbound; length=200))
    yy = Distributions.pdf.(opt.dist, xx)

    xx = isfinite(lower) ? vcat(lower, xx) : xx
    yy = isfinite(lower) ? vcat(0.0, yy) : yy
    xx = isfinite(upper) ? vcat(xx, upper) : xx
    yy = isfinite(upper) ? vcat(yy, 0.0) : yy

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
    if haskey(plotattributes, :layout)
        l = plotattributes[:layout]
        if l isa Int
            if l ≠ Nlength
                l = Nlength
                @warn "layout is automatically coverted to $(Nlength)"
            end
            nc = ceil(Int, sqrt(Nlength))
            nr = ceil(Int, Nlength / nc)
            total_cells = nc * nr
            layout_val = (nr, nc)
        elseif l isa Tuple{Int,Int}
            # Layout is given as (nrows, ncols)
            nr, nc = l
            layout_val = (nr, nc)
            total_cells = nr * nc
        elseif l isa Tuple && any(x -> x === :, l)
            # Fallback: assume l[1] and l[2] (which may be Colon)
            if l == (:, :)
                nc = ceil(Int, sqrt(Nlength))
                nr = ceil(Int, Nlength / nc)
            else
                nr = (l[1] isa Colon) ? ceil(Int, Nlength / l[2]) : l[1]
                nc = (l[2] isa Colon) ? ceil(Int, Nlength / l[1]) : l[2]
            end
            layout_val = (nr, nc)
            total_cells = nr * nc
        elseif l isa Matrix
            nr, nc = size(l)
            layout_val = l
            total_cells = nr * nc
        else
            # Unknown external layout; leave as is and default grid to one row.
            layout_val = l
            nc = ceil(Int, sqrt(Nlength))
            nr = ceil(Int, Nlength / nc)
            total_cells = nr * nc
        end
    else
        # However, if nrows or ncols are provided, use them.
        if nrows !== :auto || ncols !== :auto
            if nrows === :auto && ncols !== :auto
                nc = ncols
                nr = ceil(Int, Nlength / ncols)
            elseif ncols === :auto && nrows !== :auto
                nr = nrows
                nc = ceil(Int, Nlength / nrows)
            else
                nr, nc = nrows, ncols
            end
            layout_val = (nr, nc)
        else
            nc = ceil(Int, sqrt(Nlength))
            nr = ceil(Int, Nlength / nc)
            layout_val = (nr, nc)
        end
        total_cells = nc * nr
    end

    size_val = (nc * each_size[1], nr * each_size[2])

    return layout_val, size_val, total_cells
end

function compute_marker_size(nsample::Integer; max_size::Float64=15.0, min_size::Float64=7.0, max_Nsample::Integer=60)
    s = max_size - (max_size - min_size) / max_Nsample * nsample
    return clamp(s, min_size, max_size)
end

function compute_marker_alpha(nsample::Integer; max_α::Float64=0.6, min_α::Float64=0.15, max_Nsample::Integer=60)
    a = max_α - (max_α - min_α) / max_Nsample * nsample
    return clamp(a, min_α, max_α)
end