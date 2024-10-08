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

inline fn ctrlKey(comptime char: u8) u8 {
    return char & 0b00011111;
}

// inline fn ctrlKey(char: u8) u8 {
//     return char & 0b00011111;
// }

fn isCtrlKey(key: u8, char: u8) bool {
    if (!std.ascii.isControl(key)) {
        return false;
    }

    return key == (char & 0b00011111);
}

const EditorError = error{
    Quit,
};

fn processKeyPress(c: u8) EditorError!u8 {
    switch (c) {
        ctrlKey('c') => {
            return EditorError.Quit;
        },
        else => {
            return c;
        },
    }
}

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

    var e = editor.Editor.init(allocator, terminal, stdin);
    defer e.deinit();

    // try e.open();
    try e.openFile("tests/file.txt");

    try e.start();
}

test "isCtrlKey" {
    const isCtrlQ = isCtrlKey(17, 'q');

    try expect(isCtrlQ);
}
