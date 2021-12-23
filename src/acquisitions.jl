#
# acquisitions.jl
#
# Implement acquisition control feature
# APIs
#e
#-----------------------------------------------------------------------------------

"""
   SpinnakerCameras.acquire_n_save_images(camera, numImg, fname, fileformat)

   acquire images of which number is specified by numImg and save the images
   in the format given by imageFormat; eg. ".jpeg". The fname is the base name of the images.
   The file name is tagged by the order of the imaging. Timeout can be specified
""" acquire_n_save_images

function acquire_n_save_images(camera::Camera, numImg::Int64, fname::String,
                            imageFormat::String; timeoutSec::Int64 = 1)
   #Begin acquisition
   SpinnakerCameras.start(camera)

   # retreive, convert, and save images
   for ind in 1:numImg
       img =
       try
           SpinnakerCameras.next_image(camera, timeoutSec)
       catch ex
           if (!isa(ex, SpinnakerCameras.CallError) ||
               ex.code != SpinnakerCameras.SPINNAKER_ERR_TIMEOUT)
               rethrow(ex)
           end
           nothing
       end
       # check image completeness
       if  img.incomplete == 1
           print("Image $ind is incomplete.. skipepd \n")
           # finalize(img)

       elseif img.status != 0
           print("Image $ind has error.. skipepd \n")
           # finalize(img)

       else
           # save image
           fname_now = Printf.@sprintf "%s_%d%s" fname ind imageFormat
           SpinnakerCameras.save_image(img, fname_now )
           print("Image $ind is complete.. saved as $fname_now \n")

           finalize(img)
       end

   end

   SpinnakerCameras.stop(camera)

end


"""
    SpinnakerCameras.acquire_n_share_image(camera, shared_array)
    1. acquire the next image
    2. check writability of the shared array
    3. lock the shared array
    4. copy the image into the shared_array
    5. unlock the shared array
    6. destroy the image
""" acquire_n_share_image

function acquire_n_share_image(camera::Camera, arr::SharedArray, timeoutSec::Int64 = 1 )
    #Begin acquisition
    SpinnakerCameras.start(camera)

    # retreive, post images

    img =
    try
        SpinnakerCameras.next_image(camera, timeoutSec)
    catch ex
        if (!isa(ex, SpinnakerCameras.CallError) ||
            ex.code != SpinnakerCameras.SPINNAKER_ERR_TIMEOUT)
            rethrow(ex)
        end
        nothing
    end

    # check image completeness
    if  img.incomplete == 1
        print("Image $ind is incomplete.. skipepd \n")
        finalize(img)
    elseif img.status != 0
        print("Image $ind has error.. skipepd \n")
        finalize(img)
    else

        img_data = @view img.data[:,:]
        copyto!(arr, img_data)

        finalize(img)
    end
    SpinnakerCameras.stop(camera)


end
