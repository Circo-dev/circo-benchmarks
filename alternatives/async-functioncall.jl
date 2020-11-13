using BenchmarkTools
import Base.Threads.@spawn # Seems it is the same as @async when "--threads 1"

const N = 10
const fn = x -> 2x

function channelize(calcfn)
    return (input, output)->begin
        while true
            data = take!(input)
            put!(output, calcfn(data))
        end
    end
end

function createcalc(channel_length = 1)
    source, target = (Channel{Int64}(channel_length) for i = 1:2)
    @spawn channelize(fn)(source, target)
    return source, target
end

function runcalc(source, target; N = N)
    @spawn begin
        for i = 1:N
            put!(source, i)
        end
    end
    @spawn begin
        sum = 0
        for i = 1:N
            sum += take!(target)
        end
        return sum
    end
end

function runasync(fn; N = N)
    sum = 0
    for i = 1:N
        sum += fetch(@async fn(i))
    end
    return sum
end

@info "@async:"
@btime runasync(fn)

for channel_length in (0, 1, 2, 4, 8, 16, Inf)
    @info "---"
    @info "Channel length: $channel_length"
    @btime fetch(runcalc(params...)) setup = (params = createcalc($channel_length))
end
