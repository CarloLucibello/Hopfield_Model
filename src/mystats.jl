
struct MyStats <: OnlineStat{Union{NamedTuple, AbstractDict{Symbol}}}
    _stats::OrderedDict{Symbol, OnlineStat}
end

function MyStats()
    stats = OrderedDict{Symbol, Any}()
    return MyStats(stats)
end

Base.getindex(s::MyStats, k::Symbol) = getindex(s._stats, k)
Base.keys(s::MyStats) = keys(s._stats)
Base.pairs(s::MyStats) = pairs(s._stats)
Base.setindex!(s::MyStats, v, k::Symbol) = setindex!(s._stats, v, k)
Base.haskey(s::MyStats, k::Symbol) = haskey(s._stats, k)
Base.length(s::MyStats) = length(s._stats)
Base.values(s::MyStats) = values(s._stats)


function Base.getproperty(s::MyStats, k::Symbol)
    if hasfield(MyStats, k)
        return getfield(s, k)
    else
        return getindex(s, k)
    end
end

function OnlineStats._fit!(s::MyStats, x::Union{NamedTuple, AbstractDict{Symbol}})
    for (k, v) in pairs(x)
        if !haskey(s, k)
            s[k] = _init_stat()
        end
        OnlineStats.fit!(s[k], v)
    end
end

_init_stat() = Series(Mean(), Variance())

Base.empty!(s::MyStats) = s._stats = OrderedDict{Symbol, Any}()

function OnlineStats._merge!(s1::MyStats, s2::MyStats)
    for (k, v) in pairs(s2._stats)
        if !haskey(s1, k)
            s1[k] = v
        end
        OnlineStats.merge!(s1[k], v)
    end
end

OnlineStats.nobs(s::MyStats) = length(s._stats) > 0 ? OnlineStats.nobs(first(values(s))) : 0

OnlineStats.value(s::MyStats) = Statistics.mean(s)

Statistics.mean(s::MyStats) = OrderedDict(k => OnlineStats.value(v.stats[1]) for (k,v) in pairs(s))
Statistics.var(s::MyStats) = OrderedDict(k => OnlineStats.value(v.stats[2]) for (k,v) in pairs(s))

function mean_with_err(s::MyStats)
    d = OrderedDict{Symbol,Any}()
    for (k, v) in pairs(s)
        d[k] = OnlineStats.value(v.stats[1])
        d[Symbol(k, "_err")] = sqrt(OnlineStats.value(v.stats[2]) / v.stats[2].n)
    end
    return d
end

Base.show(io::IO, s::MyStats) = show(io, s._stats)

# Binary op interface for reduce/mapreduce
function (s::MyStats)(x, y)
    OnlineStats.fit!(s, x)
    OnlineStats.fit!(s, y)
    return s
end

# Binary op interface for reduce/mapreduce
function (s::MyStats)(x::MyStats, y)
    @assert s === x
    OnlineStats.fit!(s, y)
    return s
end


## UTiLS #######

function DrWatson.dict_list(od::OrderedDict)
    d = Dict(od)
    dlist = dict_list(d)
    return [OrderedDict((k => d[k] for k in keys(od))...) for d in dlist]
end


"""
Check if a file with the name exists, if so, append a number to the name.
"""
function check_filename(filename)
    mkpath(dirname(filename))
    i = 1
    _filename = filename
    while isfile(_filename)
        i += 1
        _filename = filename * "." * string(i)
    end
    filename = _filename
    return filename
end

