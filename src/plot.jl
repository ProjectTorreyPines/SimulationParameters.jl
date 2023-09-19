using RecipesBase

@recipe function plot_pars(pars::AbstractParameters)
    N = 0
    for par in leaves(pars)
        if typeof(par.value) <: Function
            N += 1
        end
    end

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

@recipe function plot_pars(par::AbstractParameter)
    time = top(par).time
    time_range = time.pulse_shedule_time_basis
    time0 = time.simulation_start
    @series begin
        xlim := (time_range[1], time_range[end])
        par.value
    end
    @series begin
        seriestype := :scatter
        primary := false
        marker := :dot
        markerstrokewidth := 0.0
        title := join(path(par)[2:end], ".")
        link := :x
        ylabel := "[$(par.units)]"
        xlabel := "[s]"
        [time0], [par.value(time0)]
    end
end