using SpinnakerCameras
using Statistics
using Dates
if pwd() != "/home/evwaco/SpinnakerCameras.jl/example"
    cd("/home/evwaco/SpinnakerCameras.jl/example")
end


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

img = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt8},shmid[1])
imgTime = SpinnakerCameras.attach(SpinnakerCameras.SharedArray{UInt64},shmid[2])

# save images to examine
saveNum = 900
saveImg = Array{UInt8,3}(undef,800,800,saveNum)
saveTs = Vector{UInt64}(undef,saveNum)
local_ts = Vector{DateTime}(undef,saveNum)
@time for k in 1:saveNum
    imgHandle = SpinnakerCameras.rdlock(img,1) do
            img
    end
    saveTs[k] = SpinnakerCameras.rdlock(imgTime,1) do
         imgTime[1]
    end
    arrPtr = @view saveImg[:,:,k]
    copyto!(arrPtr,img)

    local_ts[k] = now()
    # print("Image $(k) is saved ...")
end

timestamp = Vector{DateTime}(undef,15)
change_ind = Vector{Int64}(undef,20)
counter = [1]
for i in 2:length(saveTs)
    if (saveTs[i] - saveTs[i-1]) == 0
        continue
    else

        ind = counter[1]
        change_ind[ind] = i
        timestamp[ind] = local_ts[i]
        counter[1] += 1
    end
end

timeDiff = []
for i in 2:counter[1]-1
    diffT = saveTs[change_ind[i]] -saveTs[change_ind[i-1]]
    # println(diffT)
    append!(timeDiff,[Int64(diffT)]/1e6)
end

println("Average image acquisition rate = $(mean(timeDiff)) ms")
