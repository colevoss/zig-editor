const std = @import("std");
const keys = @import("keys.zig");
const display = @import("display.zig");

const Term = @import("term.zig").Term;
const Input = keys.Input;

const log = std.log.scoped(.editor);

pub const Editor = struct {
    allocator: std.mem.Allocator,

    term: Term,
    in: std.fs.File,
    reader: std.fs.File.Reader,

    inputBuffer: [3]u8 = undefined,

    rows: std.ArrayList(Row),

    rowOffset: usize = 0,
    colOffset: usize = 0,

    display: display.Display,

    const Row = struct {
        chars: []u8,
    };

    pub const Error = error{
        Quit,
        InvalidMoveChar,
    };

    pub const State = enum {
        read,
        control,
        escape,
    };

    pub fn init(alloc: std.mem.Allocator, term: Term, in: std.fs.File) Editor {
        const disp = display.Display{
            .rows = term.rows,
            .cols = term.cols,
            .fileRows = 0,
            .buffer = 5,
        };

        return .{
            .allocator = alloc,
            .in = in,
            .reader = in.reader(),
            .term = term,
            .display = disp,
            .rows = std.ArrayList(Row).init(alloc),
        };
    }

    pub fn deinit(self: *Editor) void {
        for (self.rows.items) |row| {
            self.allocator.free(row.chars);
        }

        self.rows.deinit();
    }

    pub fn open(self: *Editor, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var bufReader = std.io.bufferedReader(file.reader());
        const reader = bufReader.reader();

        var line = std.ArrayList(u8).init(self.allocator);
        defer line.deinit();

        const writer = line.writer();

        while (reader.streamUntilDelimiter(writer, '\n', null)) {
            errdefer line.clearRetainingCapacity();
            const chars = try line.toOwnedSlice();

            try self.rows.append(.{
                .chars = chars,
            });
        } else |err| switch (err) {
            error.EndOfStream => {
                log.debug("Finished reading file", .{});
            },
            else => return err,
        }

        self.display.reset();
        self.display.fileRows = self.rows.items.len;
    }

    fn draw(self: *Editor) !void {
        try self.term.prepare();

        var i: usize = 0;

        var rows: usize = undefined;

        if (self.term.rows < self.rows.items.len) {
            rows = self.term.rows;
        } else {
            rows = self.rows.items.len;
        }
        // const rows = @min(self.term.rows, self.rows.items.len);

        while (i < rows) : (i += 1) {
            const rowI = i + self.display.offsetY;
            // log.debug("rowI {d}", .{rowI});
            try self.term.drawRow(self.rows.items[rowI].chars, i);
        }

        try self.term.finish(i, self.display.cursorX, self.display.cursorY);
    }

    pub fn start(self: *Editor) !void {
        try self.draw();

        defer {
            self.term.cx = 0;
            self.term.cy = 0;
            self.term.prepare() catch unreachable;
            self.term.finish(0, 0, 0) catch unreachable;
        }

        log.debug("Starting editori", .{});
        log.err("Startin editor (err)", .{});

        while (true) {
            // try self.term.refreshScreen();
            try self.draw();

            const input = try self.read();

            switch (input.tag) {
                .none => continue,
                .escape, .illegal => return,
                .move_up, .move_down, .move_right, .move_left => {
                    self.moveCursor(input.tag);
                },
                .printable => {
                    log.debug("Char {c}", .{input.data});
                    // try writer.writeByte(input.data);
                    // try writer.print("{c}", .{input.data});
                },
            }
        }
    }

    fn read(self: *Editor) !Input {
        var state = State.read;

        var input = Input{
            .tag = .none,
        };

        const n = try self.reader.readAtLeast(&self.inputBuffer, 1);

        var i: u8 = 0;

        while (i < n) : (i += 1) {
            const c = self.inputBuffer[i];

            switch (state) {
                .read => switch (c) {
                    keys.ctrlKey('c') => {
                        input.tag = .escape;
                        break;
                    },
                    // 'h', 'j', 'k', 'l' => {
                    //     input.tag = Input.Tag.moveFromKey(c);
                    //     break;
                    // },
                    32...126 => {
                        input.tag = .printable;
                        input.data = c;

                        break;
                    },
                    '\x1b' => {
                        if (n == 1) {
                            input.tag = .escape;
                            break;
                        }

                        state = .escape;
                    },
                    else => {},
                },
                .escape => {
                    switch (c) {
                        '[' => {
                            state = .control;
                        },
                        else => {
                            log.debug("IDK esc", .{});
                        },
                    }
                },
                .control => switch (c) {
                    'A', 'B', 'C', 'D' => {
                        input.tag = Input.Tag.moveFromKey(c);
                        break;
                    },
                    '0'...'9' => {},
                    else => {},
                },
            }
        }

        return input;
    }

    pub fn moveCursor(self: *Editor, tag: Input.Tag) void {
        switch (tag) {
            .move_left => {
                self.display.move(.left, 1);
            },
            .move_right => {
                self.display.move(.right, 1);
            },
            .move_up => {
                self.display.move(.up, 1);
            },
            .move_down => {
                self.display.move(.down, 1);
            },
            else => unreachable,
        }
    }
};
