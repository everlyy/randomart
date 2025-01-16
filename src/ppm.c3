module ppm;

import std::io;
import std::io::file;

fn void! write(String filename, char[<3>]* pixels, usz width, usz height) {
    File file = file::open(filename, "wb")!;
    io::fprintf(&file, "P6\n")!;
    io::fprintf(&file, "%d %d\n255\n", width, height)!;
    for(usz y = 0; y < height; y++) {
        for(usz x = 0; x < width; x++) {
            file.write(&pixels[y * width + x])!;
        }
    }
}
