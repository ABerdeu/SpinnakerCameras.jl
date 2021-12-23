#
# errors.jl -
#
# Management of errors for the Julia interface to the Spinnaker SDK.
#
#------------------------------------------------------------------------------

"""
    SpinnakerCameras.CallError(err, func)

yields an exception representing an error with code `err` occuring in a call to
function `func` of the Spinnaker SDK.

"""
CallError(err::Integer, func::Symbol) = CallError(SpinErr(err), func)
CallError(err::SpinErr, func::Symbol) =
    CallError(err, func, get(_error_symbols, err, :UNKNOWN))

# Throws a `CallError` exception if `err` indicates an error in function `func`.
function _check(err::SpinErr, func::Symbol)
    if err != SPINNAKER_ERR_SUCCESS
        throw_call_error(err, func)
    end
    return nothing
end

const _error_symbols = Dict{Cint,Symbol}()

@noinline throw_call_error(err::Integer, func::Symbol) =
    throw(CallError(err, func))

show(io::IO, ::MIME"text/plain", err::CallError) =
    print(io, "error ", err.name, " (", err.code,
          ") returned by function `", err.func, "`")

# The error codes used in Spinnaker C.  These codes are returned from every
# function in Spinnaker C.
for (sym, val) in (
    # An error code of 0 means that the function has run without error.
    (:SPINNAKER_ERR_SUCCESS,                 0),
    #
    # The error codes in the range of -1000 to -1999 are reserved for Spinnaker
    # exceptions.
    (:SPINNAKER_ERR_ERROR,               -1001),
    (:SPINNAKER_ERR_NOT_INITIALIZED,     -1002),
    (:SPINNAKER_ERR_NOT_IMPLEMENTED,     -1003),
    (:SPINNAKER_ERR_RESOURCE_IN_USE,     -1004),
    (:SPINNAKER_ERR_ACCESS_DENIED,       -1005),
    (:SPINNAKER_ERR_INVALID_HANDLE,      -1006),
    (:SPINNAKER_ERR_INVALID_ID,          -1007),
    (:SPINNAKER_ERR_NO_DATA,             -1008),
    (:SPINNAKER_ERR_INVALID_PARAMETER,   -1009),
    (:SPINNAKER_ERR_IO,                  -1010),
    (:SPINNAKER_ERR_TIMEOUT,             -1011),
    (:SPINNAKER_ERR_ABORT,               -1012),
    (:SPINNAKER_ERR_INVALID_BUFFER,      -1013),
    (:SPINNAKER_ERR_NOT_AVAILABLE,       -1014),
    (:SPINNAKER_ERR_INVALID_ADDRESS,     -1015),
    (:SPINNAKER_ERR_BUFFER_TOO_SMALL,    -1016),
    (:SPINNAKER_ERR_INVALID_INDEX,       -1017),
    (:SPINNAKER_ERR_PARSING_CHUNK_DATA,  -1018),
    (:SPINNAKER_ERR_INVALID_VALUE,       -1019),
    (:SPINNAKER_ERR_RESOURCE_EXHAUSTED,  -1020),
    (:SPINNAKER_ERR_OUT_OF_MEMORY,       -1021),
    (:SPINNAKER_ERR_BUSY,                -1022),
    #
    # The error codes in the range of -2000 to -2999 are reserved for Gen API
    # related errors.
    (:GENICAM_ERR_INVALID_ARGUMENT,      -2001),
    (:GENICAM_ERR_OUT_OF_RANGE,          -2002),
    (:GENICAM_ERR_PROPERTY,              -2003),
    (:GENICAM_ERR_RUN_TIME,              -2004),
    (:GENICAM_ERR_LOGICAL,               -2005),
    (:GENICAM_ERR_ACCESS,                -2006),
    (:GENICAM_ERR_TIMEOUT,               -2007),
    (:GENICAM_ERR_DYNAMIC_CAST,          -2008),
    (:GENICAM_ERR_GENERIC,               -2009),
    (:GENICAM_ERR_BAD_ALLOCATION,        -2010),
    #
    # The error codes in the range of -3000 to -3999 are reserved for image
    # processing related errors.
    (:SPINNAKER_ERR_IM_CONVERT,          -3001),
    (:SPINNAKER_ERR_IM_COPY,             -3002),
    (:SPINNAKER_ERR_IM_MALLOC,           -3003),
    (:SPINNAKER_ERR_IM_NOT_SUPPORTED,    -3004),
    (:SPINNAKER_ERR_IM_HISTOGRAM_RANGE,  -3005),
    (:SPINNAKER_ERR_IM_HISTOGRAM_MEAN,   -3006),
    (:SPINNAKER_ERR_IM_MIN_MAX,          -3007),
    (:SPINNAKER_ERR_IM_COLOR_CONVERSION, -3008),)
    @eval begin
        const $sym = SpinErr($val)
        _error_symbols[$val] = $(QuoteNode(sym))
    end
end
