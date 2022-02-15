# gui.jl
# image display based on ImageView
"""
    live_display(delay::Float64 = 0.001)
    Read image from the image data shared array and display it
    Based on Images, ImageView
    default update rate = 1 ms
""" live_display

function live_display(delay::Float64 = 0.001)
    # read shmid from a text file
    fname = "shmids.txt"
    path = "/tmp/SpinnakerCameras/"
    shmid = Vector{Int64}(undef,2)
    f = open(path*fname,"r")
    for i in 1:2
        rd = readline(f)
        shmid[i] = parse(Int64,rd)
    end
    close(f)

    img_data = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt8},shmid[1])
    imgTime = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt64},shmid[2])

    # initiate Gtk Window
    img_size = size(img_data)
    img0 = Gray.(n0f8.(ones(img_size)))
    window = imshow_gui((600, 600), (1, 1))  # 2 columns, 1 row of images (each initially 300×300)
    canvases = window["canvas"]
    imshow(canvases, img0)
    Gtk.showall(window["window"])

    img_handle =  Array{UInt8,2}(undef,800,800)
    while true

        SpinnakerCameras.rdlock(img_data) do
            copyto!(img_handle,img_data)
            imshow(canvases,  Gray.(n0f8.(img_handle./256)))
        end

        sleep(delay)
    end



end
