-- this program prints out the process of compile a function
-- in Darkroom
import "darkroom"
darkroomSimple = require("darkroomSimple")
inputImage = darkroomSimple.load("cat.bmp")
im Blur(x,y)
  [uint8[3]](inputImage(x-1,y)*0.3+inputImage(x,y)*0.4+inputImage(x+1,y)*0.3)
end

Blur:save("output.bmp",{verbose=true,cores=1,printstage=true})

