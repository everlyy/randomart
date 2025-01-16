module randomart;

import std::io;
import std::thread::pool;
import std::math;
import ppm;
import profiler;
import program;
import args;
import test;

struct RenderPixelArgs {
    Program program;
    char[<3>]* output;
    usz x;
    usz y;
    usz w;
    usz h;
    double t;
}

struct RenderOptions {
    usz width;
    usz height;
    double t;
}

fn int render_pixel(void* raw_args) {
    RenderPixelArgs* args = raw_args;

    double[<3>] result = args.program.execute(
        (double)args.x / (double)args.w * 2.0f - 1.0f,
        (double)args.y / (double)args.h * 2.0f - 1.0f,
        args.t
    );

    double[<3>] pixel = {
        math::clamp(result.x, -1.0f, 1.0f),
        math::clamp(result.y, -1.0f, 1.0f),
        math::clamp(result.z, -1.0f, 1.0f)
    };

    double[<3>] pixel255 = ((pixel.rgb + 1.0) / 2.0) * 255.0;
    *args.output = {
        (char)pixel255.r,
        (char)pixel255.g,
        (char)pixel255.b,
    };

    return 0;
}

fn void! render_image(Program program, String filename, RenderOptions options) {
    char[<3>]* pixels = mem::new_array(char[<3>], options.width * options.height);

    ThreadPool(<16>) pool;
    pool.init()!;

    profiler::start("Rendering");
    for(usz y = 0; y < options.height; y++) {
        for(usz x = 0; x < options.width; x++) {
            RenderPixelArgs* args = @tclone(RenderPixelArgs {
                .program = program,
                .output = &pixels[y * options.width + x],
                .x = x,
                .y = y,
                .w = options.width,
                .h = options.height,
                .t = options.t
            });
            pool.push(&render_pixel, args)!;
        }
    }
    pool.stop_and_destroy()!;
    profiler::stop();

    profiler::start("Saving Image");
    ppm::write(filename, pixels, options.width, options.height)!!;
    profiler::stop();
}

fn void usage(String program) {
    io::printfn("Usage: %s [filename] [options [args]]...", program);
    io::printfn("    -j             Enable JIT compilation");
    io::printfn("    -d             Dump AST, bytecode, and JIT compiled code");
    io::printfn("    -D             Same as `-d` except doesn't generate image");
    io::printfn("    -T             Run tests");
    io::printfn("    -w <width>     Width of output image");
    io::printfn("    -h <height>    Height of output image");
    io::printfn("    -t <t>         Customize `t` input of program [-1..1]");
    io::printfn("    -s <seed>      Set seed for randomness");
    io::printfn("    -l <limit>     Depth limit for recursive generator");
}

fn void main(String[] _args) {
    Args ap = args::create(_args);

    usz width = 250;
    usz height = 250;
    double t = 0.0;
    char[] seed = "seed";
    usz limit = 5;
    String filename = "output.ppm";
    bool jit = false;
    bool dump = false;
    bool render = true;
    bool test = false;

    while(ap.has_next()) {
        String arg = ap.next();
        if(arg.len < 1) continue;

        bool is_flag = arg[0] == '-';

        if(!is_flag) {
            filename = arg;
            continue;
        }

        String flag = arg;

        if(flag == "--help") {
            usage(ap.program());
            return;
        }

        // Toggle flags
        if(flag == "-j") {
            jit = true;
            continue;
        }

        if(flag == "-d") {
            dump = true;
            continue;
        }

        if(flag == "-D") {
            dump = true;
            render = false;
            continue;
        }

        if(flag == "-T") {
            test = true;
            continue;
        }

        if(!ap.has_next()) {
            io::printfn("Expected argument after flag '%s'", flag);
            return;
        }

        arg = ap.next();

        // Flags with arguments
        if(flag == "-w") {
            width = arg.to_integer(usz)!!;
            continue;
        }

        if(flag == "-h") {
            height = arg.to_integer(usz)!!;
            continue;
        }

        if(flag == "-t") {
            t = arg.to_double()!!;
            continue;
        }

        if(flag == "-s") {
            seed = arg;
            continue;
        }

        if(flag == "-l") {
            limit = arg.to_integer(usz)!!;
            continue;
        }
    }

    if(test) {
        test::test();
        return;
    }

    Program program = program::generate(seed, limit, jit, dump)!!;
    if(!render) return;

    render_image(program, filename, RenderOptions {
        .width = width,
        .height = height,
        .t = t,
    })!!;
}
