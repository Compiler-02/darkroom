import "darkroom"
darkroomSimple = require("darkroomSimple")
inputImage = darkroomSimple.load("cat.bmp")
im areaFilterX(x,y)
  [uint8[3]](inputImage(x-1,y)/3+inputImage(x,y)/3+inputImage(x+1,y)/3)
end
areaFilterX:save("output.bmp")
