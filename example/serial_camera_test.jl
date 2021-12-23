using Revise
using Distributed
addprocs(1)

@everywhere using Pkg
@everywhere Pkg.activate("/home/evwaco/SpinnakerCameras.jl/")
@everywhere import SpinnakerCameras as SC


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

## 2. initialize
RemoteCameraEngine = SC.listening(shcam, remcam)
remcam.cmds[1] = SC._to_Cint(SC.CMD_INIT)
notify(remcam.no_cmds)

## 3. configure camera
# update ImageConfigContext in shared camera
new_conf = SC.ImageConfigContext()
#  nanosecond exposure time
new_conf.exposuretime = 5000.0
# ROI
new_conf.width = 800
new_conf.height = 800
new_conf.offsetX = (2048-new_conf.width )/2
new_conf.offsetY = (1536-new_conf.height)/2

## configure
SC.set_img_config(shcam,new_conf)
remcam.cmds[1] = SC._to_Cint(SC.CMD_CONFIG)
notify(remcam.no_cmds)

## 4. start acquisition
remcam.cmds[1] = SC._to_Cint(SC.CMD_WORK)
notify(remcam.no_cmds)

# 5. stop acquisition
remcam.cmds[1] = SC._to_Cint(SC.CMD_STOP)
notify(remcam.no_cmds)

#6. update and restart acquisition
remcam.cmds[1] = SC._to_Cint(SC.CMD_UPDATE)
notify(remcam.no_cmds)
