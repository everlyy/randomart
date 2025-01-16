module args;

struct Args {
    String[] args;
    usz current;
}

fn Args create(String[] args) {
    return Args {
        .args = args,
        .current = 1 // Skip program name
    };
}

fn String Args.program(self) {
    return self.args[0];
}

fn bool Args.has_next(self) {
    return self.current < self.args.len;
}

fn String Args.next(&self) {
    return self.args[self.current++];
}
