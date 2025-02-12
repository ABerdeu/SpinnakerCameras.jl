#
# types.jl -
#
# Type definitions for the Julia interface to the Spinnaker SDK.
#
#------------------------------------------------------------------------------

# Julia type for a C enumeration.
const Cenum = Cint

# Julia type for `spinErr`, the type of the result returned by most functions
# of the Spinnaker SDK.
const SpinErr = Cenum

# Julia type for `bool8_t`, the type of booleans used in the Spinnaker SDK.
const SpinBool = UInt8

struct CallError <: Exception
    code::Cint
    func::Symbol
    name::Symbol # symbolic name of error
end

# Julia equivalent to C structure `spinLibraryVersion`.
struct LibraryVersion
    major::Cuint # Major version of the library
    minor::Cuint # Minor version of the library
    type::Cuint  # Version type of the library
    build::Cuint # Build number of the library
end

# `SpinObject` is the abstract super-type of Julia objects.  Such objects have
# a "handle" member which is the address of an opaque Spinnaker object.
abstract type SpinObject end

# In the SDK, all handle types are anonymous pointers (`void*`), but in the low
# level Julia interface, we use more specific pointers to avoid errors.
# `Ptr{<:OpaqueObject}` is the super-type of all pointers to Spinnaker objects.
abstract type OpaqueObject end

for T in (:System, :Camera, :CameraList, :Interface, :InterfaceList,
          :Node, :NodeMap, :Image)
    @eval begin
        abstract type $(Symbol("Opaque",T)) <: OpaqueObject; end
        const $(Symbol(T,"Handle")) = Ptr{$(Symbol("Opaque",T))}
    end
end

mutable struct System <: SpinObject
    handle::SystemHandle
    function System()
        ref = Ref{SystemHandle}(0)
        @checked_call(:spinSystemGetInstance, (Ptr{SystemHandle},), ref)
        return finalizer(_finalize, new(ref[]))
    end
end

mutable struct InterfaceList <: SpinObject
    handle::InterfaceListHandle
    system::System # needed to maintain a reference to the "system" instance
    function InterfaceList(sys::System)
        # Check argument.
        check(sys)

        # Create an empty interface list.
        ref = Ref{InterfaceListHandle}(0)
        @checked_call(:spinInterfaceListCreateEmpty,
                      (Ptr{InterfaceListHandle},), ref)

        # Instanciate the object and associate its finalizer (in case of
        # subsequent errors).
        lst = finalizer(_finalize, new(ref[], sys))

        # Retrieve the interface list from the system.
        @checked_call(:spinSystemGetInterfaces,
                      (SystemHandle, InterfaceListHandle),
                      handle(sys), handle(lst))

        # Return the instanciated object.
        return lst
    end
end

mutable struct Interface <: SpinObject
    handle::InterfaceHandle
    system::System # needed to maintain a reference to the "system" instance
    function Interface(lst::InterfaceList, i::Integer)
        1 ≤ i ≤ length(lst) || error(
            "out of bound index in Spinnaker ", shortname(lst))
        sys = check(system(check(lst)))
        ref = Ref{InterfaceHandle}(0)
        @checked_call(:spinInterfaceListGet,
                      (InterfaceListHandle, Csize_t,
                       Ptr{InterfaceHandle}),
                      handle(lst), i - 1, ref)
        return finalizer(_finalize, new(ref[], sys))
    end
end

mutable struct CameraList <: SpinObject
    handle::CameraListHandle
    system::System # needed to maintain a reference to the "system" instance

    function CameraList(sys::System)
        # Check argument.
        check(sys)

        # Create an empty camera list.
        ref = Ref{CameraListHandle}(0)
        @checked_call(:spinCameraListCreateEmpty,
                      (Ptr{CameraListHandle},), ref)

        # Instanciate the object and associate its finalizer (in case of
        # subsequent errors).
        lst = finalizer(_finalize, new(ref[], sys))

        # Retrieve the camera list from the system.
        @checked_call(:spinSystemGetCameras,
                      (SystemHandle, CameraListHandle),
                      handle(sys), handle(lst))

        # Return the instanciated object.
        return lst
    end

    function CameraList(int::Interface)
        # Check argument and get object system.
        sys = check(system(check(int)))

        # Create an empty camera list.
        ref = Ref{CameraListHandle}(0)
        @checked_call(:spinCameraListCreateEmpty,
                      (Ptr{CameraListHandle},), ref)

        # Instanciate the object and associate its finalizer (in case of
        # subsequent errors).
        lst = finalizer(_finalize, new(ref[], sys))

        # Retrieve the camera list for the interface.
        @checked_call(:spinInterfaceGetCameras,
                      (InterfaceHandle, CameraListHandle),
                      handle(int), handle(lst))

        # Return the instanciated object.
        return lst
    end
end

mutable struct Camera <: SpinObject
    handle::CameraHandle
    system::System # needed to maintain a reference to the "system" instance
    function Camera(lst::CameraList, i::Integer)
        1 ≤ i ≤ length(lst) || error(
            "out of bound index in Spinnaker ", shortname(lst))
        sys = check(system(check(lst)))
        ref = Ref{CameraHandle}(0)
        @checked_call(:spinCameraListGet,
                      (CameraListHandle, Csize_t, Ptr{CameraHandle}),
                      handle(lst), i - 1, ref)
        return finalizer(_finalize, new(ref[], sys))
    end
end

# The `parent` member of a node map is needed to keep a reference on the
# associated object to avoid it being garbage collected while the node map is
# in use.  There are no functions in the SDK to release or destroy a node map,
# so there are no needs for a finalizer and a node map may be immutable.
struct NodeMap <: SpinObject
    handle::NodeMapHandle
    parent::Union{System,Interface,Camera}
end

# The `parent` member of a node is needed to keep a reference on the associated
# mode map and its parent object so as to avoid them being garbage collected
# while the node is in use.  The function `spinNodeMapReleaseNode` must be
# called to release a node, so a node must have a finalizer and is thus a
# mutable object.
mutable struct Node <: SpinObject
    handle::NodeHandle
    parent::NodeMap # needed to maintain a reference to the parent node map instance
    function Node(nodemap::NodeMap, str::AbstractString)
        check(parent(nodemap))
        ref = Ref{NodeHandle}(0)
        @checked_call(:spinNodeMapGetNode,
                      (NodeMapHandle, Cstring, Ptr{NodeHandle}),
                      handle(nodemap), str, ref)
        return finalizer(_finalize, new(ref[], nodemap))
    end
    function Node(nodemap::NodeMap, i::Integer)
        # Retrieving the length of the node map costs some time, but the error
        # returned by spinNodeMapGetNodeByIndex when the index is invalid is
        # SPINNAKER_ERR_ERROR which is not very indicative.  So we only compare
        # the index to the node map length in case of error.  When error is
        # SPINNAKER_ERR_ERROR while the index is in bounds (which does occur),
        # a "null" node is returned.
        check(parent(nodemap))
        ref = Ref{NodeHandle}(0)
        inbounds = (i ≥ 1) # check lower bound
        if inbounds
            err = @unchecked_call(:spinNodeMapGetNodeByIndex,
                                  (NodeMapHandle, Csize_t, Ptr{NodeHandle}),
                                  handle(nodemap), i - 1, ref)
            if err != SPINNAKER_ERR_SUCCESS
                inbounds &= (i ≤ length(nodemap)) # check upper bound
                if inbounds && err != SPINNAKER_ERR_ERROR
                    # error not due to out of bounds index
                    throw_call_error(err, :spinNodeMapGetNodeByIndex)
                end
            end
        end
        inbounds || error(
            "out of bounds index in Spinnaker ", shortname(nodemap))
        return finalizer(_finalize, new(ref[], nodemap))
    end
end

"""
    SpinnakerCameras.NodeType

enumeration of the possible types of a node.

"""
@enum NodeType::Cenum begin
    ValueNode
    BaseNode
    IntegerNode
    BooleanNode
    FloatNode
    CommandNode
    StringNode
    RegisterNode
    EnumerationNode
    EnumEntryNode
    CategoryNode
    PortNode
    UnknownNode = -1
end

"""
    SpinnakerCameras.AccessMode

enumeration of the possible access modes of a node.

"""
@enum AccessMode::Cenum begin
    NI
    NA
    WO
    RO
    RW
    UndefinedAccesMode
    CycleDetectAccesMode
end

"""
    SpinnakerCameras.Visibility

enumeration of the possible recommended visibilities of a node.

"""
@enum Visibility::Cenum begin
    Beginner = 0
    Expert = 1
    Guru = 2
    Invisible = 3
    UndefinedVisibility = 99
end

"""
    SpinnakerCameras.CachingMode

enumeration of the possible caching modes of a register.

"""
@enum CachingMode::Cenum begin
    NoCache              # Do not use cache
    WriteThrough         # Write to cache and register
    WriteAround          # Write to register, write to cache on read
    UndefinedCachingMode # Not yet initialized
end

"""
    SpinnakerCameras.NameSpace

enumeration of the possible namespaces of a register.

"""
@enum NameSpace::Cenum begin
    Custom             # name resides in custom namespace
    Standard           # name resides in one of the standard namespaces
    UndefinedNameSpace # Object is not yet initialized
end

mutable struct Image <: SpinObject
    # The `created` member of images is to distinguish between the two kinds of
    # images provided by the Spinnaker C SDK:
    #
    # - images obtained from a call to `spinCameraGetNextImage` or
    #   `spinCameraGetNextImageEx` and released by `spinImageRelease`,
    #
    # - images created by `spinImageCreateEmpty`, `spinImageCreateEx`,
    #   `spinImageCreateEx2`, or `spinImageCreate`, and destroyed by
    #   `spinImageDestroy`.
    #
    handle::ImageHandle
    created::Bool
    Image(handle::ImageHandle, created::Bool) =
        finalizer(_finalize, new(handle, created))
    Image() = Image(ImageHandle(0), false)
end
