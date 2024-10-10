const std = @import("std");
const term = @import("term.zig");
const editor = @import("editor.zig");
const posix = std.posix;
const expect = std.testing.expect;
const logfns = @import("log.zig");

pub const std_options = .{
    .logFn = logfns.stdErrLog,
};

const log = std.log.scoped(.main);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const stdout = std.io.getStdOut();
    const stdin = std.io.getStdIn();

    var termio = try term.TermIO.init(stdout);
    defer termio.deinit();

    const dimensions = try termio.size();

    const buf = std.io.bufferedWriter(stdout.writer());

    const terminal = term.Term.init(buf, .{
        .rows = dimensions.ws_row,
        .cols = dimensions.ws_col,
    });

    var e = editor.Editor.init(allocator, terminal);
    defer e.deinit();

    try e.open("tests/file.txt");
    try e.start(stdin.reader());
}
