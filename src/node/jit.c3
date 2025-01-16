module node::jit;

import node;
import std::collections::list;
import std::io::file;

fault JITCompilerError {
    COULDNT_MMAP_CODE
}

def JitFunc = fn void(double** vars);

struct BytecodeJIT {
    List(<char>) code;
    void* program;
    ulong sz;
}

extern fn void* jit_setup(void* code, ulong sz);
extern fn void jit_free(void* code, ulong sz);

fn double[<3>] BytecodeJIT.execute(&self, double x, double y, double t) {
    double[<3>] result;
    double*[6] vars = { &x, &y, &t, &result[0], &result[1], &result[2] };

    // Call to JIT compiled code
    ((JitFunc)self.program)(&vars);

    return result;
}

fn void BytecodeJIT.free(&self) {
    jit_free(self.program, self.sz);
}

fn void! BytecodeJIT.dump(&self, File file) {
    file.write(((char*)self.program)[:self.sz])!;
}

fn void BytecodeJIT.append(&self, char... args) {
    foreach(c: args) {
        self.code.push(c);
    }
}

fn void BytecodeJIT.append_double(&self, double a) {
    char* bytes = (char*)&a;
    for(usz i = 0; i < $sizeof(a); i++) {
        self.append(bytes[i]);
    }
}

fn void BytecodeJIT.c_init(&self) {
    // push rbx rsp rbp r12 r13 r14 r15
    self.append(0x53);
    self.append(0x54);
    self.append(0x55);
    self.append(0x41, 0x54);
    self.append(0x41, 0x55);
    self.append(0x41, 0x56);
    self.append(0x41, 0x57);

    // mov r9, [rdi]
    self.append(0x4C, 0x8B, 0x0F,);
    // mov r10, [rdi+0x8]
    self.append(0x4C, 0x8B, 0x57, 0x08);
    // mov r11, [rdi+0x10]
    self.append(0x4C, 0x8B, 0x5F, 0x10);
    // mov r12, [rdi+0x18]
    self.append(0x4C, 0x8B, 0x67, 0x18);
    // mov r13, [rdi+0x20]
    self.append(0x4C, 0x8B, 0x6F, 0x20);
    // mov r14, [rdi+0x28]
    self.append(0x4C, 0x8B, 0x77, 0x28);

    // fninit
    self.append(0xDB, 0xE3);
}

fn void BytecodeJIT.c_fini(&self) {
    // pop r15 r14 r13 r12 rbp rsp rbx
    self.append(0x41, 0x5F);
    self.append(0x41, 0x5E);
    self.append(0x41, 0x5D);
    self.append(0x41, 0x5C);
    self.append(0x5D);
    self.append(0x5C);
    self.append(0x5B);

    // ret
    self.append(0xC3);
}

fn void BytecodeJIT.c_push(&self, Argument src) {
    if(src.kind == NUMBER) {
        // mov r8, qword src
        self.append(0x49, 0xB8);
        self.append_double(src.as.number);
        // push r8
        self.append(0x41, 0x50);
    } else if(src.kind == INPUT) {
        // push qword ...
        self.append(0x41, 0xFF);

        switch(src.as.input) {
            case X:
                // ... [r9]
                self.append(0x31);
            case Y:
                // ... [r10]
                self.append(0x32);
            case T:
                // ... [r11]
                self.append(0x33);
        }
    } else {
        unreachable();
    }
}

fn void BytecodeJIT.c_pop(&self, Argument dst) {
    assert(dst.kind == OUTPUT);

    // pop qword ...
    self.append(0x41, 0x8F);

    switch(dst.as.output) {
        case R:
            // ... [r12]
            self.append(0x04, 0x24);
        case G:
            // ... [r13]
            self.append(0x45, 0x00);
        case B:
            // ... [r14]
            self.append(0x06);
    }
}

fn void BytecodeJIT.c_add(&self) {
    // movsd xmm0, qword [rsp + 8]
    self.append(0xF2, 0x0F, 0x10, 0x44, 0x24, 0x08);
    // addsd xmm0, qword [rsp]
    self.append(0xF2, 0x0F, 0x58, 0x04, 0x24);
    // add rsp, 8
    self.append(0x48, 0x83, 0xC4, 0x08);
    // movsd qword [rsp], xmm0
    self.append(0xF2, 0x0F, 0x11, 0x04, 0x24);
}

fn void BytecodeJIT.c_sub(&self) {
    // movsd xmm0, qword [rsp + 8]
    self.append(0xF2, 0x0F, 0x10, 0x44, 0x24, 0x08);
    // subsd xmm0, qword [rsp]
    self.append(0xF2, 0x0F, 0x5C, 0x04, 0x24);
    // add rsp, 8
    self.append(0x48, 0x83, 0xC4, 0x08);
    // movsd qword [rsp], xmm0
    self.append(0xF2, 0x0F, 0x11, 0x04, 0x24);
}

fn void BytecodeJIT.c_sin(&self) {
    // fld qword [rsp]
    self.append(0xDD, 0x04, 0x24);
    // fsin
    self.append(0xD9, 0xFE);
    // fstp qword [rsp]
    self.append(0xDD, 0x1C, 0x24);
}

fn void BytecodeJIT.c_abssqrt(&self) {
    // fld qword [rsp]
    self.append(0xDD, 0x04, 0x24);
    // fabs
    self.append(0xD9, 0xE1);
    // fsqrt
    self.append(0xD9, 0xFA);
    // fstp qword [rsp]
    self.append(0xDD, 0x1C, 0x24);
}

fn void BytecodeJIT.c_abs(&self) {
    // fld qword [rsp]
    self.append(0xDD, 0x04, 0x24);
    // fabs
    self.append(0xD9, 0xE1);
    // fstp qword [rsp]
    self.append(0xDD, 0x1C, 0x24);
}

fn void BytecodeJIT.c_tan(&self) {
    // fld qword [rsp]
    self.append(0xDD, 0x04, 0x24);
    // fptan
    self.append(0xD9, 0xF2);
    // fstp st0
    self.append(0xDD, 0xD8);
    // fstp qword [rsp]
    self.append(0xDD, 0x1C, 0x24);
}

fn void BytecodeJIT.c_mul(&self) {
    // movsd xmm0, qword [rsp + 8]
    self.append(0xF2, 0x0F, 0x10, 0x44, 0x24, 0x08);
    // mulsd xmm0, qword [rsp]
    self.append(0xF2, 0x0F, 0x59, 0x04, 0x24);
    // add rsp, 8
    self.append(0x48, 0x83, 0xC4, 0x08);
    // movsd qword [rsp], xmm0
    self.append(0xF2, 0x0F, 0x11, 0x04, 0x24);
}

fn void BytecodeJIT.c_div(&self) {
    // movsd xmm1, qword [rsp]
    self.append(0xF2, 0x0F, 0x10, 0x0C, 0x24);
    // pxor xmm0, xmm0
    self.append(0x66, 0x0F, 0xEF, 0xC0);
    // ucomisd xmm1, xmm0
    self.append(0x66, 0x0F, 0x2E, 0xC8);
    // jp near .division
    self.append(0x0F, 0x8A, 0x06, 0x00, 0x00, 0x00);
    // je near .skip
    self.append(0x0F, 0x84, 0x0A, 0x00, 0x00, 0x00);
    // .division:
    // movsd xmm0, qword [rsp + 8]
    self.append(0xF2, 0x0F, 0x10, 0x44, 0x24, 0x08);
    // divsd xmm0, xmm1
    self.append(0xF2, 0x0F, 0x5E, 0xC1);
    // .skip:
    // add rsp, 8
    self.append(0x48, 0x83, 0xC4, 0x08);
    // movsd qword [rsp], xmm0
    self.append(0xF2, 0x0F, 0x11, 0x04, 0x24);
}


fn BytecodeJIT! compile(Bytecode bytecode) {
    BytecodeJIT jit;

    jit.c_init();

    foreach(i: bytecode.instructions) {
        switch(i.kind) {
            case PUSH:
                jit.c_push(i.arg);
            case POP:
                jit.c_pop(i.arg);
            case ADD:
                jit.c_add();
            case SUB:
               jit.c_sub();
            case SIN:
                jit.c_sin();
            case ABSSQRT:
                jit.c_abssqrt();
            case ABS:
                jit.c_abs();
            case TAN:
                jit.c_tan();
            case MUL:
                jit.c_mul();
            case DIV:
                jit.c_div();
        }
    }

    jit.c_fini();

    // Create executable memory region for generated code
    jit.program = jit_setup(jit.code.entries, jit.code.size);
    jit.sz = jit.code.size;
    jit.code.free();

    if(jit.program == null) {
        return JITCompilerError.COULDNT_MMAP_CODE?;
    }

    return jit;
}
