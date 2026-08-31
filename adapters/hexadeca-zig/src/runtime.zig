// SPDX-License-Identifier: MPL-2.0
//! Process-wide Zig 0.16 I/O runtime following the estate cartridge convention.

const std = @import("std");

var shared_threaded: std.Io.Threaded = undefined;
var shared_io_state: std.atomic.Value(u8) = .init(0);

/// Return the process-wide I/O runtime, initialising it exactly once.
pub fn io() std.Io {
    if (shared_io_state.load(.acquire) != 2) {
        if (shared_io_state.cmpxchgStrong(0, 1, .acq_rel, .acquire) == null) {
            shared_threaded = std.Io.Threaded.init(std.heap.smp_allocator, .{});
            shared_io_state.store(2, .release);
        } else {
            while (shared_io_state.load(.acquire) != 2) std.Thread.yield() catch {};
        }
    }
    return shared_threaded.io();
}
