module profiler;

import std::time;
import std::io;

struct Timer {
    String label;
    Time stime;
}

fn void Timer.start(&self, String label) {
    self.label = label;
    self.stime = time::now();
}

fn void Timer.stop(&self) {
    Time end = time::now();

    double diff = 0.0;
    String unit = "?";

    if((diff = end.diff_days(self.stime)) >= 1.0) {
        unit = "days";
    } else if((diff = end.diff_hour(self.stime)) >= 1.0) {
        unit = "hours";
    } else if((diff = end.diff_min(self.stime)) >= 1.0) {
        unit = "minutes";
    } else if((diff = end.diff_sec(self.stime)) >= 1.0) {
        unit = "seconds";
    } else {
        diff = (double)end.diff_us(self.stime) / 1000.0;
        unit = "milliseconds";
    }

    io::printfn("PROFILER: `%s` took %.3f %s", self.label, diff, unit);
}

Timer* timer @private;

fn void start(String label) {
    if(timer == null) timer = mem::new(Timer);
    timer.start(label);
}

fn void stop() {
    assert(timer != null);
    timer.stop();
}
