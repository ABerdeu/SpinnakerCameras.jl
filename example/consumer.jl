using SpinnakerCameras
using Images
if pwd() != "/home/evwaco/SpinnakerCameras.jl/example"
    cd("/home/evwaco/SpinnakerCameras.jl/example")
end
# params
numImg = 3


# read shmid from a text file
fname = "shmid.txt"
f = open(fname)
rd = readline(f)
shmid = parse(Int64,rd)
close(f)

arr = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt8},shmid)
saveImg = Array{UInt8,3}(undef,1536,2048,numImg)

for k in 1:numImg
    SpinnakerCameras.wrlock(arr,10.0) do
        arrPtr = @view saveImg[:,:,k]
        copyto!(arrPtr,arr)
    end
    print("Image $(k) is saved ...")

end

carr = map(saveImg[:,:,k] for k =1:numImg) do arr
    convert(Array{Float16},arr)
end
img = map(carr[k] for k in 1:numImg)do arr
    colorview(Gray,arr)
end


# SpinnakerCameras.detach(arr)


print("Consumer is complete ..\n")
