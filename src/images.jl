#
# images.jl -
#
# Management of images in the Julia interface to the Spinnaker SDK.
#
#------------------------------------------------------------------------------


function _finalize(obj::Image)
    ptr = handle(obj)
    if !isnull(ptr)
        _clear_handle!(obj)
        if getfield(obj, :created)
            setfield!(obj, :created, false)
            @checked_call(:spinImageDestroy, (ImageHandle,), ptr)
        else
            @checked_call(:spinImageRelease, (ImageHandle,), ptr)

        end
    end
    return nothing
end

"""

    yiedls the next image from camera `cam` waiting no longer than `secs` seconds.

    See [`SpinnakerCameras.Image`](@ref) for properties of images.

"""
function next_image(camera::Camera)
    ref = Ref{ImageHandle}(0)
    @checked_call(:spinCameraGetNextImage,
                  (CameraHandle, Ptr{ImageHandle}),
                  handle(camera), ref)
    return Image(ref[], false)
end

function next_image(cameraHandle::CameraHandle)
    ref = Ref{ImageHandle}(0)
    @checked_call(:spinCameraGetNextImage,
                  (CameraHandle, Ptr{ImageHandle}),
                  cameraHandle, ref)
    return Image(ref[], false)
end

function next_image(camera::Camera, seconds::Real)
    ref = Ref{ImageHandle}(0)
    milliseconds = round(Int64, seconds*1_000)
    @checked_call(:spinCameraGetNextImageEx,
                  (CameraHandle, Int64, Ptr{ImageHandle}),
                  handle(camera), milliseconds, ref)
    return Image(ref[], false)
end

"""
    img = SpinnakerCameras.Image(pixelformat, (width, height); offsetx=0, offsety=0)

    builds a new Spinnaker image instance.  The pixel format is an integer, for
    example one of:

    - `SpinnakerCameras.PixelFormat_Mono8`

    - `SpinnakerCameras.PixelFormat_Mono16`

    The `img.key` syntax is supported for the following properties:

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

    Call `size(img)` to get its dimensions as a 2-tuple of `Int`s.

    See also [`SpinnakerCameras.next_image`](@ref).

""" Image

function Image(pixelformat::Integer,
               dims::Tuple{Integer,Integer};
               offsetx::Integer = 0,
               offsety::Integer = 0)
    width, height = dims
    width   ≥ 1 || throw(ArgumentError("invalid image width"))
    height  ≥ 1 || throw(ArgumentError("invalid image height"))
    offsetx ≥ 0 || throw(ArgumentError("invalid image X-offset"))
    offsety ≥ 0 || throw(ArgumentError("invalid image Y-offset"))
    ref = Ref{ImageHandle}(0)
    @checked_call(
        :spinImageCreateEx,
        (Ptr{ImageHandle}, Csize_t, Csize_t, Csize_t, Csize_t, Cenum, Ptr{Cvoid}),
        ref, width, height, offsetx, offsety, pixelformat, C_NULL)
    return Image(ref[], true)
end


size(img::Image) = (Int(img.width), Int(img.height))

getproperty(img::Image, sym::Symbol) = getproperty(img, Val(sym))

setproperty!(img::Image, sym::Symbol, val) =
    error("members of Spinnaker ", shortname(img), " are read-only")


# Getter functions
# property table
propertynames(::Image) = (
    :bitsperpixel,
    :buffersize,
    :data,
    :privatedata,
    :frameid,
    :height,
    :id,
    :offsetx,
    :offsety,
    :paddingx,
    :paddingy,
    :payloadtype,
    :pixelformat,
    :pixelformatname,
    :size,
    :stride,
    :timestamp,
    :validpayloadsize,
    :width,
    :completeness
    :status)

#dispatch
for (sym, func, type) in (
    (:bitsperpixel,     :spinImageGetBitsPerPixel,     Csize_t),
    (:buffersize,       :spinImageGetBufferSize,       Csize_t),
    (:privatedata,      :spinImageGetPrivateData,      Ptr{Cvoid}),
    (:frameid,          :spinImageGetFrameID,          UInt64),
    (:height,           :spinImageGetHeight,           Csize_t),
    (:id,               :spinImageGetID,               UInt64),
    (:offsetx,          :spinImageGetOffsetX,          Csize_t),
    (:offsety,          :spinImageGetOffsetY,          Csize_t),
    (:paddingx,         :spinImageGetPaddingX,         Csize_t),
    (:paddingy,         :spinImageGetPaddingY,         Csize_t),
    (:payloadtype,      :spinImageGetPayloadType,      Csize_t),
    (:pixelformat,      :spinImageGetPixelFormat,      Cenum),
    (:size,             :spinImageGetSize,             Csize_t),
    (:stride,           :spinImageGetStride,           Csize_t),
    (:timestamp,        :spinImageGetTimeStamp,        UInt64),
    (:tlpixelformat,    :spinImageGetTLPixelFormat,    UInt64),
    (:validpayloadsize, :spinImageGetValidPayloadSize, Csize_t),
    (:width,            :spinImageGetWidth,            Csize_t),
    (:incomplete,       :spinImageIsIncomplete,        SpinBool),
    (:status,           :spinImageGetStatus,           ImageStatus)
    )

    @eval function getproperty(img::Image, ::$(Val{sym}))
        ref = Ref{$type}(0)
        @checked_call($func, (ImageHandle, Ptr{$type}), handle(img), ref)
        return ref[]
    end
end

# get data
function getproperty(img::Image , ::Val{:data})
    ref = Ref{Ptr{Cvoid}}(0)
    @checked_call(:spinImageGetData,(ImageHandle, Ptr{Ptr{Cvoid}}), handle(img), ref)
    dataPtr = ref[]
    #image size
    imgH = convert(Int64,img.height)
    imgW = convert(Int64,img.width)

    dataArr = unsafe_wrap(Array{UInt8,2}, Ptr{UInt8}(dataPtr), (imgH,imgW))
    return dataArr

end

function getproperty(img::Image, ::Val{:pixelformatname})
    # FIXME: first call with NULL buffer to get the size.
    buff = Vector{UInt8}(undef, 32)
    size = Ref{Csize_t}(0)
    while true
        size[] = length(buff)
        err = @unchecked_call(:spinImageGetPixelFormatName,
                              (ImageHandle, Ptr{UInt8}, Ptr{Csize_t}),
                              handle(img), buff, size)
        if err == SPINNAKER_ERR_SUCCESS
            return String(resize!(buff, size[] - 1))
        elseif err == SPINNAKER_ERR_INVALID_BUFFER
            # Double the buffer size.
            resize!(buff, 2*length(buff))
        else
            throw(CallError(err, :spinImageGetPixelFormatName))
        end
    end
end


"""
    SpinnakerCameras.save_image(image, filename)

save the image contained in the handle in the given filename

""" save_image

save_image(image::Image, fname::AbstractString)= @checked_call(:spinImageSaveFromExt,
                                                    (ImageHandle, Cstring),
                                                    handle(image), fname)
