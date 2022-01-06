# Julia interface to Spinnaker cameras

The `SpinnakerCameras` package is to use cameras via the Spinnaker SDK
(Software Development Kit).

## Installation

Copy file `deps/example-deps.jl` as `deps/deps.jl` and edit the value of
constant `lib` to reflect the full path to the Spinnaker SDK dynamic library
for C code.


## Usage

### System, interface and camera objects

Compared to the Spinnaker SDK for C code, the managment of objects is much
simplified by the Julia interface.  For instance, Spinnaker objects are
automatically released or destroyed when their Julia counterpart is rabage
collected.

To deal with Spinnaker cameras and interfaces, you must first get an instance
of the Spinnaker object system:

```julia
using SpinnakerCameras
system = SpinnakerCameras.System()
```

To retrieve a list of Spinnaker interfaces to which cameras can be connected,
call one of:

```julia
interfaces = system.interfaces
interfaces = SpinnakerCameras.InterfaceList(system)
```

To get a specific interface instance, say the `i`-th one, call one of:

```julia
interface = SpinnakerCameras.Interface(interfaces, i)
interface = interfaces[i]
```

which are completely equivalent.  As you may expect, calling
`length(interfaces)` yields the number of entries in the interface list.  Note
that the indices of Spinnaker interfaces, cameras, enumerations, and nodes are
1-based in Julia.

To retrieve a list of all cameras connected to the system, call one of:

```julia
cameras = system.cameras
cameras = SpinnakerCameras.CameraList(system)
```

To retrieve a list of cameras connected to a given interface, call one of:

```julia
cameras = interface.cameras
cameras = SpinnakerCameras.CameraList(interface)
```

Calling `length(cameras)` yields the number of cameras in the list.

An instance of a specific camera, say the `i`-th one, is given by:

```julia
camera = SpinnakerCameras.Camera(cameras, i)
camera = cameras[i]
```

which are completely equivalent.

Note that you may chain operations.  For instance, you may do:

```julia
camera = system.interfaces[2].cameras[1]
```

to retrieve the 1st camera on the 2nd interface.  Chaining operations however
results in creating temporary objects which are automatically released or destroyed
but which are only used once.

Lists of interfaces and lists of cameras are iterable so you may write:

```julia
for camera in system.cameras
    ...
end
```

to loop over the cameras of the system.


### Images

A Spinnaker image may be created by:

```julia
img = SpinnakerCameras.Image(pixelsformat, (width,height))
```

where `pixelsformat` is an integer specifying the pixel format (see enumeration
`spinImageFileFormat` in header `SpinnakerDefsC.h` for possible values) while
the 2-tuple `(width,height)` specifies the dimensions of the image in pixels.

An image may also be acquired from a camera (streaming acquisition must be
running):

```julia
img = SpinnakerCameras.next_image(camera)
```

which waits forever until a new image is available.  In general it is better to
specify a time limit, for instance:

```julia
secs = 5.0 # maximum number of seconds to wait
img = SpinnakerCameras.next_image(camera, secs)
```

If you want to catch timeout error, the following piece of code yields a result
`img` that is an image if a new image is acquirred before the time limit, or
`nothing` if the time limit is exceeded, and throws an exception otherwise:

```julia
img = try
    SpinnakerCameras.next_image(camera, secs)
catch ex
    if (!isa(ex, SpinnakerCameras.CallError) ||
        ex.code != SpinnakerCameras.SPINNAKER_ERR_TIMEOUT)
        rethrow(ex)
    end
    nothing
end
```

Images implement many properties.  For example:

```julia
img.bitsperpixel     # yields the number of bits per pixel of `img`
img.buffersize       # yields the buffer size of `img`
img.data             # yields the image data of `img`
img.privatedata      # yields the private data of `img`
img.frameid          # yields the frame Id of `img`
img.height           # yields the height of `img`
img.id               # yields the Id of `img`
img.offsetx          # yields the X-offset of `img`
img.offsety          # yields the Y-offset of `img`
img.paddingx         # yields the X-padding of `img`
img.paddingy         # yields the Y-padding of `img`
img.payloadtype      # yields the payload type of `img`
img.pixelformat      # yields the pixel format of `img`
img.pixelformatname  # yields the pixel format name of `img`
img.size             # yields the size of `img` (number of bytes)
img.stride           # yields the stride of `img`
img.timestamp        # yields the timestamp of `img`
img.validpayloadsize # yields the valid payload size of `img`
img.width            # yields the width of `img`
```
## Camera server
`Taobindings.jl` provides tools to create camera server and implement  shared memory space . To allow for multiprocessing, Distributed and additional 1 worker process must be added proir to importing the `SpinnakerCameras` package

```julia
using Distributed
addprocs(1)
@everywhere import SpinnakerCameras as SC

```

A camera server is an interface to client processes trying to control a camera. To create a camera server from a physical camera, a `SharedCamera` has to be created. Then, a camera that we want to be shared has to be registered to the shared camera (multiple cameras can be registered to the shared camera). A `RemoteCamera` , which in this package is equivalent to camera server in a sense, is created using the shared camera and a pre-defined buffer size and a concrete type of array element which must be of the pixel format type.

```julia
dev = SC.create(SC.SharedCamera)
shcam = SC.attach(SC.SharedCamera, dev.shmid)
SC.register(shcam,camera)

dims = (800,800)                                         # image size 800x800 pixels
remcam = SC.RemoteCamera{UInt8}(shcam, dims)             # UInt8 pixel format
```

`RemoteCamera` contains 2 shared arrays for image data. One is a shared array for image data. The other is for a timestamp. Another shared array is for a command sent by a client process. At present, it allows to have only one client. A client send a command to the RemoteCamera by writing to the command shared array. The RemoteCamera reads the command and invokes the corresponding camera operation.

To start running a camera server, the shmids of the image buffer, the image timestamp buffer, and the command shared array need to be broadcasted via writing to a file `shmids.txt` at `/tmp/SpinnakerCameras/`

```julia
img_shmid = SC.get_shmid(remcam.img)
imgTime_shmid = SC.get_shmid(remcam.imgTime)
cmds_shmid = SC.get_shmid(remcam.cmds)
shmids = [img_shmid,imgTime_shmid,cmds_shmid]
SC.broadcast_shmids(shmids)
```
Then, the RemoteCamera can start listening by

```julia
RemoteCameraEngine = SC.listening(shcam, remcam)
```

A set of camera parameters is stored in `ImageConfigContext` struct.

```julia
mutable struct ImageConfigContext
    width::Int64
    height::Int64
    offsetX::Int64
    offsetY::Int64
    pixelformat::String

    gainvalue::Float64
    exposuretime::Float64
    reversex::Bool
    reversey::Bool

    function ImageConfigContext()
        max_width = 2048
        max_height = 1536
        return new(max_width, max_height, 0, 0,"Mono8",
                    10.0, 100.0, false, false)
    end
end
```

To set parameters of a camera such as exposure time, the client has to write to a file `img_config.txt` at `/tmp/SpinnakerCameras`. After finish writing, the client can send a command to the RemoteCamera to re-configure the camera.

### Image acquisition
Image acquisition routine is spawned on a worker process. The image and timestamp are obtained from Spinnaker APIs and written to RemoteCamera shared arrays. The client can read from these shared arrays by attaching them to the local memory space.

TODO: a mechanism to notify the client when a new frame is updated.

**serial_camera_test.jl** contains an example of camera server\
**reader.jl** read data from the broadcasted shmids of the shared array and calculate acquisition rate. To be run on a seperate Julia RELP after **serial_camera_test.jl** has started.
