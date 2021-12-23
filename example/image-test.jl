#!/usr/bin/julia
using SpinnakerCameras

system = SpinnakerCameras.System()
camList = SpinnakerCameras.CameraList(system)
camNum = length(camList)

if camNum == 0
    finalize(camList)
    finalize(system)
    print("No cameras found... \n Done...")

end
print("$(camNum) cameras are found \n" )
print("Starting a camera....\n\n")

camera = camList[1]
SpinnakerCameras.initialize(camera)


# Image
img_size = (500,400)
pixelformat = SpinnakerCameras.PixelFormat_Mono8
image = SpinnakerCameras.Image(pixelformat, img_size, offsetx = 50)
print("Camera properties: \n")
# query image properties
for prop in (   :bitsperpixel,
                :buffersize,
                :data,
                :privatedata,
                :frameid,
                :id,
                :offsetx,
                :offsety,
                :paddingx,
                :paddingy,
                :payloadtype,
                :pixelformat,
                :size,
                :stride,
                :timestamp,
                :tlpixelformat,
                :validpayloadsize,
                :width,
                :height,
                :incomplete,
                :status           )

        output = getproperty(image,prop)
        print("$prop = $output \n")


end
