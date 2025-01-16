module program;

import std::io;
import std::math;
import std::math::random;
import node;
import profiler;

Lcg32Random random;

fn NodeKind random_kind(NodeKind[] kinds) {
    return kinds[random.next_long() % kinds.len];
}

fn double random_double() {
    return random::next_double(&random) * 2.0 - 1.0;
}

fn Node* random_node(usz limit) {
    if(limit == 0) {
        Node* node = node::node_create(random_kind({ NodeKind.X, NodeKind.Y, NodeKind.T, NodeKind.NUMBER }));
        if(node.kind == NodeKind.NUMBER) {
            node.as.number = random_double();
        }
        return node;
    }

    NodeKind[] kinds = {
        NodeKind.NUMBER,
        NodeKind.SIN,
        NodeKind.ABSSQRT,
        NodeKind.ABS,
        NodeKind.TAN,
        NodeKind.MUL,
        NodeKind.DIV,
        NodeKind.ADD,
        NodeKind.SUB,
    };
    NodeKind kind = random_kind(kinds);
    Node* node = node::node_create(kind);

    switch(kind) {
        case NodeKind.TRIPLE:
            unreachable();

        case NodeKind.X:
        case NodeKind.Y:
        case NodeKind.T:
            return node;

        case NodeKind.NUMBER:
            node.as.number = random_double();
            return node;

        case NodeKind.SIN:
        case NodeKind.ABS:
        case NodeKind.TAN:
        case NodeKind.ABSSQRT:
            node.as.arg = random_node(limit - 1);
            return node;

        case NodeKind.MUL:
        case NodeKind.DIV:
        case NodeKind.ADD:
        case NodeKind.SUB:
            node.as.binop.x = random_node(limit - 1);
            node.as.binop.y = random_node(limit - 1);
            return node;
    }
}

struct Program {
    bool has_jit;
    union as {
        Bytecode bc;
        BytecodeJIT jit;
    }
}

fn double[<3>] Program.execute(self, double x, double y, double t) {
    double[<3>] result;

    if(self.has_jit) {
        result = self.as.jit.execute(x, y, t);
    } else {
        result = self.as.bc.execute(x, y, t);
    }

    return result;
}

fn Program! generate(char[] seed, usz limit, bool jit, bool dump) {
    Program result = {
        .has_jit = jit
    };

    random.set_seed(seed);

    @pool() {
        profiler::start("Generating AST");
        Node* ast = node::node_triple(
            random_node(limit),
            random_node(limit),
            random_node(limit)
        );
        profiler::stop();

        profiler::start("Compiling Bytecode");
        Bytecode bc = bytecode::compile(ast)!;
        profiler::stop();

        if(result.has_jit) {
            profiler::start("JIT Compilation");
            result.as.jit = jit::compile(bc)!;
            profiler::stop();
        } else {
            result.as.bc = bc;
        }

        if(dump) {
            profiler::start("Dumping");

            File file = file::open("ast.txt", "w")!;
            ast.dump(file)!;
            file.close()!;

            file = file::open("bytecode.txt", "w")!;
            bc.dump(file)!;
            file.close()!;

            if(result.has_jit) {
                file = file::open("jit.bin", "wb")!;
                result.as.jit.dump(file)!;
                file.close()!;
            }

            profiler::stop();
        }
    };

    return result;
}
