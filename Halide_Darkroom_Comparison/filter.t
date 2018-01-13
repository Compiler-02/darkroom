import "darkroom"
darkroomSimple = require("darkroomSimple")

a = darkroomSimple.load("frame10.bmp")
I = im(x,y) [float](a) end

boxFilter = im(x,y)
  map i=-1,1 j=-1,1 reduce(sum) 
    I(x+i,y+j) 
  end
end
boxFilterNorm = im(x,y) boxFilter/9 end

boxFilterUint8 = im(x,y) [uint8](boxFilterNorm) end
boxFilterUint8:save("boxfilter.bmp")
