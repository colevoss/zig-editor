const std = @import("std");
const posix = std.posix;

const log = std.log.scoped(.term);

pub const Term = struct {
    const BufferedWriter = std.io.BufferedWriter(4096, std.fs.File.Writer);

    buf: BufferedWriter,

    cx: u16 = 0,
    cy: u16 = 0,

    rows: usize,
    cols: usize,

    pub const Config = struct {
        // file: std.fs.File,
        rows: u16,
        cols: u16,
    };

    pub fn init(buf: BufferedWriter, config: Config) Term {
        // const buf = std.io.bufferedWriter(config.file.writer());

        return .{
            .buf = buf,
            .rows = config.rows,
            .cols = config.cols,
        };
    }

    pub fn reset(self: *Term) !void {
        try self.prepare();
        _ = try self.buf.write("\x1b[?25h");
        try self.buf.flush();
    }

    pub fn prepare(self: *Term) !void {
        try self.clear();
        // hide cursor
        _ = try self.buf.write("\x1b[?25l");

        // reset cursor to 0
        _ = try self.buf.write("\x1b[H");
    }

    pub fn clear(self: *Term) !void {
        _ = try self.buf.write("\x1b[2J");
    }

    pub fn drawRow(self: *Term, str: []const u8, row: usize) !void {
        _ = try self.buf.write(str);
        // clear row right of tilde
        _ = try self.buf.write("\x1b[K");

        if (row < self.rows - 1) {
            _ = try self.buf.write("\r\n");
        }
    }

    pub fn finish(self: *Term, rowStart: usize, cx: usize, cy: usize) !void {
        var i: usize = rowStart;

        while (i < self.rows) : (i += 1) {
            _ = try self.buf.write("~");
            // clear row right of tilde
            _ = try self.buf.write("\x1b[K");

            if (i < self.rows - 1) {
                _ = try self.buf.write("\r\n");
            }
        }

        try self.drawCursor(cx, cy);

        // Reshow cursor
        _ = try self.buf.write("\x1b[?25h");
        try self.buf.flush();
    }

    pub fn drawCursor(self: *Term, x: usize, y: usize) !void {
        try std.fmt.format(
            self.buf.writer(),
            "\x1b[{d};{d}H",
            .{ y + 1, x + 1 },
        );
    }

    pub fn drawRows(self: *Term) !void {
        var i: u8 = 0;

        while (i < self.rows) : (i += 1) {
            _ = try self.buf.write("~");
            // clear row right of tilde
            _ = try self.buf.write("\x1b[K");

            if (i < self.rows - 1) {
                _ = try self.buf.write("\r\n");
            }
        }
    }

    pub inline fn flush(self: *Term) !void {
        try self.buf.flush();
    }
};

pub const TermIO = struct {
    file: std.fs.File,
    originalSettings: std.c.termios,

    pub fn init(file: std.fs.File) !TermIO {
        const originalSettings = try configure(file);

        return .{
            .file = file,
            .originalSettings = originalSettings,
        };
    }

    pub fn deinit(self: *TermIO) void {
        posix.tcsetattr(self.file.handle, posix.TCSA.NOW, self.originalSettings) catch |e| {
            std.debug.print("Error exiting term {}", .{e});
        };
    }

    pub const ConfigError = posix.TermiosGetError || posix.TermiosSetError;

    fn configure(file: std.fs.File) ConfigError!posix.termios {
        const originalSettings = try posix.tcgetattr(file.handle);

        try posix.tcsetattr(
            file.handle,
            posix.TCSA.NOW,
            settings(originalSettings),
        );

        return originalSettings;
    }

    pub fn size(self: TermIO) !posix.system.winsize {
        var sizeBuf: posix.system.winsize = undefined;

        const res = posix.system.ioctl(
            self.file.handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&sizeBuf),
        );

        if (res != 0) {
            return error.IoctlError;
        }

        return sizeBuf;
    }

    fn settings(orig: posix.termios) posix.termios {
        var newSettings = orig;

        newSettings.lflag.ECHO = false;
        // disable cannon mode, enter raw mode
        newSettings.lflag.ICANON = false;
        // disable CTRL-C and CTRL-Z
        newSettings.lflag.ISIG = false;
        // disables CTRL-V
        newSettings.lflag.IEXTEN = false;
        // disables CTRL-S and CTRL-Q
        newSettings.iflag.IXON = false;
        // disables CTRL-M
        newSettings.iflag.ICRNL = false;

        // disables output post processing
        newSettings.oflag.OPOST = false;

        // misc
        newSettings.iflag.BRKINT = false;
        newSettings.iflag.ISTRIP = false;
        newSettings.iflag.INPCK = false;
        newSettings.cflag.CSIZE = posix.CSIZE.CS8;
        newSettings.cc[@intFromEnum(posix.V.MIN)] = 0;
        newSettings.cc[@intFromEnum(posix.V.TIME)] = 1;

        return newSettings;
    }
};
