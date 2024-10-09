const std = @import("std");
const term = @import("term.zig");
const editor = @import("editor.zig");
const posix = std.posix;
const expect = std.testing.expect;
const logfns = @import("log.zig");

pub const std_options = .{
    // .log_level = .debug,
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

    const terminal = term.Term.init(.{
        .file = stdout,
        .rows = dimensions.ws_row,
        .cols = dimensions.ws_col,
    });

    var e = editor.Editor(std.fs.File).init(allocator, terminal, stdin);
    defer e.deinit();

    // try e.open();
    try e.open("tests/file.txt");

    try e.start();
}
