#
# Spinnaker.jl -
#
# Julia interface to Spinnaker cameras.
#
#------------------------------------------------------------------------------

# __precompile__(false)
module SpinnakerCameras

using Printf
using Dates
using Base: @propagate_inbounds
using Base.Threads
using Distributed
using Printf
import Base:
    VersionNumber,
    axes,
    copy,
    deepcopy,
    eachindex,
    eltype,
    empty!,
    fill!,
    firstindex,
    getindex,
    getproperty,
    isvalid,
    isreadable,
    iswritable,
    isequal,
    islocked,
    iterate,
    IndexStyle,
    last,
    lastindex,
    length,
    lock,
    ndims,
    propertynames,
    parent,
    parse,
    reset,
    reshape,
    size,
    show,
    showerror,
    similar,
    stride,
    setproperty!,
    setindex!,
    timedwait,
    trylock,
    unlock,
    wait


# TAO bindings
using Statistics
using ArrayTools
using ResizableArrays
import Base.Libc: TimeVal
using Base: @propagate_inbounds

mutable struct RestartListening
    status::Integer
end

# export client functions
export server, send, write_img_config, read_img_config


# include dependents
begin deps = normpath(joinpath(@__DIR__, "../deps/deps.jl"))
    isfile(deps) || error(
        "File \"$deps\" does not exits, see \"README.md\" for installation.")
    include(deps)
end

# Spinnaker interface
include("macros.jl")
include("types.jl")
include("errors.jl")
include("methods.jl")
include("images.jl")
include("acquisitions.jl")
include("camera.jl")

end # module
