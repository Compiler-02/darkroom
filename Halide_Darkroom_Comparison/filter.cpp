//halide/xxx/filter.cpp
//g++ filter.cpp -g -I ../include -I ../tools -L ../bin -lHalide `libpng-config --cflags --ldflags` -ljpeg -lpthread -ldl -o filter -std=c++11

#include "Halide.h"

#include "halide_image_io.h"
using namespace Halide::Tools;

int main(int argc, char **argv) {

    Halide::Buffer<uint8_t> input = load_image("frame10.png");
    
    Halide::Func im, blurx, blury, bluri;

    Halide::Var x, y, xi, yi;

    im(x, y) = Halide::cast<float>(input(x, y));
    blurx(x, y) = (im(x, y) + im(x + 1, y) + im(x + 2, y)) / 3.0f;
    blury(x, y) = (blurx(x, y) + blurx(x, y + 1) + blurx(x, y + 2)) / 3.0f;
    bluri(x, y) = Halide::cast<uint8_t>(blury(x, y));
    //blury.tile(x, y, xi, yi, 256, 32).vectorize(xi, 8).parallel(y);
    //blurx.compute_at(blury, x).store_at(blury, x).vectorize(x, 8);

    Halide::Buffer<uint8_t> output = 
        bluri.realize(input.width() - 2, input.height() - 2);

    save_image(output, "boxfilter.png");

    printf("Success!\n");
    return 0;
}
