module node;

import std::math;
import std::io;

enum NodeKind {
    NUMBER,
    TRIPLE,
    X,
    Y,
    T,
    SIN,
    ABSSQRT,
    ABS,
    TAN,
    MUL,
    DIV,
    ADD,
    SUB,
}

union NodeAs {
    double number;
    Node*[<3>] triple;
    Node*[<2>] binop;
    Node* arg;
}

struct Node {
    NodeKind kind;
    NodeAs as;
}

def ArgFunc = fn double(double);
def BinopFunc = fn double(double, double);

fn Node* Node.eval_arg(&self, ArgFunc f, double x, double y, double t) {
    Node* arg = self.as.arg.eval(x, y, t);
    assert(arg != null);
    assert(arg.kind == NodeKind.NUMBER);
    return node_number(f(arg.as.number));
}

fn Node* Node.eval_binop(&self, BinopFunc f, double x, double y, double t) {
    Node* lhs = self.as.binop.x.eval(x, y, t);
    assert(lhs != null);
    assert(lhs.kind == NodeKind.NUMBER);

    Node* rhs = self.as.binop.y.eval(x, y, t);
    assert(rhs != null);
    assert(rhs.kind == NodeKind.NUMBER);

    return node_number(f(lhs.as.number, rhs.as.number));
}

fn Node* node_create(NodeKind kind) {
    Node* node = mem::temp_alloc(Node);
    node.kind = kind;
    return node;
}

fn Node* node_number(double number) {
    Node* node = node_create(NodeKind.NUMBER);
    node.as.number = number;
    return node;
}

fn Node* node_triple(Node* x, Node* y, Node* z) {
    Node* node = node_create(NodeKind.TRIPLE);
    node.as.triple = { x, y, z };
    return node;
}

fn Node* node_x() {
    return node_create(NodeKind.X);
}

fn Node* node_y() {
    return node_create(NodeKind.Y);
}

fn Node* node_sin(Node* x) {
    Node* node = node_create(NodeKind.SIN);
    node.as.arg = x;
    return node;
}

fn Node* node_mul(Node* x, Node* y) {
    Node* node = node_create(NodeKind.MUL);
    node.as.binop.x = x;
    node.as.binop.y = y;
    return node;
}

fn Node* node_div(Node* x, Node* y) {
    Node* node = node_create(NodeKind.DIV);
    node.as.binop.x = x;
    node.as.binop.y = y;
    return node;
}

fn Node* node_add(Node* x, Node* y) {
    Node* node = node_create(NodeKind.ADD);
    node.as.binop.x = x;
    node.as.binop.y = y;
    return node;
}

fn Node* node_sub(Node* x, Node* y) {
    Node* node = node_create(NodeKind.SUB);
    node.as.binop.x = x;
    node.as.binop.y = y;
    return node;
}

fn Node* node_abssqrt(Node* x) {
    Node* node = node_create(NodeKind.ABSSQRT);
    node.as.arg = x;
    return node;
}

fn Node* node_tan(Node* x) {
    Node* node = node_create(NodeKind.TAN);
    node.as.arg = x;
    return node;
}

fn Node* node_abs(Node* x) {
    Node* node = node_create(NodeKind.ABS);
    node.as.arg = x;
    return node;
}

fn Node* node_t() {
    return node_create(NodeKind.T);
}

fn Node* Node.eval(&self, double x, double y, double t) {
    switch(self.kind) {
        case NodeKind.TRIPLE:
            return node_triple(
                self.as.triple.x.eval(x, y, t),
                self.as.triple.y.eval(x, y, t),
                self.as.triple.z.eval(x, y, t)
            );

        case NodeKind.NUMBER: return self;

        case NodeKind.X: return node_number(x);
        case NodeKind.Y: return node_number(y);
        case NodeKind.T: return node_number(t);

        case NodeKind.SIN:     return self.eval_arg(fn double (x) => math::sin(x), x, y, t);
        case NodeKind.ABS:     return self.eval_arg(fn double (x) => math::abs(x), x, y, t);
        case NodeKind.ABSSQRT: return self.eval_arg(fn double (x) => math::sqrt(math::abs(x)), x, y, t);
        case NodeKind.TAN:     return self.eval_arg(fn double (x) => math::tan(x), x, y, t);

        case NodeKind.MUL: return self.eval_binop(fn double(x, y) => (x * y), x, y, t);
        case NodeKind.ADD: return self.eval_binop(fn double(x, y) => (x + y), x, y, t);
        case NodeKind.SUB: return self.eval_binop(fn double(x, y) => (x - y), x, y, t);
        case NodeKind.DIV:
            return self.eval_binop(fn double(x, y) {
                    if(y == 0.0) return 0.0;
                    return (x / y);
                }, x, y, t);
    }
}

fn void! Node.print(&self, File file) {
    switch(self.kind) {
        case NodeKind.NUMBER:
            io::fprintf(&file, "%.4f", self.as.number)!;

        case NodeKind.TRIPLE:
            io::fprintf(&file, "(")!;
            self.as.triple.x.print(file)!;
            io::fprintf(&file, ", ")!;
            self.as.triple.y.print(file)!;
            io::fprintf(&file, ", ")!;
            self.as.triple.z.print(file)!;
            io::fprintf(&file, ")")!;

        case NodeKind.X:
        case NodeKind.Y:
        case NodeKind.T:
            io::fprintf(&file, "%s", self.kind)!;

        case NodeKind.SIN:
        case NodeKind.ABSSQRT:
        case NodeKind.ABS:
        case NodeKind.TAN:
            io::fprintf(&file, "%s(", self.kind)!;
            self.as.arg.print(file)!;
            io::fprintf(&file, ")")!;

        case NodeKind.MUL:
        case NodeKind.DIV:
        case NodeKind.ADD:
        case NodeKind.SUB:
            io::fprintf(&file, "%s(", self.kind)!;
            self.as.binop.x.print(file)!;
            io::fprintf(&file, ", ")!;
            self.as.binop.y.print(file)!;
            io::fprintf(&file, ")")!;
    }
}

fn void! Node.dump(&self, File file) {
    self.print(file)!;
    io::fprintn(&file)!;
}

fault ProgramValidationError {
    NULL_RESULT,
    NOT_TRIPLE,
    R_NOT_NUMBER,
    R_NOT_EXIST,
    G_NOT_NUMBER,
    G_NOT_EXIST,
    B_NOT_NUMBER,
    B_NOT_EXIST,
}

fn void! Node.validate_program(&self) {
    Node* result = self.eval(1.0f, 1.0f, 1.0f);
    if(result == null) return ProgramValidationError.NULL_RESULT?;
    if(result.kind != NodeKind.TRIPLE) return ProgramValidationError.NOT_TRIPLE?;
    if(result.as.triple.r == null) return ProgramValidationError.R_NOT_EXIST?;
    if(result.as.triple.r.kind != NodeKind.NUMBER) return ProgramValidationError.R_NOT_NUMBER?;
    if(result.as.triple.g == null) return ProgramValidationError.G_NOT_EXIST?;
    if(result.as.triple.g.kind != NodeKind.NUMBER) return ProgramValidationError.G_NOT_NUMBER?;
    if(result.as.triple.b == null) return ProgramValidationError.B_NOT_EXIST?;
    if(result.as.triple.b.kind != NodeKind.NUMBER) return ProgramValidationError.B_NOT_NUMBER?;
}
