module node::bytecode;

import std::io;
import std::math;
import std::collections::list;

enum Input {
    X, Y, T
}

enum Output {
    R, G, B
}

enum ArgumentKind {
    NUMBER,
    INPUT,
    OUTPUT,
}

struct Argument {
    ArgumentKind kind;
    union as {
        double number;
        Input input;
        Output output;
    }
}

enum InstructionKind {
    PUSH,
    POP,
    ADD,
    SUB,
    SIN,
    ABSSQRT,
    ABS,
    TAN,
    MUL,
    DIV,
}

struct Instruction {
    InstructionKind kind;
    Argument arg;
}

struct Bytecode {
    List(<Instruction>) instructions;
}

fn void Bytecode.c(&self, InstructionKind kind, Argument arg) {
    self.instructions.push(Instruction {
        .kind = kind,
        .arg = arg
    });
}

fn void Bytecode.c_push(&self, Argument arg) {
    self.c(PUSH, arg);
}

fn void Bytecode.c_push_number(&self, double a) {
    self.c_push(Argument {
        .kind = NUMBER,
        .as.number = a
    });
}

fn void Bytecode.c_push_input(&self, Input input) {
    self.c_push(Argument {
        .kind = INPUT,
        .as.input = input
    });
}

fn void Bytecode.c_pop_output(&self, Output output) {
    self.c(POP, Argument {
        .kind = OUTPUT,
        .as.output = output
    });
}

fn void! Bytecode.compile_node(&self, Node* node) {
    switch(node.kind) {
        case NUMBER:
            self.c_push_number(node.as.number);

        case TRIPLE:
            self.compile_node(node.as.triple.x)!;
            self.c_pop_output(R);

            self.compile_node(node.as.triple.y)!;
            self.c_pop_output(G);

            self.compile_node(node.as.triple.z)!;
            self.c_pop_output(B);

        case X:
            self.c_push_input(X);

        case Y:
            self.c_push_input(Y);

        case T:
            self.c_push_input(T);

        case SIN:
            self.compile_node(node.as.arg)!;
            self.c(SIN, {});

        case ABSSQRT:
            self.compile_node(node.as.arg)!;
            self.c(ABSSQRT, {});

        case ABS:
            self.compile_node(node.as.arg)!;
            self.c(ABS, {});

        case TAN:
            self.compile_node(node.as.arg)!;
            self.c(TAN, {});

        case MUL:
            self.compile_node(node.as.binop.x)!;
            self.compile_node(node.as.binop.y)!;
            self.c(MUL, {});

        case DIV:
            self.compile_node(node.as.binop.x)!;
            self.compile_node(node.as.binop.y)!;
            self.c(DIV, {});

        case ADD:
            self.compile_node(node.as.binop.x)!;
            self.compile_node(node.as.binop.y)!;
            self.c(ADD, {});

        case SUB:
            self.compile_node(node.as.binop.x)!;
            self.compile_node(node.as.binop.y)!;
            self.c(SUB, {});
    }
}

fn void! Bytecode.dump(self, File file) {
    foreach(i: self.instructions) {
        io::fprintf(&file, "%s", i.kind)!;
        if(i.kind == PUSH || i.kind == POP) {
            io::fprintf(&file, " %s(", i.arg.kind)!;

            switch(i.arg.kind) {
                case NUMBER:
                    io::fprintf(&file, "%f", i.arg.as.number)!;

                case INPUT:
                    io::fprintf(&file, "%s", i.arg.as.input)!;

                case OUTPUT:
                    io::fprintf(&file, "%s", i.arg.as.output)!;
            }

            io::fprintf(&file, ")")!;
        }
        io::fprintn(&file)!;
    }
}

const usz VM_STACK_SIZE = 64;

struct BytecodeVM {
    double[VM_STACK_SIZE] stack;
    usz ss;

    double x;
    double y;
    double t;

    double r;
    double g;
    double b;
}

fn void BytecodeVM.push(&self, double a) {
    assert(self.ss < VM_STACK_SIZE);
    self.stack[self.ss++] = a;
}

fn double BytecodeVM.pop(&self) {
    assert(self.ss > 0);
    return self.stack[--self.ss];
}

fn double[<3>] Bytecode.execute(self, double x, double y, double t) {
    BytecodeVM vm = {
        .x = x,
        .y = y,
        .t = t
    };

    foreach(i: self.instructions) {
        switch(i.kind) {
            case PUSH:
                if(i.arg.kind == NUMBER) {
                    vm.push(i.arg.as.number);
                } else if(i.arg.kind == INPUT) {
                    switch(i.arg.as.input) {
                        case X: vm.push(vm.x);
                        case Y: vm.push(vm.y);
                        case T: vm.push(vm.t);
                    }
                } else {
                    unreachable();
                }

            case POP:
                assert(i.arg.kind == OUTPUT);
                switch(i.arg.as.output) {
                    case R: vm.r = vm.pop();
                    case G: vm.g = vm.pop();
                    case B: vm.b = vm.pop();
                }

            case ADD:
                double a = vm.pop();
                double b = vm.pop();
                vm.push(b + a);

            case SUB:
                double a = vm.pop();
                double b = vm.pop();
                vm.push(b - a);

            case SIN:
                double a = vm.pop();
                vm.push(math::sin(a));

            case ABSSQRT:
                double a = vm.pop();
                vm.push(math::sqrt(math::abs(a)));

            case ABS:
                double a = vm.pop();
                vm.push(math::abs(a));

            case TAN:
                double a = vm.pop();
                vm.push(math::tan(a));

            case MUL:
                double a = vm.pop();
                double b = vm.pop();
                vm.push(b * a);

            case DIV:
                double a = vm.pop();
                double b = vm.pop();
                if(a == 0.0) {
                    vm.push(0.0);
                } else {
                    vm.push(b / a);
                }
        }
    }

    return { vm.r, vm.g, vm.b };
}

fn Bytecode! compile(Node* node) {
    Bytecode bc;
    bc.compile_node(node)!;
    return bc;
}
