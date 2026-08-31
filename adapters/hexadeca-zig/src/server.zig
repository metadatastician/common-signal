// SPDX-License-Identifier: MPL-2.0
//! Loopback-only REST transport implementing the Idris2 contract in native Zig.

const std = @import("std");
const router = @import("router.zig");
const runtime = @import("runtime.zig");

const REST_PORT: u16 = 8080;
const REQUEST_CAPACITY: usize = 16 * 1024;
const RESPONSE_CAPACITY: usize = 128 * 1024;
const WRITE_CAPACITY: usize = 4096;

fn handleConnection(io: std.Io, stream: std.Io.net.Stream) void {
    defer stream.close(io);

    var request_buffer: [REQUEST_CAPACITY]u8 = undefined;
    var stream_reader = stream.reader(io, &request_buffer);
    stream_reader.interface.fillMore() catch return;
    const request = stream_reader.interface.buffered();
    const line_end = std.mem.indexOf(u8, request, "\r\n") orelse return;
    const request_line = request[0..line_end];
    const first_space = std.mem.indexOfScalar(u8, request_line, ' ') orelse return;
    const method = request_line[0..first_space];
    const remainder = request_line[first_space + 1 ..];
    const second_space = std.mem.indexOfScalar(u8, remainder, ' ') orelse return;
    const target = remainder[0..second_space];

    var response_buffer: [RESPONSE_CAPACITY]u8 = undefined;
    const response = router.routeHttp1(method, target, &response_buffer) catch return;

    var write_buffer: [WRITE_CAPACITY]u8 = undefined;
    var stream_writer = stream.writer(io, &write_buffer);
    stream_writer.interface.writeAll(response) catch return;
    stream_writer.interface.flush() catch return;
}

pub fn main() !void {
    const io = runtime.io();
    const address: std.Io.net.IpAddress = .{
        .ip4 = .{ .bytes = .{ 127, 0, 0, 1 }, .port = REST_PORT },
    };
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);
    std.debug.print("Common Signal Zig REST adapter listening on http://127.0.0.1:{d}\n", .{REST_PORT});
    while (true) {
        const stream = server.accept(io) catch continue;
        handleConnection(io, stream);
    }
}
