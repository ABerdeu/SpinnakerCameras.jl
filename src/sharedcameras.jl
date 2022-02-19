#
# cameras.jl --
#
# Management of cameras for the Julia interface to the C libraries of TAO, a
# Toolkit for Adaptive Optics.
#
#------------------------------------------------------------------------------
#
# This file is part of TAO software (https://git-cral.univ-lyon1.fr/tao)
# licensed under the MIT license.
#
# Copyright (C) 2018-2021, Éric Thiébaut.
#

propertynames(cam::SharedCamera) =
    (
     #tao attribute
     :owner,
     :shmid,
     :size,
     :lock,
     :attachedCam,
     :cameras,
     :img_config,
     :listlength,
     :last,
     :next,
     :lastTS,
     :nextTS

#==
    # device control
     # :modelname,
     :serialnumber,
     # :firmware_version,
     # :manufacturerinfo,
     :userid,
     :TLtype,
     :timestamp
     :temperature,

     # Analog Control
     :gain,
     # :gainauto

     # image format control
     # :sensorencoding,
     :sensorheight,
     :sensorwidth,
     :pixelhieght,
     :pixelwidth,
     :shuttermode,
     :reversex,
     :reversey,
     :size,
     :height,
     :pixelformat,
     :width,
     # :xbin,
     # :ybin
     :xoff,
     :yoff,
     :compressionmode,

     # Acquisition Control
     :framerate,
     :exposuretime,
==#

     )
# dispatch for sharedcamera
getproperty(dev::SharedCamera, sym::Symbol) =
                            getproperty(dev,Val(sym))

#dispatch tao attribute
getproperty(dev::SharedCamera,::Val{:shmid}) = getattribute(dev,Val(:shmid))
getproperty(dev::SharedCamera,::Val{:size}) = getattribute(dev,Val(:size))
getproperty(dev::SharedCamera,::Val{:owner}) = getattribute(dev,Val(:owner))

# relay to taolib
getattribute(obj::SharedCamera, ::Val{:shmid}) =
    ccall((:tao_get_shared_data_shmid, taolib), ShmId,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::SharedCamera, ::Val{:size}) =
    ccall((:tao_get_shared_data_size, taolib), Csize_t,
          (Ptr{AbstractSharedObject},), obj)

getattribute(obj::SharedCamera, ::Val{:owner}) =
  _pointer_to_string(ccall((:tao_get_shared_object_owner, taolib),
                             Ptr{UInt8}, (Ptr{AbstractSharedObject},), obj))


# dispatch Julia properties
getproperty(dev::SharedCamera, ::Val{sym}) where{sym} =
                                        getfield(dev, sym)

# property is read-only
setproperty!(dev::SharedCamera, sym::Symbol, val)  =
                                setattribute!(dev,Val(sym),val)


# attribute manipulation function
inc_attachedCam(dev::SharedCamera) = begin
                        val = dev.attachedCam +1
                        setfield!(dev, :attachedCam,Int8(val))
                    end

# get_pixeltype(dev::SharedCamera) = PixelType(dev.img_config.pixelformat)
#TODO: PixelType = > pair pixel format to Julia Type

for sym in (
            :last,
            :next,
            :lastTs,
            :nextTS
                    )
    _sym = "$sym"
    @eval $(Symbol("set_",sym))(dev::SharedCamera,val::Integer) =
                                    setfield!(dev,Symbol($_sym),Int16(val))
end


#--- RemoteCamera property

propertynames(cam::RemoteCamera) =
    (
      # RemoteCamera properties
      :arrays,
      :timestamps,
      :img,
      :imgTime,
      :cmds,
      :time_origin,
      :no_cmds,
      # SharedCamera
      :owner,
      :shmid,
      :lock,
      :attachedcam,
      :listlength,
      :state,
      :counter,
      :last,
      :next,
      :lastTS,
      :nextTS

     )

#top level dispatch
getproperty(remcam::RemoteCamera,sym::Symbol) = getproperty(remcam, Val(sym))

#RemoteCamera properties (read-only)
for sym in (:timestamps,
            :img,
            :imgTime,
            :cmds,
            :shmids,
            :arrays,
            :device,
            :no_cmds,
            :time_origin,
            :worker_pid)
    _sym = "$sym"
    @eval getproperty(remoteCam::RemoteCamera,::$(Val{sym})) =
                        getfield(remoteCam,Symbol($_sym))
end


# Shared Camera properties
# getattribute(cam::RemoteCamera, ::Val{:lock}) = getfield(device(cam), :lock)
getproperty(remoteCam::RemoteCamera, key::Val)=
                                        getproperty(device(remoteCam), key)


# wall to setting properties
setproperty!(remoteCam::RemoteCamera, sym::Symbol, val) =
    throw_non_existing_or_read_only_attribute(remoteCam,sym)


# Constructors for `RemoteCamera`s.
# RemoteCamera(dev::SharedCamera) = RemoteCamera{dev.pixeltype}(dev)

# RemoteCamera(srv::ServerName) = RemoteCamera(attach(SharedCamera, srv))
# RemoteCamera{T}(srv::ServerName) where {T<:AbstractFloat} =
#     RemoteCamera{T}(attach(SharedCamera, srv))

#--- Abstract Monitor property
propertynames(monitor::RemoteCameraMonitor) = (
                                            :shmid,
                                            :cmds,
                                            :state,
                                            :procedures,
                                            :lock,
                                            :empty_cmds,
                                            :state_updating    )

getproperty(monitor::AbstractMonitor, sym::Symbol) = getproperty(monitor, Val(sym))

getproperty(monitor::RemoteCameraMonitor, ::Val{:cmds}) = getfield(monitor, :cmds)
getproperty(monitor::RemoteCameraMonitor, ::Val{:state}) = getfield(monitor, :state)
getproperty(monitor::RemoteCameraMonitor, ::Val{:procedures}) = getfield(monitor, :procedures)
getproperty(monitor::RemoteCameraMonitor, ::Val{:lock}) = getfield(monitor, :lock)

getproperty(monitor::RemoteCameraMonitor, ::Val{:shmid}) =
ccall((:tao_get_shared_data_shmid, taolib), ShmId,(Ptr{AbstractSharedObject},), monitor)

getproperty(monitor::RemoteCameraMonitor, ::Val{:empty_cmds}) = getfield(monitor, :empty_cmds)
getproperty(monitor::RemoteCameraMonitor, ::Val{:state_updating}) = getfield(monitor, :state_updating)



propertynames(monitor::SharedCameraMonitor) = (
                                                :cmd,
                                                :shmid,
                                                :start_status,
                                                :completion,
                                                :image_counter,
                                                :procedures,
                                                :lock,
                                                :no_cmd,
                                                :not_started,
                                                :not_complete)


getproperty(monitor::SharedCameraMonitor, ::Val{:cmd}) = getfield(monitor, :cmd)
getproperty(monitor::SharedCameraMonitor, ::Val{:start_status}) = getfield(monitor, :start_status)
getproperty(monitor::SharedCameraMonitor, ::Val{:completion}) = getfield(monitor, :completion)
getproperty(monitor::SharedCameraMonitor, ::Val{:image_counter}) = getfield(monitor, :image_counter)
getproperty(monitor::SharedCameraMonitor, ::Val{:procedures}) = getfield(monitor, :procedures)
getproperty(monitor::SharedCameraMonitor, ::Val{:lock}) = getfield(monitor, :lock)

getproperty(monitor::SharedCameraMonitor, ::Val{:shmid}) =
    ccall((:tao_get_shared_data_shmid, taolib), ShmId,(Ptr{AbstractSharedObject},), monitor)

getproperty(monitor::SharedCameraMonitor, ::Val{:no_cmd}) = getfield(monitor, :no_cmd)
getproperty(monitor::SharedCameraMonitor, ::Val{:not_started}) = getfield(monitor, :not_started)
getproperty(monitor::SharedCameraMonitor, ::Val{:not_complete}) = getfield(monitor, :not_complete)

propertynames(monitor::DataMonitor) = ( :lock,
                                        :fetch_index,
                                        :release_counter,
                                        :procedures,

                                        :wait_to_fetch,
                                        :fetch_index_updated,
                                        :fetch_index_read)

getproperty(monitor::DataMonitor, ::Val{:lock}) = getfield(monitor, :lock)

getproperty(monitor::DataMonitor, ::Val{:fetch_index}) = getfield(monitor, :fetch_index)
getproperty(monitor::DataMonitor, ::Val{:release_counter}) = getfield(monitor, :release_counter)
getproperty(monitor::DataMonitor, ::Val{:procedures}) = getfield(monitor, :procedures)

getproperty(monitor::DataMonitor, ::Val{:wait_to_fetch}) = getfield(monitor, :wait_to_fetch)
getproperty(monitor::DataMonitor, ::Val{:fetch_index_updated}) = getfield(monitor, :fetch_index_updated)
getproperty(monitor::DataMonitor, ::Val{:fetch_index_read}) = getfield(monitor, :fetch_index_read)

#--- Accessors.
camera(cam::RemoteCamera) = cam
camera(cam::SharedCamera) = cam
device(cam::RemoteCamera) = getfield(cam, :device)
device(cam::SharedCamera,i::Int64) = cam.cameras[i]
eltype(::AbstractCamera{T}) where {T} = T
cmds(monitor::RemoteCameraMonitor) = begin
                                    rdlock(monitor.cmds,0.5) do
                                        monitor.cmds
                                    end
                                end
state(monitor::RemoteCameraMonitor) = begin
                                    rdlock(monitor.state,0.5) do
                                        monitor.state
                                    end
                                end


show(io::IO, cam::RemoteCamera{T}) where {T} =
    print(io, "RemoteCamera{$T}(owner=\"", cam.owner,")")

# Make cameras iterable. We call the `timedwait` method rather that `wait` to
# avoid waiting forever.  FIXME: Compute a reasonable timeout for cameras
# (requires to known the framerate and the exposure time).
iterate(cam::AbstractCamera, ::Union{Nothing,Tuple{Any,Any}}=nothing) =
                (timedwait(cam, 30.0), nothing)


#--- create functions
function create(::Type{SharedCamera}; owner::AbstractString = default_owner(),
                perms::Integer = 0o600)

    length(owner) < SHARED_OWNER_SIZE || error("owner name too long")

    ptr = ccall((:tao_create_shared_object, taolib), Ptr{AbstractSharedObject},
                (Cstring, UInt32, Csize_t, Cuint),
                owner, _fix_shared_object_type(SHARED_CAMERA), 464, perms)
                # 464 bytes from sizeof(tao_shar_camera) in C program
    _check(ptr != C_NULL)

    return _wrap(SharedCamera, ptr)
end

function create_monitor_shared_object!(::Type{SharedObject},monitor::AbstractMonitor;
                owner::AbstractString = default_owner(),perms::Integer = 0o600)
        length(owner) < SHARED_OWNER_SIZE || error("owner name too long")

        ptr = ccall((:tao_create_shared_object, taolib), Ptr{AbstractSharedObject},
                    (Cstring, UInt32, Csize_t, Cuint),
                    owner, _fix_shared_object_type(SHARED_OBJECT), 256, perms)
                    # 256 bytes from sizeof(tao_shar_camera) in C program
        _check(ptr != C_NULL)
        _set_ptr!(monitor,ptr)
        if ptr != C_NULL
            finalizer(_finalize, monitor)
            _set_final!(monitor, true)
        end

        return monitor
end
## Camera util functions
function register(dev::SharedCamera, cam::Camera)
    inc_attachedCam(dev)
    try
        dev.cameras[dev.attachedCam] = cam
    catch
        throw(ErrorException("No more space to attach cameras"))
    end

end

function broadcast_shmids(shmids::Vector{ShmId})
    fname = "shmids.txt"
    path = "/tmp/SpinnakerCameras/"

    fname ∈ readdir(path) || touch(joinpath(path,fname))

    open(path*fname,"w") do f
        for shmid in shmids
            write(f,@sprintf("%d\n",shmid))
        end
    end
end
const img_param = fieldnames(ImageConfigContext)
const img_param_type = fieldtypes(ImageConfigContext)
# parse(::Type{PixelFormat}, val::Int64) = PixelFormat(val)
parse(::Type{String}, pixelformat_str::String) = pixelformat_str

# read img_config.txt and update SharedCamera.img_config field
function _read_and_update_config(shcam::SharedCamera)
    fname = "img_config.txt"
    path = "/tmp/SpinnakerCameras/"
    fname ∈ readdir(path) || throw(LoadError("image config doest not exist"))
    f = open(path*fname,"r" )
    rd = readlines(f)
    new_conf = shcam.img_config
    for i in 1:length(rd)
      if !isempty(rd[i])
        setfield!(new_conf,img_param[i],parse(img_param_type[i],rd[i]))
      end
    end
    @show new_conf
    setfield!(shcam,:img_config,new_conf)
  end


#--- Command and state mapper

for (cmd, now_state, next_state) in (
        (:CMD_INIT,  :STATE_UNKNOWN   ,   STATE_INIT),
        (:CMD_WORK,  :STATE_WAIT      ,   STATE_WORK),
        (:CMD_STOP,  :STATE_WORK      ,   STATE_WAIT),

    )

    @eval sort_next_state(::Val{$cmd}, ::Val{$now_state}) = $next_state
end

# sort_next_state(Val(),::Val{SIG_ERROR})
for (sig, cmd, next_state) in (
        (:SIG_DONE,  :CMD_INIT      ,   STATE_WAIT),
        (:SIG_DONE,  :CMD_STOP      ,   STATE_WAIT),
        (:SIG_DONE,  :CMD_WORK      ,   STATE_WORK),
        (:SIG_ERROR,  :CMD_WORK      ,   STATE_ERROR),
    )

    @eval sort_next_state(::Val{$cmd}, ::Val{$sig}) = $next_state
end

sort_next_state(cmd::RemoteCameraCommand, current_state::RemoteCameraState) = sort_next_state(Val(cmd), Val(current_state))
sort_next_state(cmd::RemoteCameraCommand, shcam_sig::ShCamSIG) = sort_next_state(Val(cmd), Val(shcam_sig))


thread_safe_wait(r::Condition) = begin
                                lock(r)
                                try
                                  wait(r)
                                finally
                                  unlock(r)
                                end
                              end
thread_safe_notify(r::Condition) = begin
                                lock(r)
                                try
                                  wait(r)
                                finally
                                  unlock(r)
                                end
                              end
## Listening function
@inline no_new_cmds(cmds::SharedArray{Cint,1}) = begin
                        sum(cmds .== -1) == length(cmds)
                      end
pop!(cmds::SharedArray{Cint,1}) = begin
                          val = cmds[1]
                          cmds[:] = vcat(cmds[2:end],-1)
                          return val
                        end
"""
  Listening
  1. check cmds written to the shmid
  2. read the cmds
  3. start the command
"""
listening(shcam::SharedCamera, remcam::RemoteCamera) = @async _listening(shcam, remcam)


function _listening(shcam::SharedCamera, remcam::RemoteCamera)

    while true
      # check the command
      @info "wait cmds"

      @async _keep_checking_cmds(remcam.cmds, remcam.no_cmds )
      wait(remcam.no_cmds)
      #  read new cmd
      cmd = rdlock(remcam.cmds,0.5) do
          pop!(remcam.cmds)
      end
      # sent the command to the camera
      if next_camera_operation(RemoteCameraCommand(cmd),shcam, remcam)
        @info "Command successful..."
      else
        @info "Command failed..."
      end
      println("restart status = ",restartListening.status)
      # if the flag is set to 1
      restartListening.status  == 1 && break

    end
    @info "stop listening.."
    return nothing

end

"""
    This function keeps checking the cmd array if there is a new command written to
    the shared array
"""
function _keep_checking_cmds(cmd_array::SharedArray{Cint,1}, no_cmds::Condition)

      cmd0 = rdlock(cmd_array,0.5) do
          cmd_array[1]
      end
      cmd_now = copy(cmd0)

    while cmd_now == cmd0
      cmd_now = rdlock(cmd_array,0.5) do
          cmd_array[1]
      end
      sleep(0.01)

    end
    notify(no_cmds)
    nothing
end
## image acquisition functios
@inline unpack(pack::DataPack) = (pack.img, pack.ts, pack.numID)
"""
    SpinnakerCameras.grabbing()
    Grab data from camera and put in RemoteCamera Buffer
""" grabbing
grabbing(datapack::DataPack,remcam::RemoteCamera) = _grabbing(datapack,remcam)

function _grabbing(datapack::DataPack,remcam::RemoteCamera)
      (img, ts, id) = unpack(datapack)

      wrlock(remcam.img,1) do
        copyto!(remcam.img, img)
      end
      wrlock(remcam.imgTime,1) do
        remcam.imgTime[1] = ts
      end
      nothing

end


## attach extension
function attach(::Type{SharedCamera}, shmid::Integer)
    # Attach the shared object to the address space of the caller, then wrap it
    # in a Julia object.
    ptr = ccall((:tao_attach_shared_camera, taolib),
                Ptr{AbstractSharedObject}, (ShmId,), shmid)
    _check(ptr != C_NULL)
    cam = _wrap(SharedCamera, ptr)
    return cam
end

function attach_monitor_mutex!(monitor::AbstractMonitor, shmid::Integer)

    ptr = _call_attach(shmid, SHARED_OBJECT)
    _check(ptr != C_NULL)
    _set_ptr!(monitor, ptr)
    if ptr != C_NULL && !_get_final(obj)
        finalizer(_finalize, obj)
        _set_final!(obj, true)
    end
    return monitor
end

# attached image and image timestamp shared array on a worker process
function attach_remote_process(T::Type)
    # read shared array shmids
    fname = "/tmp/SpinnakerCameras/shmids.txt"
    f = open(fname,"r")
    rd = readlines(f)
    shmids = []
    for line in rd
      push!(shmids,parse(Int64,line))
    end

    img_array = attach(SharedArray{T},shmids[1])
    imgTime_array = attach(SharedArray{UInt64},shmids[2])

    return img_array, imgTime_array
end
#--- shared camera operations
update_worker_pid(pid::Integer,remcam::RemoteCamera) = begin
  wrlock(remcam.device,0.1) do
    setfield!(remcam,:worker_pid,pid)
  end
end

# Operation - Commands table
next_camera_operation(cmd::RemoteCameraCommand,shcam::SharedCamera, remcam::RemoteCamera) = next_camera_operation(Val(cmd),shcam ,remcam)

for (cmd, cam_op) in (
    (:CMD_INIT, :init),
    (:CMD_WORK, :start),
    (:CMD_STOP, :stop),
    (:CMD_CONFIG, :config),
    (:CMD_UPDATE,  :update),
    (:CMD_RESET, :reset)

    )
@eval begin
    function next_camera_operation(::Val{$cmd}, shcam::SharedCamera, remcam::RemoteCamera)
        try
            str_op = $cam_op
            @info "Executing  $str_op \n"
            cameraTask = $cam_op(shcam,remcam)
        catch ex
            if !isa(ex, SpinnakerCameras.CallError)
                rethrow(ex)
            end
            @warn "Error occurs $(ex.func)"

            println(ex)

            return_val =  false
            return return_val
        end

        return_val =  true

        return return_val
    end
end
end

"""
    SpinnakerCameras.init()
    Initialize camera
""" init
init(shcam::SharedCamera,  remcam::RemoteCamera, ) = begin
    camera = device(shcam,1)
    try
        initialize(camera)

        # configure the camera
        for param in fieldnames(ImageConfigContext)
              _param = "$param"
              val =  getfield(shcam.img_config,param)
              @eval func = $(Symbol("set_",param))
              func(camera,val)
        end

    catch ex
        rethrow(ex)
    end
   nothing
end

start(shcam::SharedCamera,remcam::RemoteCamera ) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))

    camera = device(shcam,1)
    dataType = eltype(remcam)
    pid =[0]
    try
      # start working
      pid[1] = working(1, dataType)
      @info "worker pid = $(pid[1])"

    catch ex
      println(ex)
      rethrow(ex)
    end

    # broadcast worker pid
    update_worker_pid(pid[1],remcam)
    @info "start is DONE"

    nothing
end

"""
  SpinnakerCameras.update(SharedCamera, RemoteCamera)
  This function interrupts the ongoing acquisition loop to update the camera
  configuration and start a new acquisition loop
  The new camera configuration setting is read through a file.
""" update
function update(shcam::SharedCamera,remcam::RemoteCamera)
  stop(shcam,remcam)
  config(shcam,remcam)
  @info "Camera configuration has been updated"
  working(1)
  @info "Acquisition restarts"
  nothing
end


stop(shcam::SharedCamera,remcam::RemoteCamera) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))

    camera = device(shcam,1)
    pid = remcam.worker_pid
    try
      interrupt(pid)

    catch ex
      rethrow(ex)
    end

    nothing

end

"""
  SpinnakerCameras.config(SharedCamera, RemtoeCamera)
  Change camera setting according to the ImageConfigContext in SharedCamera
""" config

config(shcam::SharedCamera,remcam::RemoteCamera) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))
    # save previous setting
    cached_imgConfig = copy(shcam.img_config)

    _read_and_update_config(shcam)

    camera = device(shcam,1)
    try
      for param in fieldnames(ImageConfigContext)
            _param = "$param"
            valOld = getfield(cached_imgConfig, param)
            valNew =  getfield(shcam.img_config,param)

            if valOld != valNew
              # if width or height changed -> restart RemoteCamera
              if (_param == "width") || (_param == "height") || (_param = "pixelformat")
                 restartListening.status = 1
              end
              @eval func = $(Symbol("set_",param))
              func(camera,valNew)
            end
      end

    catch ex
        rethrow(ex)
    end

    nothing
end

"""
SpinnakerCameras.reset(camera)
    Power cycle the device

""" _reset

reset(shcam::SharedCamera,remcam::RemoteCamera) = begin

    shcam.attachedCam > 0 || throw(ErrorException("No attached cameras"))

    camera = device(shcam,1)

    try
      _reset(camera)

    catch ex
      rethrow(ex)
    end

    nothing
end
