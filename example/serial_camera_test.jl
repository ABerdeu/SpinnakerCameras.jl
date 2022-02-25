# serial_camera_test.jl
# Example script to demonstrate how a camera server works
# the server grab and post image data , from the camera, to the local buffer,
# to the shared mmemory in a serial order, which is not optimal for high-speed
# applications.
using Revise
using Distributed
addprocs(1)

# load package
@everywhere import SpinnakerCameras as SC
##=
system = SC.System()
camList = SC.CameraList(system)

camNum = length(camList)

if camNum == 0
    finalize(camList)
    finalize(system)
    print("No cameras found... \n Done...")

end

print("$(camNum) cameras are found \n" )

camera = camList[1]

dev = SC.create(SC.SharedCamera)
shcam = SC.attach(SC.SharedCamera, dev.shmid)

SC.register(shcam,camera)
dims = (800,800)
remcam = SC.RemoteCamera{UInt8}(shcam, dims)

#--- listening
# 1. broadcasting shmid of cmds, state, img, imgBuftime, remote camera monitor
img_shmid = SC.get_shmid(remcam.img)
imgTime_shmid = SC.get_shmid(remcam.imgTime)
cmds_shmid = SC.get_shmid(remcam.cmds)
shmids = [img_shmid,imgTime_shmid,cmds_shmid]
SC.broadcast_shmids(shmids)

## 2. initialize the camera server
RemoteCameraEngine = SC.listening(shcam, remcam)


##-- below operations are supposed to be done by remote clients
# these operations are basically write integer to the first element of the shard
# array assigned to store commands
remcam.cmds[1] = SC._to_Cint(SC.CMD_INIT)
## 3. configure camera
#  microsecond exposure time max 14_799 μsec ≈ 14.8 ms
exposuretime = 200.0
# ROI
width = 800
height = 800
offsetX = (2048-width )/2
offsetY = (1536-height)/2
write_img_config(width = width, height = height,offsetX = offsetX,
                 offsetY = offsetY, exposuretime = exposuretime )
## configure
remcam.cmds[1] = SC._to_Cint(SC.CMD_CONFIG)
## 4. start acquisition
remcam.cmds[1] = SC._to_Cint(SC.CMD_WORK)
##5. stop acquisition
remcam.cmds[1] = SC._to_Cint(SC.CMD_STOP)
##6. update and restart acquisition
remcam.cmds[1] = SC._to_Cint(SC.CMD_UPDATE)
