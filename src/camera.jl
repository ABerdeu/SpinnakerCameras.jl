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
    Configuration functions
==#

"""
   SpinnakerCameras.setAcquisitionmode(camera, mode_str)
   Set acquisition mode
""" set_acquisitionmode
function set_acquisitionmode(camera::Camera, mode_str::AbstractString)

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

end


"""
   SpinnakerCameras.set_exposure(camera,exposure_time)

""" set_exposuretime
function set_exposuretime(camera::Camera, exposure_time::Float64)
    _camNodemape = camera.nodemap

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
   exposure_time > exposureMax ? exposure_time = exposureMax : nothing

   isavailable(exposureTimeNode)
   iswritable(exposureTimeNode)
   setValue(exposureTimeNode, exposure_time)

end

"""
   SpinnakerCameras.reset_exposure(camera)
""" reset_exposure

function reset_exposure(camera::Camera)
    _camNodemape =  camera.nodemap

   # turn off automatic exposure time
   exposureAutoNode = _camNodemape["ExposureAuto"]
   isavailable(exposureAutoNode)
   isreadable(exposureAutoNode)
   exposureOnNode = EntryNode(exposureAutoNode, "Continuous")
   exposureOnInt = getEntryValue(exposureOnNode)

   isavailable(exposureAutoNode)
   iswritable(exposureAutoNode)
   setEnumValue(exposureAutoNode, exposureOnInt)
end

"""
   SpinnakerCameras.read_exposuretime(camera,exposure_time)

""" read_exposuretime
function read_exposuretime(camera::Camera)
    _camNodemape = camera.nodemap
    exposureTimeNode = _camNodemape["ExposureTime"]
    isavailable(exposureTimeNode)
    isreadable(exposureTimeNode)
    val =  getvalue(Cdouble, exposureTimeNode, false)
    finalize(_camNodemape)
    return val
end


"""
 SpinnakerCameras.set_gainvalue(camera, gainvalue)

""" set_gainvalue

function set_gainvalue(camera::Camera, gainvalue::Float64)
    _camNodemape = camera.nodemap

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
   gainvalue > gainMax ? gainvalue = gainMax : nothing

   isavailable(gainValueNode)
   iswritable(gainValueNode)
   setValue(gainValueNode, gainvalue)
end

"""
    SpinnakerCameras.set_shuttermode(camera, shuttermode)
""" set_shuttermode

function set_shuttermode(camera::Camera, shuttermode::AbstractString)

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
end

"""
    SpinnakerCameras.set_reverse(cameara,reverse_dir)
""" set_reversex
function set_reversex(camera::Camera, action::Bool)

    if action
        _camNodemape = camera.nodemap
        # get reverse node
        ReverseNode = _camNodemape["ReverseX"]

        # check availability and readability
        isavailable(ReverseNode)
        isreadable(ReverseNode)

        setValue(ReverseNode,true)
    else
        nothing
    end
end

function set_reversey(camera::Camera, action::Bool)
    if action

        _camNodemape = camera.nodemap
        # get reverse node
        ReverseNode = _camNodemape["ReverseY"]

        # check availability and readability
        isavailable(ReverseNode)
        isreadable(ReverseNode)

        setValue(ReverseNode,true)
    else
        nothing
    end
end

# FIXME check bounds
"""
    SpinnakerCameras.set_width(cameara,width)
""" set_width
function set_width(camera::Camera, width::Int64)

    _camNodemape = camera.nodemap
    # get reverse node
    WidthNode = _camNodemape["Width"]

    # check availability and readability
    isavailable(WidthNode)
    isreadable(WidthNode)
    widthMax = getmax(Int64, WidthNode)
    widthMin = getmin(Int64, WidthNode)

    # rounding to 4-byte integer

    if width > widthMax
         width = widthMax
        @warn "width is bounded to $width"
    elseif width < widthMin
        width = widthMin
        @warn "width is bounded to $width"
   end


    setValue(WidthNode,width)
end

"""
    SpinnakerCameras.set_height(cameara,height)
""" set_height
function set_height(camera::Camera, height::Int64)

    _camNodemape = camera.nodemap
    # get reverse node
    HeightNode = _camNodemape["Height"]

    # check availability and readability
    isavailable(HeightNode)
    isreadable(HeightNode)
    heightMax = getmax(Int64, HeightNode)
    heightMin = getmin(Int64, HeightNode)

    if height > heightMax
         height = heightMax
        @warn "height is bounded to $height"
    elseif height < heightMin
        height = heightMin
       @warn "height is bounded to $height"
    end
    setValue(HeightNode,height)
end

"""
    SpinnakerCameras.set_offsetX(cameara,offsetx)
""" set_offsetX
function set_offsetX(camera::Camera, offsetx::Int64)

    _camNodemape = camera.nodemap
    # get reverse node
    OffsetXNode = _camNodemape["OffsetX"]

    # check availability and readability
    isavailable(OffsetXNode)
    isreadable(OffsetXNode)
    offsetxMax = getmax(Int64, OffsetXNode)
    offsetxMin = getmin(Int64, OffsetXNode)
    if offsetx > offsetxMax
         offsetx = offsetxMax
        @warn "offsetx is bounded to $width"
    elseif offsetx < offsetxMin
        offsetx = offsetxMin
       @warn "offsetx is bounded to $width"
    end
    setValue(OffsetXNode,offsetx)
end

"""
    SpinnakerCameras.set_offsetY(camera,offsety)
""" set_offsetY
function set_offsetY(camera::Camera, offsety::Int64)

    _camNodemape = camera.nodemap
    # get reverse node
    OffsetYNode = _camNodemape["OffsetY"]

    # check availability and readability
    isavailable(OffsetYNode)
    isreadable(OffsetYNode)
    offsetyMax = getmax(Int64, OffsetYNode)
    offsetyMin = getmin(Int64, OffsetYNode)
    if offsety > offsetyMax
         offsety = offsetyMax
        @warn "offsetx is bounded to $width"
    elseif offsety < offsetyMin
        offsety = offsetyMin
       @warn "offsetx is bounded to $width"
    end
    setValue(OffsetYNode,offsety)
end

"""
    SpinnakerCameras.set_pixelformat(camera, pixelformat)
""" set_pixelformat
function set_pixelformat(camera::Camera,pixelformat::String)
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

end

#---
#==
    CAMEARA OPERATION
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

"""
    Camera operations

    work
    stop
    abor
    configure
""" Camera_operations
"""
    Work
    create image buffer, and start image acquisition.
""" work
function working(camNum::Int64,T::Type)
      w = workers()

      try
         remote_do(SpinnakerCameras.work,w[1],camNum,T)

     catch e
         @info e
      end
     return w[1]
 end


function work(camNum::Int64, T::Type)
    Base.exit_on_sigint(false)

    system = SpinnakerCameras.System()
    camList = SpinnakerCameras.CameraList(system)
    camNum = length(camList)

    if camNum == 0
        finalize(camList)
        finalize(system)
        throw("No cameras found... ")

    end
    camera = camList[camNum]

    SpinnakerCameras.initialize(camera)
    # set acquisition mode
    SpinnakerCameras.set_acquisitionmode(camera, "Continuous")

    # attach shared array in a remote process
    img_array, imgTime_array = SpinnakerCameras.attach_remote_process(T)
    # begin acquisition
    SpinnakerCameras.start(camera)
    counter = 0
    # pack = SpinnakerCameras.DataPack()
    try
        while true
            #get image
            img =
            try
                SpinnakerCameras.next_image(camera,0.5)
            catch ex

                if (!isa(ex, SpinnakerCameras.CallError) ||
                    ex.code != SpinnakerCameras.SPINNAKER_ERR_TIMEOUT)
                    rethrow(ex)
                else
                    @warn "image corrupted"
                end
                nothing
            end

            if img.incomplete == 1 && img.status != 0
               @goto clear_img
            end

            counter +=1

            ts = img.timestamp
            img_data = @view img.data[:,:]

            # write to remtoe camera shared array
            wrlock(img_array,1.0) do
                copyto!(img_array, img_data)
            end

            wrlock(imgTime_array,1.0) do
                imgTime_array[1] = ts
            end
            # write(f,"$counter\n")
            @label clear_img
                SpinnakerCameras.finalize(img)

        end
    catch e
        SpinnakerCameras.stop(camera)
        if e isa InterruptException
            @info "Acquisition loop is terminated"
            try
                SpinnakerCameras.finalize(img)
            catch e
                if !(e isa UndefVarError)
                    rethrow(e)
                end
            end
            return nothing
        else
            rethrow(e)
            return nothing
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
""" camear_temperature

function camera_temperature(camera::Camera)
    _camNodemape =  camera.nodemap
    deviceTemperatureNode = _camNodemape["DeviceTemperature"]
    isavailable(deviceTemperatureNode)
    isreadable(deviceTemperatureNode)

    temperature =  getvalue(Cdouble, deviceTemperatureNode, true)
    finalize(_camNodemape)

    return  temperature
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
