#
# camera.jl
#
# general camera status functions
# APIs
#

#------------------------------------------------------------------------------

get_img(cam::Camera) = getfield(cam, :img_buf)
get_ts(cam::Camera) = getfield(cam, :ts)

#==
    Configuration functions (reading)
==#

"""
   exposuretime = SpinnakerCameras.read_exposuretime(camera)
   Returns the exposure time currently in use.
""" read_exposuretime
function read_exposuretime(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["ExposureTime"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Cdouble, camNode, false)
    finalize(_camNodemape)
    return val
end

"""
   gainvalue = SpinnakerCameras.read_gainvalue(camera)
   Returns the gain value currently in use.
""" read_gainvalue
function read_gainvalue(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["Gain"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Cdouble, camNode, false)
    finalize(_camNodemape)
    return val
end

"""
   reverseX = SpinnakerCameras.read_reverseX(camera)
   Returns the reverseX value currently in use.
""" read_reverseX
function read_reverseX(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["ReverseX"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Int64, camNode, false)
    finalize(_camNodemape)
    return val==1
end

"""
   reverseY = SpinnakerCameras.read_reverseY(camera)
   Returns the reverseY value currently in use.
""" read_reverseY
function read_reverseY(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["ReverseY"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Int64, camNode, false)
    finalize(_camNodemape)
    return val==1
end

"""
   width = SpinnakerCameras.read_width(camera)
   Returns the height currently in use.
""" read_width
function read_width(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["Width"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Int64, camNode, false)
    finalize(_camNodemape)
    return val
end

"""
   height = SpinnakerCameras.read_height(camera)
   Returns the height currently in use.
""" read_height
function read_height(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["Height"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Int64, camNode, false)
    finalize(_camNodemape)
    return val
end

"""
   offsetX = SpinnakerCameras.read_offsetX(camera)
   Returns the offsetX currently in use.
""" read_offsetX
function read_offsetX(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["OffsetX"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Int64, camNode, false)
    finalize(_camNodemape)
    return val
end


"""
   offsetY = SpinnakerCameras.read_offsetY(camera)
   Returns the offsetY currently in use.
""" read_offsetY
function read_offsetY(camera::Camera)
    _camNodemape = camera.nodemap
    camNode = _camNodemape["OffsetY"]
    isavailable(camNode)
    isreadable(camNode)
    val =  getvalue(Int64, camNode, false)
    finalize(_camNodemape)
    return val
end

#==
    Configuration functions (writing)
==#

"""
   SpinnakerCameras.setAcquisitionmode(camera, mode_str)
   Set acquisition mode. Returns the updated acquisition mode.
""" set_acquisitionmode
function set_acquisitionmode(camera::Camera, mode_str::AbstractString)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    cameraNodemap = camera.nodemap
    # get acquisition node
    acquisitionModeNode = cameraNodemap["AcquisitionMode"]

    # check availability and readability
    isavailable(acquisitionModeNode)
    isreadable(acquisitionModeNode)

    # get entry node
    acquisitionModeEntryNode = EntryNode(acquisitionModeNode, mode_str)

    # get entry node value
    mode_num = getEntryValue(acquisitionModeEntryNode)
    # set the acquisitionmode node
    isavailable(acquisitionModeNode)
    iswritable(acquisitionModeNode)

    setEnumValue(acquisitionModeNode, mode_num)

    finalize(acquisitionModeEntryNode)
    finalize(acquisitionModeNode)
    finalize(cameraNodemap)

    # Restarting the camera if needed
    if flag_streaming
        start(camera)
    end

    # Return the updated value
    return mode_str
end


"""
   SpinnakerCameras.set_exposure(camera,exposure_time)
   Set exposure time. Returns the updated exposure time.
""" set_exposuretime
function set_exposuretime(camera::Camera, exposure_time::Float64)
    _camNodemape = camera.nodemap

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    # turn off automatic exposure time
    exposureAutoNode = _camNodemape["ExposureAuto"]
    isavailable(exposureAutoNode)
    isreadable(exposureAutoNode)
    exposureOffNode = EntryNode(exposureAutoNode, "Off")
    exposureOffInt = getEntryValue(exposureOffNode)

    isavailable(exposureAutoNode)
    iswritable(exposureAutoNode)
    setEnumValue(exposureAutoNode, exposureOffInt)

    # check maximum exposure time
    exposureTimeNode = _camNodemape["ExposureTime"]
    isavailable(exposureTimeNode)
    isreadable(exposureTimeNode)
    exposureMax = getmax(Float64, exposureTimeNode)
    exposureMin = getmin(Float64, exposureTimeNode)

    # checking the extremal bound
    if exposure_time > exposureMax
        exposure_time = exposureMax
        @warn "exposure time is bounded to $exposure_time"
    elseif exposure_time < exposureMin
        exposure_time = exposureMin
        @warn "exposure time is bounded to $exposure_time"
    end

    isavailable(exposureTimeNode)
    iswritable(exposureTimeNode)
    setValue(exposureTimeNode, exposure_time)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Return the updated value
    return read_exposuretime(camera)
end

"""
   SpinnakerCameras.reset_exposure(camera)
   Reset the exposure time of the camera. Returns the updated value.
""" reset_exposure

function reset_exposure(camera::Camera)
    _camNodemape =  camera.nodemap

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    # turn off automatic exposure time
    exposureAutoNode = _camNodemape["ExposureAuto"]
    isavailable(exposureAutoNode)
    isreadable(exposureAutoNode)
    exposureOnNode = EntryNode(exposureAutoNode, "Continuous")
    exposureOnInt = getEntryValue(exposureOnNode)

    isavailable(exposureAutoNode)
    iswritable(exposureAutoNode)
    setEnumValue(exposureAutoNode, exposureOnInt)

    # Restarting the camera if needed
    if flag_streaming
      start(camera)
    end

    # Return the updated value
    return read_exposuretime(camera)
end


"""
     SpinnakerCameras.set_gainvalue(camera, gainvalue)
     Set the gain value of the camera. Returns the updated value.
""" set_gainvalue

function set_gainvalue(camera::Camera, gainvalue::Float64)
    _camNodemape = camera.nodemap

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    # turn off automatic exposure time
    gainAutoNode = _camNodemape["GainAuto"]
    isavailable(gainAutoNode)
    isreadable(gainAutoNode)
    gainOffNode = EntryNode(gainAutoNode, "Off")
    gainOffNodeInt = getEntryValue(gainOffNode)

    isavailable(gainAutoNode)
    iswritable(gainAutoNode)
    setEnumValue(gainAutoNode, gainOffNodeInt)

    # check maximum exposure time
    gainValueNode = _camNodemape["Gain"]
    isavailable(gainValueNode)
    isreadable(gainValueNode)
    gainMax = getmax(Float64, gainValueNode)
    gainMin = getmin(Float64, gainValueNode)

    # checking the extremal bound
    if gainvalue > gainMax
        gainvalue = gainMax
        @warn "gain value is bounded to $gainvalue"
    elseif gainvalue < gainMin
        gainvalue = gainMin
        @warn "gain value is bounded to $gainvalue"
    end

    isavailable(gainValueNode)
    iswritable(gainValueNode)
    setValue(gainValueNode, gainvalue)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_gainvalue(camera::Camera)
end

"""
    SpinnakerCameras.set_shuttermode(camera, shuttermode)
""" set_shuttermode

function set_shuttermode(camera::Camera, shuttermode::AbstractString)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get shuttermode node
    SensorShutterModeNode = _camNodemape["SensorShutterMode"]

    # check availability and readability
    isavailable(SensorShutterModeNode)
    isreadable(SensorShutterModeNode)

    # get entry node
    SensorShutterModeEntryNode = EntryNode(SensorShutterModeNode, shuttermode)

    # get entry node value
    mode_num = getEntryValue(SensorShutterModeEntryNode)

    # set the shuttermode node
    isavailable(SensorShutterModeNode)
    iswritable(SensorShutterModeNode)

    setEnumValue(SensorShutterModeNode, mode_num)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end
end

"""
    SpinnakerCameras.set_reverseX(camera,reverse_dir)
    Returns the updated value
""" set_reverseX
function set_reverseX(camera::Camera, reverse_dir::Bool)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get reverse node
    ReverseNode = _camNodemape["ReverseX"]

    # check availability and readability
    isavailable(ReverseNode)
    isreadable(ReverseNode)

    setValue(ReverseNode, reverse_dir)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_reverseX(camera)
end

"""
    SpinnakerCameras.set_reverseY(camera,reverse_dir)
    Returns the updated value
""" set_reverseY
function set_reverseY(camera::Camera, reverse_dir::Bool)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get reverse node
    ReverseNode = _camNodemape["ReverseY"]

    # check availability and readability
    isavailable(ReverseNode)
    isreadable(ReverseNode)

    setValue(ReverseNode, reverse_dir)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_reverseY(camera)
end

"""
    SpinnakerCameras.set_width(camera,width)
    Set the width of the acquired picture. It has to be a multiple of 16. It is
    also bounded by the offsetX value.
    Returns the updated value
""" set_width
function set_width(camera::Camera, width::Int64)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get reverse node
    WidthNode = _camNodemape["Width"]

    # check availability and readability
    isavailable(WidthNode)
    isreadable(WidthNode)
    widthMax = getmax(Int64, WidthNode)
    widthMin = getmin(Int64, WidthNode)

    # rounding to the closest multiple of 16
    step = 16
    width_new = Int64(step*round(width/step))
    if width_new != width
        @warn "width is rounded to $width_new"
    end

    # checking the extremal bounds
    if width_new > widthMax
        width_new = widthMax
        @warn "width is bounded to $width_new"
    elseif width_new < widthMin
        width_new = widthMin
        @warn "width is bounded to $width_new"
   end


    setValue(WidthNode, width_new)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_width(camera)
end

"""
    SpinnakerCameras.set_height(camera,height)
    Set the height of the acquired picture. It has to be a multiple of 2. It is
    also bounded by the offsetY value
""" set_height
function set_height(camera::Camera, height::Int64)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get reverse node
    HeightNode = _camNodemape["Height"]

    # check availability and readability
    isavailable(HeightNode)
    isreadable(HeightNode)
    heightMax = getmax(Int64, HeightNode)
    heightMin = getmin(Int64, HeightNode)

    # rounding to the closest multiple of 2
    step = 2
    height_new = Int64(step*round(height/step))
    if height_new != height
        @warn "height is rounded to $height_new"
    end

    # checking the extremal bounds
    if height_new > heightMax
        height_new = heightMax
        @warn "height is bounded to $height_new"
    elseif height_new < heightMin
        height_new = heightMin
        @warn "height is bounded to $height_new"
    end
    setValue(HeightNode, height_new)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_height(camera)
end

"""
    SpinnakerCameras.set_offsetX(camera,offsetx)
    Set the offset on the x-axis of the acquired picture. It has to be a
    multiple of 4. It is also bounded by the width value
""" set_offsetX
function set_offsetX(camera::Camera, offsetx::Int64)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get reverse node
    OffsetXNode = _camNodemape["OffsetX"]

    # check availability and readability
    isavailable(OffsetXNode)
    isreadable(OffsetXNode)
    offsetxMax = getmax(Int64, OffsetXNode)
    offsetxMin = getmin(Int64, OffsetXNode)

    # rounding to the closest multiple of 4
    step = 4
    offsetx_new = Int64(step*round(offsetx/step))
    if offsetx_new != offsetx
        @warn "offsetx is rounded to $offsetx_new"
    end

    # checking the extremal bounds
    if offsetx_new > offsetxMax
        offsetx_new = offsetxMax
        @warn "offsetx is bounded to $offsetx_new"
    elseif offsetx_new < offsetxMin
        offsetx_new = offsetxMin
        @warn "offsetx is bounded to $offsetx_new"
    end
    setValue(OffsetXNode, offsetx_new)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_offsetX(camera)
end

"""
    SpinnakerCameras.set_offsetY(camera,offsety)
    Set the offset on the y-axis of the acquired picture. It has to be a
    multiple of 2. It is also bounded by the width value
""" set_offsetY
function set_offsetY(camera::Camera, offsety::Int64)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    # get reverse node
    OffsetYNode = _camNodemape["OffsetY"]

    # check availability and readability
    isavailable(OffsetYNode)
    isreadable(OffsetYNode)
    offsetyMax = getmax(Int64, OffsetYNode)
    offsetyMin = getmin(Int64, OffsetYNode)

    # rounding to the closest multiple of 2
    step = 2
    offsety_new = Int64(step*round(offsety/step))
    if offsety_new != offsety
        @warn "offsetx is rounded to $offsety_new"
    end

    # checking the extremal bounds
    if offsety_new > offsetyMax
         offsety_new = offsetyMax
        @warn "offsetx is bounded to $offsety_new"
    elseif offsety_new < offsetyMin
        offsety_new = offsetyMin
       @warn "offsetx is bounded to $offsety_new"
    end
    setValue(OffsetYNode, offsety_new)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    # Returns the updated value
    return read_offsetY(camera)
end

"""
    SpinnakerCameras.set_pixelformat(camera, pixelformat)
""" set_pixelformat
function set_pixelformat(camera::Camera,pixelformat::String)

    # Stopping the camera if needed
    flag_streaming = isstreaming(camera)
    if flag_streaming
        stop(camera)
    end

    _camNodemape = camera.nodemap
    pixelformatNode = _camNodemape["PixelFormat"]
    # check availability and readability
    isavailable(pixelformatNode)
    isreadable(pixelformatNode)

    # get entry node
    pixelformatEntryNode = EntryNode(pixelformatNode,pixelformat)

    # get entry node value
    mode_num = getEntryValue(pixelformatEntryNode)
    # set the acquisitionmode node

    # check availability and readability
    isavailable(pixelformatNode)
    isreadable(pixelformatNode)
    setEnumValue(pixelformatNode, mode_num)

    finalize(pixelformatEntryNode)
    finalize(pixelformatNode)
    finalize(_camNodemape)

    # Restarting the camera if needed
    if flag_streaming
       start(camera)
    end

    return pixelformat
end

#---
#==
    camera OPERATION
==#
"""
    SpinnakerCameras.Camera(lst, i)

yields the `i`-th entry of Spinnaker interface list `lst`.  This is the same
as `lst[i]`.

""" Camera

"""
    SpinnakerCameras.initialize(cam)

initializes Spinnaker camera `cam`.

""" initialize

"""
    SpinnakerCameras.deinitialize(cam)

deinitializes Spinnaker camera `cam`.

""" deinitialize


"""
    SpinnakerCameras.start(cam)
    starts acquisition with Spinnaker camera `cam`.

""" start

"""
    SpinnakerCameras.stop(cam)
    stops acquisition with Spinnaker camera `cam`.


""" stop


for (jl_func, c_func) in ((:initialize,         :spinCameraInit),
                          (:deinitialize,       :spinCameraDeInit),
                          (:start,              :spinCameraBeginAcquisition),
                          (:stop,               :spinCameraEndAcquisition),)
    _jl_func = Symbol("_", jl_func)
    @eval begin
        $jl_func(obj::Camera) = $_jl_func(handle(obj))
        $_jl_func(ptr::CameraHandle) =
            @checked_call($c_func, (CameraHandle,), ptr)
    end
end

"""
    SpinnakerCameras.isinitialized(cam)

yields whether Spinnaker camera `cam` is initialized.

""" isinitialized

"""
    SpinnakerCameras.isstreaming(cam)

yields whether Spinnaker camera `cam` is currently acquiring images.

""" isstreaming

"""
    isvalid(cam)

yields whether Spinnaker camera `cam` is still valid for use.

""" isvalid

for (jl_func, c_func) in ((:isinitialized, :spinCameraIsInitialized),
                          (:isstreaming,   :spinCameraIsStreaming),
                          (:isvalid,       :spinCameraIsValid),)
    _jl_func = Symbol("_", jl_func)
    @eval begin
        $jl_func(obj::Camera) = $_jl_func(handle(obj))
        function $_jl_func(ptr::CameraHandle)
            isnull(ptr) && return false
            ref = Ref{SpinBool}(false)
            @checked_call($c_func, (CameraHandle, Ptr{SpinBool}), ptr, ref)
            return to_bool(ref[])
        end
    end
end

#--- Camera utils

function _reset(camera::Camera)
    _camNodemape = camera.nodemap
    deviceResetNode = _camNodemape["DeviceReset"]
    command_execute(deviceResetNode)
    print("Camera is reset... \n")
    return finalize(_camNodemape)
end

"""
    SpinnakerCameras.device_tempertaure(camera)
    return current device temperature in °C
""" camera_temperature

function camera_temperature(camera::Camera)
    _camNodemape =  camera.nodemap
    deviceTemperatureNode = _camNodemape["DeviceTemperature"]
    isavailable(deviceTemperatureNode)
    isreadable(deviceTemperatureNode)

    temperature =  getvalue(Cdouble, deviceTemperatureNode, true)
    finalize(_camNodemape)

    return  temperature
end


"""
   SpinnakerCameras.camera_maxExposureTime(camera)
   Returns the maximal exposure time of the camera
""" camera_maxExposureTime
function camera_maxExposureTime(camera::Camera)

    _camNodemape =  camera.nodemap

    # check maximum exposure time
    exposureTimeNode = _camNodemape["ExposureTime"]
    isavailable(exposureTimeNode)
    isreadable(exposureTimeNode)
    return getmax(Float64, exposureTimeNode)
end


"""
   SpinnakerCameras.camera_minExposureTime(camera)
   Returns the minimal exposure time of the camera
""" camera_maxExposureTime
function camera_minExposureTime(camera::Camera)

    _camNodemape =  camera.nodemap

    # check maximum exposure time
    exposureTimeNode = _camNodemape["ExposureTime"]
    isavailable(exposureTimeNode)
    isreadable(exposureTimeNode)
    return getmin(Float64, exposureTimeNode)
end


"""
   SpinnakerCameras.camera_minGainValue(camera)
   Returns the minimal exposure time of the camera
""" camera_minGainValue
function camera_minGainValue(camera::Camera)

    _camNodemape =  camera.nodemap

    # check maximum exposure time
    gainValueNode = _camNodemape["Gain"]
    isavailable(gainValueNode)
    isreadable(gainValueNode)
    return getmin(Float64, gainValueNode)
end


"""
   SpinnakerCameras.camera_maxGainValue(camera)
   Returns the minimal exposure time of the camera
""" camera_minGainValue
function camera_maxGainValue(camera::Camera)

    _camNodemape =  camera.nodemap

    # check maximum exposure time
    gainValueNode = _camNodemape["Gain"]
    isavailable(gainValueNode)
    isreadable(gainValueNode)
    return getmax(Float64, gainValueNode)
end


function _finalize(obj::Camera)
    ptr = handle(obj)
    if _isinitialized(ptr)
        _deinitialize(ptr)
    end
    if !isnull(ptr)

        err1 = @unchecked_call(:spinCameraDeInit, (CameraHandle,), ptr)
        err2 = @unchecked_call(:spinCameraRelease, (CameraHandle,), ptr)
        _check(err1,:spinCameraDeInit)
        _check(err2,:spinCameraRelease)

        _clear_handle!(obj)
    end

    return nothing
end
