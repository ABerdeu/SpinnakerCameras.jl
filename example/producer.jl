using SpinnakerCameras
using Printf
using Images
if pwd() != "/home/evwaco/SpinnakerCameras.jl/example"
    cd("/home/evwaco/SpinnakerCameras.jl/example")
end
# Acquisition params
modeStr = "SingleFrame"

# Exposure
exposure_time = 40.0


system = SpinnakerCameras.System()
camList = SpinnakerCameras.CameraList(system)
camNum = length(camList)

if camNum == 0
    finalize(camList)
    finalize(system)
    print("No cameras found... \n Done...")
    exit()
end
print("$(camNum) cameras are found \n" )
print("Starting a camera....\n\n")

camera = camList[1]
SpinnakerCameras.initialize(camera)

print("Set acquisition mode to $modeStr ... \n")

SpinnakerCameras.setAcquisitionmode(camera, modeStr)

# set exposure
print("Set exposure time to $exposure_time\n")
SpinnakerCameras.configure_exposure(camera, exposure_time)
#---
#==
    Acquire image and post it in the shared memroy via shared array structure
    psuedo code
    1. create shared array
    2. acquire image
    3. put image into the shared memory

=#
# params
numImg = 8
delay = 5

sharr = SpinnakerCameras.create(SpinnakerCameras.SharedArray{UInt8,2},
    (1536,2048), perms = 0o666)

# save shmid in a text file
# cd("./example")
fname = "shmid.txt"
open(fname,"w") do f
    write(f,@sprintf("%d", sharr.shmid))
end

arr = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt8}, sharr.shmid)

# acquisition loop
for k in 1:numImg
    SpinnakerCameras.rdlock(arr,10.0) do
        sleep(delay)
        println("posting image ", k)
        SpinnakerCameras.acquire_n_share_image(camera, arr)
    end

end


SpinnakerCameras.detach(arr)

#---  finalize the objects
for obj in (:camera, :camList, :system)
    eval(Expr(:call,:finalize, obj))
end
print("Producer is complete ..\n")
