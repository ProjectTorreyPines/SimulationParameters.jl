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

"""
    plot_par(par::AbstractParameter)

Plot individual time dependent parameter
"""
@recipe function plot_par(par::AbstractParameter)
    time = top(par).time
    time_range = time.pulse_shedule_time_basis
    time0 = time.simulation_start

    time_data = par.value.(time_range)
    if eltype(time_data) <: Number
        data0 = par.value(time0)
        yticks = :auto
    else
        time_data, mapping = encode_array(time_data)
        data0 = mapping[par.value(time0)]
        yticks = (collect(values(mapping)), collect(keys(mapping)))
    end
    @series begin
        xlim := (time_range[1], time_range[end])
        yticks := yticks
        time_range, time_data
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
