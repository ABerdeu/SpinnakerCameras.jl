using Revise
using SpinnakerCameras
import Printf

system = SpinnakerCameras.System()
camList = SpinnakerCameras.CameraList(system)
camNum = length(camList)

if camNum == 0
    finalize(camList)
    finalize(system)
    print("No cameras found... \n Done...")

end
print("$(camNum) cameras are found \n" )

camera = camList[1]

dev = SpinnakerCameras.create(SpinnakerCameras.SharedCamera)
shcam = SpinnakerCameras.attach(SpinnakerCameras.SharedCamera, dev.shmid)

SpinnakerCameras.register(shcam,camera)

remcam = SpinnakerCameras.RemoteCamera{UInt8}(shcam, (1536,2048))


remotecam_monitor = SpinnakerCameras.RemoteCameraMonitor(SpinnakerCameras.default_P_list)
SpinnakerCameras.create_monitor_shared_object!(SpinnakerCameras.SharedObject,remotecam_monitor)
shcam_monitor = SpinnakerCameras.SharedCameraMonitor(SpinnakerCameras.default_p_list_sh)
SpinnakerCameras.create_monitor_shared_object!(SpinnakerCameras.SharedObject,shcam_monitor)


#--- listening
# 1. broadcasting shmid of cmds, state, img, imgBuftime, remote camera monitor
cmds_shmid = SpinnakerCameras.get_shmid(SpinnakerCameras.cmds(remotecam_monitor))
state_shmid = SpinnakerCameras.get_shmid(SpinnakerCameras.state(remotecam_monitor))
img_shmid = SpinnakerCameras.get_shmid(remcam.img)
imgTime_shmid = SpinnakerCameras.get_shmid(remcam.imgTime)
remcamMonitor_shmid = SpinnakerCameras.get_shmid(remotecam_monitor)
shcam_monitor_shmid = SpinnakerCameras.get_shmid(shcam_monitor)
shmids = [img_shmid,imgTime_shmid,cmds_shmid, state_shmid, remcamMonitor_shmid,shcam_monitor_shmid]
SpinnakerCameras.broadcast_shmids(shmids)

# 2. start a new process
Listening = SpinnakerCameras.listening(remotecam_monitor, shcam_monitor)
Updating = SpinnakerCameras.updating_shcam_cmd(shcam, shcam_monitor,remcam, remotecam_monitor)
shcam_monitor.procedures[7](shcam_monitor)
# inject init command
remotecam_monitor.procedures[4](remotecam_monitor,SpinnakerCameras.STATE_UNKNOWN)
remotecam_monitor.procedures[2](remotecam_monitor,[SpinnakerCameras.CMD_INIT])
# cmd is filled
notify(remotecam_monitor.empty_cmds)

#inject start command
remotecam_monitor.procedures[2](remotecam_monitor,[SpinnakerCameras.CMD_WORK])

notify(remotecam_monitor.empty_cmds)
