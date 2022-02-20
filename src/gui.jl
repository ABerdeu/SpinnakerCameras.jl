# gui.jl
# image display based on ImageView


conversion(img_handle::Array{UInt8,2}) =  n0f8.(img_handle./2^8)
conversion(img_handle::Array{UInt16,2}) =  n0f16.(img_handle./2^16)

"""
    live_display(delay::Float64 = 0.001)
    Read image from the image data shared array and display it
    Based on Images, ImageView
    default update rate = 1 ms
""" live_display

function live_display(;delay::Float64 = 0.001)
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

    # read image format
    fname = "img_config.txt"
    path = "/tmp/SpinnakerCameras/"
    fname ∈ readdir(path) || throw(LoadError("image config doest not exist"))
    f = open(path*fname,"r" )
    rd = readlines(f)
    _width = parse(Int,rd[1])
    _height = parse(Int,rd[2])
    _pixelformat = rd[5]

    dataType = get(SpinnakerCameras.PixelFormat,_pixelformat, Real)

    img_data = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{dataType},shmid[1])
    imgTime = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt64},shmid[2])

    # initiate Gtk Window
    img_size = size(img_data)
    img0 = Gray.(ones(img_size))

    window = imshow_gui((600, 600), (1, 1))
    canvases = window["canvas"]
    imshow(canvases, img0)
    Gtk.showall(window["window"])

    img_handle =  Array{dataType,2}(undef,_width,_height)
    while true
        try
        SpinnakerCameras.rdlock(img_data) do
            copyto!(img_handle,img_data)
            imshow(canvases, Gray.(conversion(img_handle)))
        end
        sleep(delay)
        catch
            break
        end
    end

    nothing

end
