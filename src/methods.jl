#
# methods.jl -
#
# Implementation of methods for the Julia interface to the Spinnaker SDK.
#
#------------------------------------------------------------------------------

# Make sure to initialize handles and references to handles with NULL.
Base.Ref{T}() where {T<:Ptr{<:OpaqueObject}} = Ref{T}(0)
Base.Ptr{T}() where {T<:OpaqueObject} = Ptr{T}(0)

to_bool(x::SpinBool) = (x != zero(x))

HRT2Int64(ts::HighResolutionTime) = convert(UInt64,ts.sec*1e9 + ts.nsec)

"""
    SpinnakerCameras.isnull(arg)

yields whether `arg` is a null pointer of a Spinnaker object with a null
handle.

"""
isnull(obj::SpinObject) = isnull(handle(obj))
isnull(ptr::Ptr{T}) where {T} = (ptr == null_pointer(T))

null_pointer(::Type{T}) where {T} = Ptr{T}(0)
null_pointer(x) = null_pointer(typeof(x))

"""
    SpinnakerCameras.handle(obj) -> ptr

yields the handle of Spinnaker object `obj`.  This function is for the
low-level interface, it shall not be used by the end-user.

"""
handle(obj::SpinObject) = getfield(obj, :handle)

_clear_handle!(obj::SpinObject) =
    setfield!(obj, :handle, fieldtype(typeof(obj), :handle)(0))

system(sys::System) = obj
system(obj::SpinObject) = getfield(obj, :system)

"""
    SpinnakerCameras.shortname(obj) -> str

yields the name of Spinnaker object `obj`.  The object type may be specified
instead.

"""
shortname(obj::SpinObject) = shortname(typeof(obj))
shortname(::Type{<:System}) = "object system"
shortname(::Type{<:Interface}) = "interface"
shortname(::Type{<:InterfaceList}) = "interface list"
shortname(::Type{<:CameraList}) = "camera list"
shortname(::Type{<:Camera}) = "camera"
shortname(::Type{<:Image}) = "image"
shortname(::Type{<:Node}) = "node"
shortname(::Type{<:NodeMap}) = "node map"

"""
    SpinnakerCameras.check(obj) -> obj

throws an exception if the handle of object `obj` is null, otherwise returns
the object.

"""
function check(obj::SpinObject)
    isnull(obj) && error("Spinnaker ", shortname(obj), " has been finalized")
    return obj
end

# This version of `_finalize` implements the do-block syntax.  If the handle of
# object `obj` is not null, function `func` is called with the handle value and
# the object handle is set to null.
function _finalize(func::Function, obj::SpinObject)
    ptr = handle(obj)
    if ! isnull(ptr)
        func(ptr)
        _clear_handle!(obj)
    end
    return nothing
end

# Function Generation
# Get length/size of some Spinnaker objects.
# FIXME: spinNodeMapGetNumNodes seems broken
for (jl_func, type, c_func) in (
    (:length, :InterfaceList, :spinInterfaceListGetSize),
    #(:sizeof, :Image,         :spinImageGetSize),
    (:length, :CameraList,    :spinCameraListGetSize),
    (:length, :NodeMap,       :spinNodeMapGetNumNodes),)
    handle_type = Symbol(type,"Handle")
    @eval begin
        function $jl_func(obj::$type)
            isnull(obj) && return 0
            ref = Ref{Csize_t}(0)
            @checked_call($c_func, ($handle_type, Ptr{Csize_t}),
                          handle(obj), ref)
            return Int(ref[])
        end
    end
end

#------------------------------------------------------------------------------
# Methods for properties of any Spinnaker object type.
#
# Specialize `getproperty` and `setproperty!` in the name of the member (for
# type-stability and faster code).
getproperty(obj::SpinObject, sym::Symbol) = getproperty(obj, Val(sym))
setproperty!(obj::SpinObject, sym::Symbol, val) =
    setproperty!(obj, Val(sym), val)

# The following methods are to deal with errors.
getproperty(obj::T, ::Val{M}) where {T<:SpinObject,M} =
    throw_unknown_field(T, M)

setproperty!(obj::T, ::Val{M}, val) where {T<:SpinObject,M} =
    if M in propertynames(obj)
        throw_read_only_field(T, M)
    else
        throw_unknown_field(T, M)
    end

@noinline throw_unknown_field(T::Type, sym::Union{Symbol,AbstractString}) =
    throw(ErrorException("objects of type $T have no field `$sym`"))

@noinline throw_read_only_field(T::Type, sym::Union{Symbol,AbstractString}) =
    throw(ErrorException("field `$sym` of objects of type $T is read-only"))

#------------------------------------------------------------------------------
# SYSTEM

"""
    sys = SpinnakerCameras.System()

yields an instance `sys` of Spinnaker object system.  The following properties
are implemented:

    sys.cameras        # yields the list of cameras
    sys.interfaces     # yields the list of interfaces
    sys.libraryversion # yields the version number of the SDK library
    sys.tlnodemap      # yields the transport layer node map

""" System

_finalize(obj::System) = _finalize(obj) do ptr
    @checked_call(:spinSystemReleaseInstance, (SystemHandle,), ptr)
end

propertynames(::System) = (
    :cameras,
    :interfaces,
    :libraryversion,
    :tlnodemap)

getproperty(sys::System, ::Val{:cameras}) = CameraList(sys)
getproperty(sys::System, ::Val{:interfaces}) = InterfaceList(sys)
getproperty(sys::System, ::Val{:libraryversion}) = VersionNumber(sys)

"""
    SpinnakerCameras.LibraryVersion(sys)

yields the version of the Spinnaker library for object system `sys`.

"""
function LibraryVersion(sys::System)
    ref = Ref{LibraryVersion}()
    @checked_call(:spinSystemGetLibraryVersion,
                  (SystemHandle, Ptr{LibraryVersion},),
                  handle(sys), ref)
    return ref[]
end

VersionNumber(sys::System) = VersionNumber(LibraryVersion(sys))
VersionNumber(v::LibraryVersion) =
    VersionNumber(v.major, v.minor, v.type, (), (v.build,))

#------------------------------------------------------------------------------
# LISTS OF INTERFACES

"""
    lst = SpinnakerCameras.InterfaceList(sys)

yields a list of Spinnaker interfaces for the system `sys`.  This is the same
as `sys.interfaces`.

Call `length(lst)` to retrieve the number of interfaces and use syntax `lst[i]`
to get the `i`-th interface.

""" InterfaceList
# get interface from an index
getindex(lst::InterfaceList, i::Integer) = Interface(lst, i)

# clear interfaces in the list
empty!(obj::InterfaceList) = begin
    @checked_call(:spinInterfaceListClear, (InterfaceListHandle,), handle(obj))
    return obj
end

_finalize(obj::InterfaceList) = _finalize(obj) do ptr
    err1 = @unchecked_call(:spinInterfaceListClear,
                           (InterfaceListHandle,), ptr)
    err2 = @unchecked_call(:spinInterfaceListDestroy,
                           (InterfaceListHandle,), ptr)
    _check(err1, :spinInterfaceListClear)
    _check(err2, :spinInterfaceListDestroy)
end

# Make interface lists and camera lists iterable.
function iterate(itr::Union{InterfaceList,CameraList,NodeMap},
                 state::NTuple{2,Int} = (1, length(itr)))
    idx, len = state
    if idx ≤ len
        return itr[idx], (idx+1, len)
    else
        return nothing
    end
end

#------------------------------------------------------------------------------
# INTERFACES

"""
    SpinnakerCameras.Interface(lst, i)

yields the `i`-th entry of Spinnaker interface list `lst`.  This is the same as
`lst[i]`.

The following properties are implemented an interface instance:

    interface.cameras   # yields the list of cameras of the interface
    interface.tlnodemap # yields the transport layer node map of the interface

""" Interface

propertynames(::Interface) = (:cameras, :tlnodemap)

getproperty(obj::Interface, ::Val{:cameras}) = CameraList(obj)

_finalize(obj::Interface) = _finalize(obj) do ptr
    @checked_call(:spinInterfaceRelease, (InterfaceHandle,), ptr)
end

#------------------------------------------------------------------------------
# LISTS OF CAMERAS

"""
    lst = SpinnakerCameras.CameraList(sys)
    lst = SpinnakerCameras.CameraList(int)

yield a list of Spinnaker cameras for the system `sys` or for the interface
`int`.   This is the same as `sys.cameras` and `int.cameras` respectively.

Call `length(lst)` to retrieve the number of cameras and use syntax `lst[i]` to
get the `i`-th camera.

""" CameraList
# get camera from an index
getindex(lst::CameraList, i::Integer) = Camera(lst, i)

# clear camera list
empty!(obj::CameraList) = begin
    @checked_call(:spinCameraListClear, (CameraListHandle,), handle(obj))
    return obj
end

_finalize(obj::CameraList) = _finalize(obj) do ptr
    err1 = @unchecked_call(:spinCameraListClear,
                           (CameraListHandle,), ptr)
    err2 = @unchecked_call(:spinCameraListDestroy,
                           (CameraListHandle,), ptr)
    _check(err1, :spinCameraListClear)
    _check(err2, :spinCameraListDestroy)
end



#------------------------------------------------------------------------------
# NODE MAPS AND NODES

for (T, key, func) in (
    (:System,    :tlnodemap,       :spinSystemGetTLNodeMap),
    (:Interface, :tlnodemap,       :spinInterfaceGetTLNodeMap),
    (:Camera,    :nodemap,         :spinCameraGetNodeMap),
    (:Camera,    :tldevicenodemap, :spinCameraGetTLDeviceNodeMap),
    (:Camera,    :tlstreamnodemap, :spinCameraGetTLStreamNodeMap))
    @eval begin
        function getproperty(obj::$T, ::$(Val{key}))
            ref = Ref{NodeMapHandle}(0)
            @checked_call($func, ($(Symbol(T,"Handle")), Ptr{NodeMapHandle}),
                          handle(obj), ref)
            return NodeMap(ref[], obj)
        end
    end
end
# get the parent node/ root node
parent(obj::NodeMap) = getfield(obj, :parent)
parent(obj::Node) = getfield(obj, :parent)

# get the node eother by numerical index or
getindex(obj::NodeMap, idx::Integer) = Node(obj, idx)
getindex(obj::NodeMap, str::AbstractString) = Node(obj, str)

show(io::IO, ::MIME"text/plain", obj::NodeMap) =
    print(io, "SpinnakerCameras.NodeMap: ", length(obj), " node(s)")

show(io::IO, ::MIME"text/plain", obj::Node) =
    print(io, "SpinnakerCameras.Node: name = \"", obj.name, "\"")

#-------------------------------------
#===
        Getter functions
        Numeric nodes
===#

"""
    SpinnakerCameras.getvalue(T, node[, verif])

yields the value of a Spinnaker node.  Argument `T` is the type of the result,
`T<:Integer` for an integer-valued node and `T<:AbstractFloat` for a
real-valued node.  Optional argument `verif` is to manually specify whether to
verify the node.

""" getvalue

"""
    SpinnakerCameras.getmin(T, node)

yields the minimum value of a Spinnaker node.  Argument `T` is the type of the
result, `T<:Integer` for an integer-valued node and `T<:AbstractFloat` for a
real-valued node.

""" getmin

"""
    SpinnakerCameras.getmax(T, node)

yields the maximum value of a Spinnaker node.  Argument `T` is the type of the
result, `T<:Integer` for an integer-valued node and `T<:AbstractFloat` for a
real-valued node.

""" getmax

"""
    SpinnakerCameras.getinc(T, node)

yields the increment of an integer Spinnaker node.  Argument `T` is the type of
the result.

""" getinc

for (jl_func, type, c_func) in (
    (:getvalue, Int64,   :spinIntegerGetValue),
    (:getmin,   Int64,   :spinIntegerGetMin),
    (:getmax,   Int64,   :spinIntegerGetMax),
    (:getinc,   Int64,   :spinIntegerGeInc),
    (:getvalue, Cdouble, :spinFloatGetValue),
    (:getmin,   Cdouble, :spinFloatGetMin),
    (:getmax,   Cdouble, :spinFloatGetMax),)
    @eval function $jl_func(::Type{$type}, node::Node)
        ref = Ref{$type}(0)
        @checked_call($c_func, (NodeHandle, Ptr{$type}), handle(node), ref)
        return ref[]
    end
    if jl_func === :getvalue
        c_func_ex = Symbol(c_func, "Ex")
        @eval function $jl_func(::Type{$type}, node::Node, verif::Bool)
            ref = Ref{$type}(0)
            @checked_call($c_func_ex, (NodeHandle, SpinBool, Ptr{$type}),
                          handle(node), verif, ref)
            return ref[]
        end
    end
end

for func in (:getvalue, :getmin, :getmax, :getinc)
    for (T, U) in ((:Integer, :Int64),
                   (:AbstractFloat, :Cdouble))
        if func !== :getinc || T === :Integer
            @eval $func(T::Type{<:$T}, node::Node) =
                convert(T, $func($U, node))
        end
        if func === :getvalue
            @eval $func(T::Type{<:$T}, node::Node, verif::Bool) =
                convert(T, $func($U, node, verif))
        end
    end
end

#===
        Setter functions
        Numeric nodes
===#

"""
    SpinnakerCameras.setValue(node, value)

sets the value of a Spinnaker node.  Argument node is the numeric node to be set.
Argument value is the value to be set

""" setValue

setValue(node::Node, value::Float64) = @checked_call(:spinFloatSetValue,
                                                    (NodeHandle, Cdouble),
                                                    handle(node), value)

setValue(node::Node, value::Int64) = @checked_call(:spinIntegerSetValue,
                                                    (NodeHandle, Cint),
                                                    handle(node), value)


"""
    SpinnakerCameras.setEnumValue(node, value)

sets the value of a enum node.  Argument node is the numeric node to be set.
Argument value is the value to be set

""" setEnumtValue

setEnumValue(node::Node, value::Int64) = @checked_call(:spinEnumerationSetIntValue,
                                                    (NodeHandle, Cint),
                                                    handle(node), value)

#-------------------------------------------------------------------------------
#====
    Node additional functions
    - commandNode execute
    - status checking
    - property query
    - Enum Entry Node
    - Finalizer
===#

# ================== command node execute ====================
"""
    SpinnakerCameras.command_execute(nd)

execute a command node

""" command_execute

command_execute(node::Node) = @checked_call(:spinCommandExecute,
                                             (NodeHandle,), handle(node))

# ================== status checking ====================
"""
    SpinnakerCameras.isavailable(nd)

yields whether node `nd` is available.

""" isavailable

"""
    SpinnakerCameras.isimplemented(nd)

yields whether node `nd` is implemented.

""" isimplemented

"""
    SpinnakerCameras.isreadable(nd)

yields whether node `nd` is readable.

""" isreadable

"""
    SpinnakerCameras.iswritable(nd)

yields whether node `nd` is writable.

""" iswritable

for (jl_func, c_func) in ((:isavailable,   :spinNodeIsAvailable),
                          (:isimplemented, :spinNodeIsImplemented),
                          (:isreadable,    :spinNodeIsReadable),
                          (:iswritable,    :spinNodeIsWritable),)
    _jl_func = Symbol("_", jl_func)
    @eval begin

        function $_jl_func(obj::Node)
            isnull(handle(obj)) && return false
            ref = Ref{SpinBool}(false)
            @checked_call($c_func, (NodeHandle, Ptr{SpinBool}),
                          handle(obj), ref)
            return to_bool(ref[])
        end

        $jl_func(obj::Node) = $_jl_func(obj)
    end
end

isequal(a::Node, b::Node) = _isequal(handle(a), handle(b))
function _isequal(a::NodeHandle, b::NodeHandle)
    (isnull(a) || isnull(b)) && return false
    ref = Ref{SpinBool}(false)
    @checked_call(:spinNodeIsEqual,
                  (NodeHandle, NodeHandle, Ptr{SpinBool}), a, b, ref)
    return to_bool(ref[])
end
# ============== getproperty for Nodes ======================

# node properties
propertynames(::Node) = (
    :accessmode,
    :name,
    :cachingmode,
    :namespace,
    :visibility,
    :tooltip,
    :displayname,
    :type,
    :pollingtime)


# Implement `getproperty` for node objects.  Note that a node handle may be
# NULL (see comments about calling `spinNodeMapGetNodeByIndex`), so a default
# value is provided in that case.
for (sym, func, T, def) in (
    (:accessmode,  :spinNodeGetAccessMode,             AccessMode,  UndefinedAccesMode),
    (:name,        :spinNodeGetName,                   Cstring,     ""),
    (:cachingmode, :spinNodeGetCachingMode,            CachingMode, UndefinedCachingMode),
    (:namespace,   :spinNodeGetNameSpace,              NameSpace,   UndefinedNameSpace),
    (:visibility,  :spinNodeGetVisibility,             Visibility,  UndefinedVisibility),
    (:tooltip,     :spinNodeGetToolTip,                Cstring,     ""),
    (:displayname, :spinNodeGetDisplayName,            Cstring,     ""),
    (:type,        :spinNodeGetType,                   NodeType,    UnknownNode),
    (:pollingtime, :spinNodeGetPollingTime,            Int64,       0)
    )
    if T === Cstring
        @eval function getproperty(obj::Node, ::$(Val{sym}))
            isnull(handle(obj)) && return $def
            local buf
            len = 0
            ptr = Ptr{UInt8}(0)
            while true
                siz = Ref{Csize_t}(len)
                @checked_call($func,
                              (NodeHandle, Ptr{UInt8}, Ptr{Csize_t}),
                              handle(obj), ptr, siz)
                if len > 0
                    return String(resize!(buf, siz[] - 1))
                end
                len = siz[]
                buf = Vector{UInt8}(undef, len)
                ptr = pointer(buf)
            end
        end
    else
        @eval function getproperty(obj::Node, ::$(Val{sym}))
            isnull(handle(obj)) && return $def
            ref = Ref{$T}($def)
            @checked_call($func, (NodeHandle, Ptr{$T}), handle(obj), ref)
            return ref[]
        end
    end
end

# ==================  EnumEntryNode ========================

"""
    SpinnakerCameras.getEntryValue(entryNode) -> Int64

get enum value from enum entry node and return as Integer

""" getEntryValue

function getEntryValue(obj::EntryNode)
    ref = Ref{Int64}(0)
    @checked_call(:spinEnumerationEntryGetIntValue,
                    (NodeHandle, Ptr{Int64}),
                    handle(obj), ref)
    return ref[]

end

# ============    Nodemap/ Node Finalizer ======================

# nodemap finalizer
function _finalize(obj::NodeMap)
    ptr = handle(obj)
    if !isnull(ptr)
        _clear_handle!(obj)

    end
    return nothing
end

# node finalizer
function _finalize(obj::Node)
    ptr = handle(obj)
    if !isnull(ptr)
        _clear_handle!(obj)
    end
    return nothing
end

# entry node finalizer
function _finalize(obj::EntryNode)
    ptr = handle(obj)
    if !isnull(ptr)
        # @checked_call(:spinEnumerationReleaseNode,
        #               (NodeHandle, NodeHandle),
        #               handle(parent(obj)), ptr)
         _clear_handle!(obj)

    end
    return nothing
end
