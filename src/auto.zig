const std = @import("std");
const term = @import("term.zig");
const editor = @import("editor.zig");
const posix = std.posix;
const logfns = @import("log.zig");
const expect = std.testing.expect;
const Thread = std.Thread;
const Mutext = Thread.Mutex;

pub const std_options = .{
    // .log_level = .debug,
    .logFn = logfns.stdErrLog,
};

const Fifo = std.fifo.LinearFifo(u8, .Dynamic);

const Pipe = struct {
    mutext: Mutext,
    interval: usize,
    file: []const u8,
    allocator: std.mem.Allocator,
    fifo: *Fifo,

    pub fn start(self: *Pipe) void {
        const file = std.fs.cwd().openFile(self.file, .{}) catch |err| {
            std.debug.print("ERR {}", .{err});
            return;
        };
        defer file.close();

        var fileBufReader = std.io.bufferedReader(file.reader());
        const reader = fileBufReader.reader();

        var line = std.ArrayList(u8).init(self.allocator);
        defer line.deinit();

        const writer = line.writer();

        while (reader.streamUntilDelimiter(writer, '\n', null)) {
            self.mutext.lock();
            defer {
                line.clearRetainingCapacity();
                self.mutext.unlock();
                std.time.sleep(self.interval * std.time.ns_per_ms);
            }

            self.fifo.write(line.items) catch unreachable;
        } else |err| {
            std.debug.print("Stream ERR {}", .{err});
            return;
        }
    }

    pub fn startStdIn(self: *Pipe) void {
        const stdin = std.io.getStdIn();
        const reader = stdin.reader();

        var buf: [3]u8 = undefined;

        while (true) {
            const n = reader.read(&buf) catch unreachable;

            if (n == 0) {
                continue;
            }

            self.mutext.lock();
            defer {
                self.mutext.unlock();
                std.time.sleep(self.interval * std.time.ns_per_ms);
            }

            self.fifo.write(&buf) catch unreachable;
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var fifo = std.fifo.LinearFifo(u8, .Dynamic).init(allocator);
    // var fifo = Fifo.init(allocator);
    defer fifo.deinit();

    // var reader = fifo.reader();

    var pipe = Pipe{
        .allocator = allocator,
        .mutext = Mutext{},
        .interval = 250,
        .fifo = &fifo,
        .file = "tests/commands.txt",
    };

    var thread1 = try std.Thread.spawn(.{}, Pipe.start, .{&pipe});
    var thread2 = try std.Thread.spawn(.{}, Pipe.startStdIn, .{&pipe});

    const stdout = std.io.getStdOut();
    // const stdin = std.io.getStdIn();

    // var termio = try term.TermIO.init(stdout);
    // defer termio.deinit();
    //
    // const dimensions = try termio.size();

    const terminal = term.Term.init(.{
        .file = stdout,
        .rows = 20,
        .cols = 20,
    });

    var e = editor.Editor(*std.fifo.LinearFifo(u8, .Dynamic)).init(allocator, terminal, *fifo);
    defer e.deinit();

    try e.open("tests/file.txt");
    // try e.start();
    while (true) {
        std.debug.print("len {d}", .{fifo.readableLength()});
        std.time.sleep(2000 * std.time.ns_per_ms);
        const input = try e.read();
        std.debug.print("Input: {}\n", .{input});
    }

    thread1.join();
    thread2.join();
}
