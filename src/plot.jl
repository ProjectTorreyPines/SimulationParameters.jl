using RecipesBase

"""
    plot_pars(pars::AbstractParameters)

Plot time dependent parameters in a plot layout
"""
@recipe function plot_pars(pars::AbstractParameters)
    N = 0
    for par in leaves(pars)
        if typeof(par.value) <: Function
            N += 1
        end
    end

    if N > 0
        layout := @layout [N]
        k = 0
        for par in leaves(pars)
            if typeof(par.value) <: Function
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
    plot_par(par::AbstractParameter)

Plot individual time dependent parameter
"""
@recipe function plot_par(par::AbstractParameter)
    time = top(par).time
    t_range = time.pulse_shedule_time_basis
    time0 = time.simulation_start

    time_data = par.value.(t_range)
    if eltype(time_data) <: Number
        data0 = par.value(time0)
        yticks = :auto
    else
        time_data, mapping = encode_array(time_data)
        data0 = mapping[par.value(time0)]
        yticks = (collect(values(mapping)), collect(keys(mapping)))
    end
    @series begin
        xlim := (t_range[1], t_range[end])
        yticks := yticks
        label --> ""
        t_range, time_data
    end
    if par.opt !== missing
        @series begin
            ls := :dash
            primary := false
            par.opt
        end
    end
    @series begin
        seriestype := :scatter
        primary := false
        marker := :dot
        markerstrokewidth := 0.0
        title := spath(path(par)[2:end])
        titlefontsize := 8
        link := :x
        ylabel := "[$(par.units)]"
        xlabel := "[s]"
        yticks := yticks
        [time0], [data0]
    end
end
