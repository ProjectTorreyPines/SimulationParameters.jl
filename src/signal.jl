import Symbolics

Symbolics.@variables t
const tt = t

function flat(t)
    return t * 0 + 1
end

function line(t)
    return t
end

function step(t)
    return t >= 0.0
end

function pulse(t)
    a = step(t)
    b = step(-t + 1)
    return a * b
end

function ramp(t)
    a = t * (t < 1) * (t > 0)
    b = t >= 1
    y = a + b
    return y
end

function trap(t, n)
    @assert 0 <= n <= 1 "trap flat must be between [0,1]"
    k = 1 / ((1 - n) / 2)
    if n == 1.0
        return pulse(t)
    else
        a = ramp(t * k) * (t < 0.5)
        b = ramp(-t * k + k) * (t >= 0.5)
        return a + b
    end
end

function signal(f_t, time)
    data = similar(time)
    for k in eachindex(time)
        data[k] = Symbolics.value.(Symbolics.substitute.(f_t, tt => time[k]))
    end
    time, data
end

function sparse_signal(f_t::Symbolics.Num, time::AbstractVector{Float64}, precision::Float64=1E-4)
    data = similar(time)
    for k in eachindex(time)
        data[k] = Symbolics.value.(Symbolics.substitute.(f_t, tt => time[k]))
    end
    return sparse_signal(time, data, precision)
end

function sparse_signal(time::AbstractVector{Float64}, data::AbstractVector{<:Real}, precision::Float64=1E-4)
    sparse_time = similar(time)
    sparse_data = similar(data)

    m, M = extrema(data)

    n = 0
    change = false
    for k in eachindex(time)
        if n < 2
            n += 1
        else
            extr_grad = (sparse_data[n] - sparse_data[n-1]) / (sparse_time[n] - sparse_time[n-1])
            extr_val = extr_grad * (time[k] - sparse_time[n]) + sparse_data[n]
            if abs(data[k] - extr_val) / (M - m) < precision || change
                change = false
            else
                n += 1
                change = true
            end
        end
        sparse_time[n] = time[k]
        sparse_data[n] = data[k]
    end

    return sparse_time[1:n], sparse_data[1:n]
end
