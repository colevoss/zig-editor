const std = @import("std");
const display = @import("display.zig");
const Input = @import("Input.zig");

const Term = @import("term.zig").Term;

const log = std.log.scoped(.editor);

pub const Editor = struct {
    allocator: std.mem.Allocator,

    term: Term,

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

    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, term: Term) Self {
        const disp = display.Display{
            .rows = term.rows,
            .cols = term.cols,
            .fileRows = 0,
            .buffer = 5,
        };

        return .{
            .allocator = alloc,
            .term = term,
            .display = disp,
            .rows = std.ArrayList(Row).init(alloc),
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.rows.items) |row| {
            self.allocator.free(row.chars);
        }

        self.rows.deinit();
    }

    pub fn open(self: *Self, path: []const u8) !void {
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

    fn draw(self: *Self) !void {
        try self.term.prepare();

        var i: usize = 0;

        var rows: usize = undefined;

        if (self.term.rows < self.rows.items.len) {
            rows = self.term.rows;
        } else {
            rows = self.rows.items.len;
        }

        while (i < rows) : (i += 1) {
            const rowI = i + self.display.offsetY;
            try self.term.drawRow(self.rows.items[rowI].chars, i);
        }

        try self.term.finish(i, self.display.cursorX, self.display.cursorY);
    }

    pub fn start(self: *Self, reader: anytype) !void {
        defer {
            self.term.reset() catch unreachable;
        }

        log.debug("Starting editori", .{});
        log.err("Startin editor (err)", .{});

        while (true) {
            try self.draw();

            self.read(reader) catch |err| switch (err) {
                Error.Quit => {
                    return;
                },
                else => {
                    log.err("Error processing input {}\n", .{err});
                    continue;
                },
            };
        }
    }

    pub fn read(self: *Self, reader: anytype) !void {
        var buf: [3]u8 = undefined;
        const n = try reader.readAtLeast(&buf, 1);
        const i = try Input.read(n, &buf);

        return self.processInput(i);
    }

    pub fn processInput(self: *Self, input: Input.Action) !void {
        switch (input.tag) {
            .none => return,
            .escape, .illegal => {
                return Error.Quit;
            },
            .move_up,
            .move_down,
            .move_right,
            .move_left,
            => {
                self.moveCursor(input.tag);
            },
            .printable => {
                log.debug("Char {c}", .{input.data});
            },
        }
    }

    pub fn moveCursor(self: *Self, tag: Input.Action.Tag) void {
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
