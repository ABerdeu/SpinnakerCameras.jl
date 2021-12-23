#
# times.jl --
#
# Methods related to time for the Julia interface to the C libraries of TAO, a
# Toolkit for Adaptive Optics.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

import Base.Libc: TimeVal

"""
    TaoBindings.current_time()

yields the current time since the
[Epoch](https://en.wikipedia.org/wiki/Unix_time), that is 00:00:00 UTC, 1
January 1970.

See also [`TaoBindings.monotonic_time`](@ref).

""" current_time

"""
    TaoBindings.monotonic_time()

yields a monotonic time since some unspecified starting point but which is not
affected by discontinuous jumps in the system time (e.g., if the system
administrator manually changes the clock), but is affected by the incremental
adjustments performed by adjtime() and NTP.

See also [`TaoBindings.current_time`](@ref).

""" monotonic_time

for func in (:current_time, :monotonic_time)
    @eval function $func()
        t = Ref{HighResolutionTime}()
        _check(ccall(($(string("tao_get_",func)), taolib), Status,
                     (Ptr{HighResolutionTime},), t))
        return t[]
    end
end

"""
    @normalizetime(ipvar, fpvar, m)

yields the code to normalize the time specified by the integer variables
`ipvar` and `fpvar` with the numbers of seconds and of fraction of seconds; the
literal integer `m` is such that `fpvar` is in second/`m`.

"""
macro normalizetime(ipvar, fpvar, m)
    @assert isa(ipvar, Symbol)
    @assert isa(fpvar, Symbol)
    @assert isa(m, Integer)
    ip = esc(ipvar)
    fp = esc(fpvar)
    quote
        local fm = convert(typeof($fp), $m)
        $ip += convert(typeof($ip), div($fp, fm))
        $fp = rem($fp, fm)
        if $fp < 0
            $ip -= one($ip)
            $fp += fm
        end
    end
end

for T in (:HighResolutionTime, :TimeSpec)
    @eval begin

        $T(tv::TimeVal) = $T(tv.sec, 1_000*tv.usec)

        $T(secs::Integer) = $T(secs, 0)

        function $T(secs::AbstractFloat)
            if isnan(secs)
                return $T(0, -1)
            else
                # Compute the number of seconds and nanoseconds, rounding to
                # the nearest number of nanoseconds.  Then, normalize the
                # number of seconds and nanoseconds.
                fs = floor(secs)
                if fs ≥ typemax(Ctime_t)
                    return $T(typemax(Ctime_t), 0)
                elseif fs ≤ typemin(Ctime_t)
                    return $T(typemin(Ctime_t), 0)
                else
                    sec = Ctime_t(fs)
                    nsec = round(_typeof_timespec_nsec,
                                 (secs - fs)*1E9) # result is ≥ 0
                    giga = convert(typeof(nsec), 1_000_000_000)
                    if nsec >= giga
                        sec += one(sec)
                        nsec -= giga
                    end
                    return $T(sec, nsec)
                end
            end
        end

    end
end

function TimeVal(t::AbstractHighResolutionTime)
    # Extract the number of seconds and microseconds (rounded to nearest).
    # Then, normalize the number of seconds and microseconds.
    sec, nsec = t.sec, t.nsec
    @normalizetime(sec, nsec, 1_000_000_000)
    usec = div(nsec + 500, 1_000) # microseconds rounded to nearest
    mega = convert(typeof(usec), 1_000_000)
    if usec >= mega
        sec += one(sec)
        usec -= mega
    end
    return TimeVal(sec, usec)
end

to_float(::Type{T}, t::AbstractHighResolutionTime) where {T<:AbstractFloat} =
    T(t.sec) + (T(1)/T(1_000_000_000))*T(t.nsec)

to_float(::Type{T}, tv::TimeVal) where {T<:AbstractFloat} =
    T(tv.sec) + (T(1)/T(1_000_000))*T(tv.usec)

# Extend some basic functions (not for TimeVal to avoid type-piracy).
Base.Float64(t::AbstractHighResolutionTime)::Float64 = to_float(Float64, t)
Base.Float32(t::AbstractHighResolutionTime)::Float32 = to_float(Float32, t)
Base.BigFloat(t::AbstractHighResolutionTime)::BigFloat = to_float(BigFloat, t)
Base.float(t::AbstractHighResolutionTime) = to_float(Float64, t)

Base.convert(::Type{T}, t::T) where {T<:AbstractHighResolutionTime} = t
Base.convert(::Type{T}, secs::Real) where {T<:AbstractHighResolutionTime} = T(secs)
Base.convert(::Type{T}, tv::TimeVal) where {T<:AbstractHighResolutionTime} = T(tv)
Base.convert(::Type{TimeVal}, t::AbstractHighResolutionTime) = TimeVal(t)
Base.convert(::Type{T}, t::AbstractHighResolutionTime) where {T<:AbstractHighResolutionTime} =
    T(t.sec, t.nsec)

Base.:(+)(t::AbstractHighResolutionTime) = t
Base.:(-)(t::T) where {T<:AbstractHighResolutionTime} = begin
    sec, nsec = -t.sec, -t.nsec
    @normalizetime(sec, nsec, 1_000_000_000)
    return T(sec, nsec)
end

Base.:(+)(t::T, secs::Real) where {T<:AbstractHighResolutionTime} = t + T(secs)
Base.:(-)(t::T, secs::Real) where {T<:AbstractHighResolutionTime} = t - T(secs)

Base.:(+)(a::T, b::T) where {T<:AbstractHighResolutionTime} = begin
    sec, nsec = a.sec + b.sec, a.nsec + b.nsec
    @normalizetime(sec, nsec, 1_000_000_000)
    return T(sec, nsec)
end

Base.:(-)(a::T, b::T) where {T<:AbstractHighResolutionTime} = begin
    sec, nsec = a.sec - b.sec, a.nsec - b.nsec
    @normalizetime(sec, nsec, 1_000_000_000)
    return T(sec, nsec)
end

"""
    TaoBindings.normalize(t)

yields time `t` (a `HighResolutionTime`, `TimeSpec` or `TimeVal` structure)
such that the fractional number of seconds is nonnegative and strictly less
than one second.

"""
function normalize(t::T) where {T<:AbstractHighResolutionTime}
    sec, nsec = t.sec, t.nsec
    @normalizetime(sec, nsec, 1_000_000_000)
    return T(sec, nsec)
end

function normalize(t::TimeVal)
    sec, usec = t.sec, t.usec
    @normalizetime(sec, usec, 1_000_000)
    return TimeVal(sec, usec)
end
