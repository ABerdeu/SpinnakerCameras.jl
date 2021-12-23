using SpinnakerCameras
using Images
# Acquisition params
modeStr = "SingleFrame"

# Image format params
imageSize = (500, 350)

# Exposure
exposure_time = 100.0


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

SpinnakerCameras.set_acquisitionmode(camera, modeStr)

# set exposure
print("Set exposure time to $exposure_time\n")
SpinnakerCameras.set_exposuretime(camera, exposure_time)
#---
#==
    Acquire image and post it in the shared memroy via shared array structure
    psuedo code
    1. create shared array
    2. acquire image
    3. put image into the shared memory
    4. invoke data reading script --> read and save image

=#
#
sharr = SpinnakerCameras.create(SpinnakerCameras.SharedArray{UInt8,2},
    (1536,2048), perms = 0o666)

arr = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt8}, sharr.shmid)

while SpinnakerCameras.islocked(arr) end
SpinnakerCameras.wrlock(arr,1.0) do
    SpinnakerCameras.acquire_n_share_image(camera, arr)
end
# display the image
carr = convert(Array{Float16},arr)
img = colorview(Gray,carr)

SpinnakerCameras.detach(arr)

#---  finalize the objects
for obj in (:camera, :camList, :system)
    eval(Expr(:call,:finalize, obj))
end
print("Example is complete ..\n")
