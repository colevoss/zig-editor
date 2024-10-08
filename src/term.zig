const std = @import("std");
const posix = std.posix;

pub const Term = struct {
    buf: std.io.BufferedWriter(4096, std.fs.File.Writer),

    cx: u16 = 0,
    cy: u16 = 0,

    rows: u16,
    cols: u16,

    pub const Config = struct {
        file: std.fs.File,
        rows: u16,
        cols: u16,
    };

    pub fn init(config: Config) Term {
        const buf = std.io.bufferedWriter(config.file.writer());

        return .{
            .buf = buf,
            .rows = config.rows,
            .cols = config.cols,
        };
    }

    pub fn prepare(self: *Term) !void {
        // hide cursor
        _ = try self.buf.write("\x1b[?25l");

        // reset cursor to 0
        _ = try self.buf.write("\x1b[H");
    }

    pub fn drawRow(self: *Term, row: []const u8) !void {
        _ = try self.buf.write(row);
        // clear row right of tilde
        _ = try self.buf.write("\x1b[K");
        _ = try self.buf.write("\r\n");
    }

    pub fn finish(self: *Term, rowStart: u8) !void {
        var i: u8 = rowStart;
        // var i: u8 = 0;

        while (i < self.rows) : (i += 1) {
            _ = try self.buf.write("~");
            // clear row right of tilde
            _ = try self.buf.write("\x1b[K");

            if (i < self.rows - 1) {
                _ = try self.buf.write("\r\n");
            }
        }

        try self.drawCursor();

        // Reshow cursor
        _ = try self.buf.write("\x1b[?25h");
        try self.buf.flush();
    }

    pub fn refreshScreen(self: *Term) !void {
        // hide cursor
        _ = try self.buf.write("\x1b[?25l");

        // reset cursor to 0
        _ = try self.buf.write("\x1b[H");

        try self.drawRows();
        try self.drawCursor();

        // Reshow cursor
        _ = try self.buf.write("\x1b[?25h");
        try self.buf.flush();
    }

    pub fn drawCursor(self: *Term) !void {
        try std.fmt.format(
            self.buf.writer(),
            "\x1b[{d};{d}H",
            .{
                self.cy + 1,
                self.cx + 1,
            },
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
        newSettings.lflag.IEXTEN = false; // disables CTRL-S and CTRL-Q newSettings.iflag.IXON = false;
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
