# client.jl
# methods to send request to camera server
# --------------------------------------------

"""
    SpinnakerCameras.CameraServer.server(;camera_number::Integer = 1)

    A single command that bring up a camera server. It chooses the first GenICam
    in the camera list by default

""" server

#TODO: reconfigurable remote camera dimension

function server(;camera_number::Int = 1)
    # add a process
    SpinnakerCameras.addprocs(1)

    # local package directory
    eval(macroexpand(Main,quote SpinnakerCameras.@everywhere using Pkg end))
    @everywhere Pkg.activate("/home/evwaco/SpinnakerCameras.jl/")

    # load SpinnakerCameras module everywhere
    # a trick to use top-level expression inside a function
    eval(macroexpand(Main,quote SpinnakerCameras.@everywhere using SpinnakerCameras end))

    # bring uop the system
    system = SpinnakerCameras.System()
    camList = SpinnakerCameras.CameraList(system)

    camNum = length(camList)

    if camNum == 0
        finalize(camList)
        finalize(system)
        print("No cameras found... \n Done...")

    end

    camera = camList[camera_number]

    dev = SpinnakerCameras.create(SpinnakerCameras.SharedCamera)
    shcam = SpinnakerCameras.attach(SpinnakerCameras.SharedCamera, dev.shmid)

    SpinnakerCameras.register(shcam,camera)
    dims = (800,800)
    remcam = SpinnakerCameras.RemoteCamera{UInt8}(shcam, dims)

    #-listening
    # broadcasting shmid of cmds, state, img, imgBuftime, remote camera monitor
    img_shmid = SpinnakerCameras.get_shmid(remcam.img)
    imgTime_shmid = SpinnakerCameras.get_shmid(remcam.imgTime)
    cmds_shmid = SpinnakerCameras.get_shmid(remcam.cmds)
    shmids = [img_shmid,imgTime_shmid,cmds_shmid]
    SpinnakerCameras.broadcast_shmids(shmids)

    ## initialize the camera server
    SpinnakerCameras.listening(shcam, remcam)
end

"""
    SpinnakerCameras.send(cmdString::AbstractString)
    send command to camera server

    **Table of commands**
    | String Command | Integer code    |         Description       |
    | -------------- |:-------------:  | :-------------------------|
    | initialize     |        0        | Initialize a camera       |
    | work           |        2        | Start acquisition         |
    | stop           |        3        | Terminate acquisition     |
    | configure      |        6        | Set the image parameters  |
    | update         |        7        | reconfigure and restart   |
    | reset          |        5        | power cycle the camera    |

    eg. SpinnakerCameras.send("initialize")

""" send
const cmd_string  = ["initialize", "work", "stop", "configure","update", "reset"]
const cmd_numeric = [0           , 2     , 3     , 6          , 7      , 5      ]
const cmd_string_num_pair = Dict(cmd_string .=> cmd_numeric)

function send(cmdString::AbstractString)
    cmd = get(cmd_string_num_pair,cmdString,nothing)
    fname = "shmids.txt"
    path = "/tmp/SpinnakerCameras/"
    shmid = Vector{Int64}(undef,3)
    # read shmid from a text file
    try

        f = open(path*fname,"r")
        for i in 1:3
            rd = readline(f)
            shmid[i] = parse(Int64,rd)
        end
        close(f)
    catch
        error("Camera server has not started")
    end

    cmd_arrray = attach(SharedArray{Cint},shmid[3])

    wrlock(cmd_arrray,0.1) do
        cmd_arrray[1] = cmd
    end

    nothing

end


function read_img_config()
    fname = "img_config.txt"
    path = "/tmp/SpinnakerCameras/"
    fname ∈ readdir(path) || throw(LoadError("image config doest not exist"))
    f = open(path*fname,"r")
    rd = readlines(f)

    n = fieldnames(ImageConfigContext)

    for i in 1:length(rd)
        println(String(n[i])," ",String(rd[i]))
    end
end


function write_img_config(;kwargs...)

    fname = "img_config.txt"
    path = "/tmp/SpinnakerCameras/"
    fname ∈ readdir(path) || throw(LoadError("image config doest not exist"))
    f = open(path*fname,"r")
    rd = readlines(f)

    n = fieldnames(ImageConfigContext)
    ntype = fieldtypes(ImageConfigContext)

    img_conf = ImageConfigContext()

    for i in 1:length(rd)
        _rd = parse(ntype[i],rd[i])
        setfield!(img_conf, n[i], _rd)
    end

    for (key, val) in kwargs
        setfield!(img_conf, Symbol(key), val)
    end
    # write to the text file
    fname = "img_config.txt"
    path = "/tmp/SpinnakerCameras/"

    open(joinpath(path,fname),"w") do f
        for n in fieldnames(ImageConfigContext)
          val = getfield(img_conf,n)
          if isa(val, Bool)
            val = Int(val)
          end
          write(f,@sprintf("%s\n",val))
        end
    end
end
