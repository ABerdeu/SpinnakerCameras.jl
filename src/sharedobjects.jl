#
# sharedobjects.jl --
#
# Management of shared objects for the Julia interface to the C libraries of
# TAO, a Toolkit for Adaptive Optics.
#
#-------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

propertynames(obj::SharedObject) =
    (:accesspoint,
     :shmid,
     :lock,
     :owner,
     :size,
     :type,
     )

getproperty(obj::TaoSharedObject, sym::Symbol) =
    getattribute(obj, Val(sym))

setproperty!(obj::TaoSharedObject, sym::Symbol, val) =
    setattribute!(obj, Val(sym), val)

"""
    TaoBindings.getattribute(obj, Val(sym)) -> val

yields the value of attribute whose symbolic name is `sym` for shared object
`obj`.  This method implements the `obj.sym` syntax for TAO shared objects and
should be specialized for different object types and attribute names.

!!! warning
    The caller is responsible of locking the object for read access if some
    guaranties about the returned value are expected.  The `rdlock` method
    used in a do-block is perfect for that.  For instance assuming `cam`
    is a shared or remote camera:

        state, pixeltype = rdlock(cam) do
            cam.state, cam.pixeltype
        end

""" getattribute

getattribute(obj::TaoSharedObject, ::Val{:accesspoint}) =
    _pointer_to_string(ccall((:tao_get_shared_object_accesspoint, taolib),
                             Ptr{UInt8}, (Ptr{AbstractSharedObject},), obj))

getattribute(obj::TaoSharedObject, ::Val{:lock}) = getfield(obj, :lock)

getattribute(obj::TaoSharedObject, ::Val{:owner}) =
    _pointer_to_string(ccall((:tao_get_shared_object_owner, taolib),
                             Ptr{UInt8}, (Ptr{AbstractSharedObject},), obj))

getattribute(obj::TaoSharedObject, ::Val{:shmid}) =
    ccall((:tao_get_shared_data_shmid, taolib), ShmId,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::TaoSharedObject, ::Val{:size}) =
    ccall((:tao_get_shared_data_size, taolib), Csize_t,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::TaoSharedObject, ::Val{:type}) =
    ccall((:tao_get_shared_object_type, taolib), UInt32,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::TaoSharedObject, ::Val{sym}) where {sym} =
    throw_non_existing_attribute(obj, sym)


"""
    TaoBindings.setattribute!(obj, Val(sym), val) -> val

sets the value of attribute whose symbolic name is `sym` for shared object
`obj`.  This method implements the `obj.sym = val` syntax for TAO shared
objects and should be specialized for different object types and attribute
names.

!!! warning
    The caller is responsible of locking the object for read-write access.

""" setattribute!

setattribute!(obj::AnySharedObject, ::Val{sym}, val) where {sym} =
    throw_non_existing_or_read_only_attribute(obj, sym)

@noinline function throw_non_existing_attribute(obj::AnySharedObject,
                                                sym::Symbol)
    error("objects of type ", typeof(obj), " have no attribute `", sym, "`")
end

@noinline function throw_non_existing_or_read_only_attribute(obj::AnySharedObject,
                                                             sym::Symbol)
    sym ∈ propertynames(obj) || throw_non_existing_attribute(obj, sym)
    error("attribute `", sym, "` is read-only")
end

#------------------------------------------------------------------------------

# Private accessors.
_get_ptr(obj::AnySharedObject) = getfield(obj, :ptr)
_set_ptr!(obj::AnySharedObject, val::Ptr{AbstractSharedObject}) =
    setfield!(obj, :ptr, val)
_set_ptr!(obj::AnySharedObject, val::Ptr{Cvoid}) = # FIXME: avoid this!
    _set_ptr!(obj, Ptr{AbstractSharedObject}(val))
_set_ptr!(obj::AbstractMonitor, val::Ptr{AbstractSharedObject}) =
    setfield!(obj, :ptr, val)
_set_lock!(obj::AnySharedObject, val::LockMode) = setfield!(obj, :lock, val)
_get_final(obj::AnySharedObject) = getfield(obj, :final)
_set_final!(obj::AnySharedObject, val::Bool) = setfield!(obj, :final, val)

# For the type of a shared objects, only the bits are significant, not the
# value.
_fix_shared_object_type(type::UInt32) :: UInt32 =
    (0 ≤ type ≤ 255 ? (SHARED_MAGIC | type) : type)
_fix_shared_object_type(type::Int32) :: UInt32 =
    _fix_shared_object_type(reinterpret(UInt32, type))
_fix_shared_object_type(type::Signed) :: UInt32 =
    _fix_shared_object_type(convert(Int32, type))
_fix_shared_object_type(type::Unsigned) :: UInt32 =
    _fix_shared_object_type(convert(UInt32, type))

function create(::Type{SharedObject}, type::Integer, size::Integer;
                owner::AbstractString = default_owner(),
                perms::Integer = 0o600)
    length(owner) < SHARED_OWNER_SIZE || error("owner name too long")
    ptr = ccall((:tao_create_shared_object, taolib), Ptr{AbstractSharedObject},
                (Cstring, UInt32, Csize_t, Cuint),
                owner, _fix_shared_object_type(type), size, perms)
    _check(ptr != C_NULL)
    return _wrap(SharedObject, ptr)
end

"""
    attach(TaoBindings.SharedObject, shmid, type=TaoBindings.SHARED_ANY) -> obj

attaches the shared TAO object identified by `shmid` to the data space of the
caller and returns a new instance of `TaoBindings.SharedObject` associated with it.
Argument `type` can be used to restrict to a specific type of shared object
(throwing an exception if `shmid` does not correspond to an object of that
type).

    attach(TaoBindings.SharedArray, shmid) -> arr

attaches the shared TAO array identified by `shmid` to the data space of the
caller and returns a new instance of `TaoBindings.SharedArray` associated with it and
which can be used as any Julia `DenseArray`.


    attach(TaoBindings.SharedCamera, shmid) -> cam

attaches the shared TAO camera identified by `shmid` to the data space of the
caller and returns a new instance of `TaoBindings.SharedCamera` associated with it.
In this case, `shmid` may be a share memory identifier (an integer) of the
access point (a string) of an XPA frame-grabber server.  For instance:

    cam = attach(TaoBindings.SharedCamera, "TAO:Andor0")

"""

function attach(::Type{SharedObject}, shmid::Integer,
                type::Integer = SHARED_ANY)
    # Attach the shared object to the address space of the caller, then wrap it
    # in a Julia object.
    ptr = _call_attach(shmid, type)
    _check(ptr != C_NULL)
    return _wrap(SharedObject, ptr)
end

function attach!(obj::SharedObject, shmid::Integer,
                 type::Integer = SHARED_ANY)
    if _get_ptr(obj) == C_NULL
        _set_lock!(obj, UNLOCKED)
    else
        _detach(obj, true)
    end
    ptr = _call_attach(shmid, type)
    _check(ptr != C_NULL)
    _set_ptr!(obj, ptr)
    if ptr != C_NULL && !_get_final(obj)
        finalizer(_finalize, obj)
        _set_final!(obj, true)
    end
    return obj
end

"""
    detach(obj::TaoBindings.AnySharedObject)

detaches TAO shared-object `obj` from the data space of the caller.
This is automatically done when the object is garbage collected.

"""
detach(obj::AnySharedObject) = _detach(obj, true)

# Finalizing a shared object amounts to detaching it.  Errors must not be
# thrown though.
_finalize(obj::AnySharedObject) = _detach(obj, false)

function _detach(obj::AnySharedObject, throwerrors::Bool)
    ptr = _get_ptr(obj)
    if ptr == C_NULL
        _set_lock!(obj, UNLOCKED)
    else

        # Make sure object is unlocked and detach it.
        status = OK
        if obj.lock != UNLOCKED
            _set_lock!(obj, UNLOCKED)
            if _call_unlock(ptr) != OK
                status = ERROR
            end
        end
        _set_ptr!(obj, C_NULL)
        if _call_detach(ptr) != OK
            status = ERROR
        end
        _check(status, !throwerrors)
    end
    return nothing
end

# Wrap a shared object attached at address `ptr` into a "fresh" Julia object
# of type `T`.
function _wrap(::Type{T},
               ptr::Ptr{AbstractSharedObject}) where {
                   T<:AnySharedObject}
    obj = T()
    _set_ptr!(obj, ptr)
    if ptr != C_NULL
        finalizer(_finalize, obj)
        _set_final!(obj, true)
    end
    return obj
end

# Specialize `unsafe_convert` for all flavors of shared objects when passed as
# argument to `ccall`.  This could also be the opportunity to check for the
# validity of the pointer but it turns out that it was faster (and simpler) to
# have it in the C library.
Base.unsafe_convert(::Type{Ptr{AbstractSharedObject}}, obj::AnySharedObject) =
    _get_ptr(obj)

"""
    rdlock(obj::TaoBindings.Lockable, timeout=Inf) -> bool

locks TAO lockable object `obj` for read-only access.  For a given shared
object, there can be any number of readers and no writers or no readers and at
most one writer.  The call blocks until the lock can be acquired but no longer
than the time limit specified by `timeout` (if unspecified, there is no time
limit).  If `timeout` is a number, it is interpreted as a relative time limit
in seconds from now; otherwise, `timeout` can be an instance of
`HighResolutionTime` to specify an absolute time limit.

The value returned by `rdlock` is a boolean indicating whether the lock has
been acquired by the caller before the time limit expired.

Typical usage is:

    if rdlock(obj, secs)
        # Object has been locked for read-only access by the caller.
        try
            ...
        finally
            # Unlock object when read-only access no longer needed.
            unlock(obj)
        end
    else
        # Time-out occured before lock can be obtained.
        throw(Tao.TimeoutError())
    end

To simplify such construction, the do-block syntax is supported to perform some
operations on a lockable object with a granted read-only access.  For instance,
a shared array `arr` can be safely copied into another destination array `dest`
by:

    rdlock(arr, tm) do
        copyto!(dest, arr)
    end

If the lock cannot be acquired before the time limit `tm`, a `Tao.TimeoutError`
exception is thrown (if this argument is omitted, there is no time limit).

See also: [`wrlock(::TaoBindings.Lockable)`](@ref),
[`islocked(::TaoBindings.Lockable)`](@ref),
[`unlock(::TaoBindings.Lockable)`](@ref).

"""

function rdlock(func::Function, obj::Lockable, args...)
    rdlock(obj, args...) || throw(TimeoutError())
    try
        return func()
    finally
        unlock(obj)
    end
end

"""
    wrlock(obj::TaoBindings.AnySharedObject, timeout=Inf) -> bool

locks TAO lockable object `obj` for read-write access.  For a given shared
object, there can be any number of readers and no writers or no readers and at
most one writer.  The call blocks until the lock can be acquired but no longer
than the time limit specified by `timeout` (if unspecified, there is no time
limit).  If `timeout` is a number, it is interpreted as a relative time limit
in seconds from now; otherwise, `timeout` can be an instance of
`HighResolutionTime` to specify an absolute time limit.

The value returned by `wrlock` is a boolean indicating whether the lock has
been acquired by the caller before the time limit expired.

Typical usage is:

    if wrlock(obj, secs)
        # Object has been locked for read-write access by the caller.
        try
            ...
        finally
            # Unlock object when read-write access no longer needed.
            unlock(obj)
        end
    else
        # Time-out occured before lock can be obtained.
        throw(Tao.TimeoutError())
    end

To simplify such construction, the do-block syntax is supported to perform some
operations on a lockable object with a granted read-write access.  For
instance, the values of a shared array `arr` can be safely copied from another
source array `src` by:

    wrlock(arr, tm) do
        copyto!(arr, src)
    end

If the lock cannot be acquired before the time limit `tm`, a `Tao.TimeoutError`
exception is thrown (if this argument is omitted, there is no time limit).

See also: [`rdlock(::TaoBindings.Lockable)`](@ref),
[`islocked(::TaoBindings.Lockable)`](@ref),
[`unlock(::TaoBindings.Lockable)`](@ref).

"""

function wrlock(func::Function, obj::Lockable, args...)
    wrlock(obj, args...) || throw(TimeoutError())
    try
        return func()
    finally
        unlock(obj)
    end
end

# Read/write lock methods for shared objects.
for (func, mode) in ((:rdlock, :READ_ONLY),
                     (:wrlock, :READ_WRITE),)
    @eval begin

        function $func(obj::AnySharedObject)
            obj.lock == UNLOCKED || throw_already_locked()
            if _get_ptr(obj) == C_NULL
                _set_lock!(obj, $mode)
            else
                status = ccall(
                    ($(string("tao_",func,"_shared_data")), taolib),
                    Status, (Ptr{AbstractSharedObject},), obj)
                status == OK && _set_lock!(obj, $mode)
                _check(status)
            end
            return obj.lock == $mode
        end

        function $func(obj::AnySharedObject, secs::Real)
            obj.lock == UNLOCKED || throw_already_locked()
            if _get_ptr(obj) == C_NULL
                _set_lock!(obj, $mode)
            else
                if secs == 0
                    status = ccall(
                        ($(string("tao_try_",func,"_shared_data")), taolib),
                        Status, (Ptr{AbstractSharedObject},), obj)
                else
                    status = ccall(
                        ($(string("tao_timed_",func,"_shared_data")), taolib),
                        Status, (Ptr{AbstractSharedObject}, Cdouble,),
                        obj, secs)
                end
                status == OK && _set_lock!(obj, $mode)
                _check(status)
            end
            return obj.lock == $mode
        end

        function $func(obj::AnySharedObject, abstime::HighResolutionTime)
            obj.lock == UNLOCKED || throw_already_locked()
            if _get_ptr(obj) == C_NULL
                _set_lock!(obj, $mode)
            else
                status = ccall(
                    ($(string("tao_abstimed_",func,"_shared_data")), taolib),
                    Status, (Ptr{AbstractSharedObject}, Ptr{HighResolutionTime},),
                    obj, Ref(abstime))
                status == OK && _set_lock!(obj, $mode)
                _check(status)
            end
            return obj.lock == $mode
        end

    end
end

"""
    unlock(obj::TaoBindings.Lockable)

unlocks TAO lockable object `obj` that has been locked by the caller by
[`rdlock(obj)`](@ref) or by [`wrlock(obj)`](@ref).  Call
[`islocked(obj)`](@ref) to check whether `obj` is locked.

"""

function unlock(obj::AnySharedObject)
    obj.lock == UNLOCKED && throw_not_locked()
    _set_lock!(obj, UNLOCKED)
    if _get_ptr(obj) != C_NULL
        _check(_call_unlock(_get_ptr(obj)))
    end

    nothing
end

_call_unlock(ptr::Ptr{AbstractSharedObject}) =
    ccall((:tao_unlock_shared_data, taolib), Status,
          (Ptr{AbstractSharedObject},), ptr)

_call_detach(ptr::Ptr{AbstractSharedObject}) =
    ccall((:tao_detach_shared_object, taolib), Status,
          (Ptr{AbstractSharedObject},), ptr)

_call_attach(shmid::Integer, type::Integer) =
    ccall((:tao_attach_shared_object, taolib), Ptr{AbstractSharedObject},
          (ShmId, UInt32,), shmid, _fix_shared_object_type(type))

@noinline throw_not_locked() = error("object is not locked by caller")
@noinline throw_already_locked() = error("object already locked by caller")

"""
    islocked(obj::TaoBindings.AnySharedObject) -> boolean

yields whether TAO lockable object `obj` is locked by the caller.

See also: [`rdlock(::TaoBindings.AnySharedObject)`](@ref),
[`wrlock(::TaoBindings.AnySharedObject)`](@ref),
[`unlock(::TaoBindings.AnySharedObject)`](@ref).

"""
islocked(obj::AnySharedObject) = (obj.lock != UNLOCKED)

get_shmid(obj::AnySharedObject) = obj.shmid

"""
    TaoBindings.default_owner()

yields the default owner name of a shared TAO object.

"""
default_owner() = get(ENV, "USER", "")

"""
    get_accesspoint(obj) -> str

yields the XPA accesspoint address of the server owning the shared object
`obj`.  This is the same as:

    obj.accesspoint

There are no needs to have locked the shared object `obj` to query its
accesspoint name because it is an immutable information (after initialization).

Argument can also be instance of `XPA.AccessPoint`, a string with a valid XPA
server address or a server `class:name` identifier.

See also: [`attach`](@ref), [`get_shmid`](@ref), [`get_type`](@ref),
[`get_size`](@ref), XPA.address.

"""
get_accesspoint(obj::AnySharedObject) = obj.accesspoint

_pointer_to_string(ptr::Ptr{UInt8}) =
    (ptr == C_NULL ? "" : unsafe_string(ptr))
