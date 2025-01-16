module test;

import program;
import node;
import std::math::random;
import std::math;
import std::io;
import std::io::file;

fault TestError {
    NAN,
    MISMATCH
}

fn void! result_ok(double a, double b) {
    const double EPS = 0.0001;
    
    if(math::is_nan(a) || math::is_nan(b)) {
        return TestError.NAN?;
    }
    
    if(math::abs(a - b) > EPS) {
        return TestError.MISMATCH?;
    }
}

fn bool! test_one(usz test_no) {
    usz limit = 15;

    Node* ast = node::node_triple(
        program::random_node(limit),
        node::node_number(0.0),
        node::node_number(1.0),
    );

    Bytecode bc = bytecode::compile(ast)!;
    BytecodeJIT jit = jit::compile(bc)!;
    defer jit.free();

    double[<3>] input = { rnd() * 2 - 1, 0.0, 0.0 };
    double[<3>] bc_result = bc.execute(input.x, input.y, input.z);
    double[<3>] jit_result = jit.execute(input.x, input.y, input.z);

    if(catch err = result_ok(bc_result.x, jit_result.x)) {
        io::printfn("Result not OK: %s (#%d) !!", err, test_no);
        io::printf("  => program : ");
        ast.as.triple.x.dump(*io::stdout())!;
        io::printfn("  => input : %s", input);
        io::printfn("  => output :");
        io::printfn("    => Bytecode : %f", bc_result.x);
        io::printfn("    => JIT      : %f", jit_result.x);

        File file = file::open("bc.txt", "w")!;
        bc.dump(file)!;
        file.close()!;

        file = file::open("jit.bin", "wb")!;
        jit.dump(file)!;
        file.close()!;
        
        return false;
    }

    return true;
}

fn void test() {
    usz counter = 0;
    while(true) {
        counter++;
        if(counter % 100 == 0) {
            io::printf("Test #%d\r", counter);
            io::stdout().flush()!!;
        }

        @pool() {
            bool result = test_one(counter)!!;
            if(!result) {
                return;
            }
        };
    }
}
