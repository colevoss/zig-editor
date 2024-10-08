const std = @import("std");

pub fn stdErrLog(
    comptime level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ "(" ++ @tagName(scope) ++ ") ";

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const file = std.fs.cwd().createFile("editor.log", .{ .read = true }) catch |err| {
        std.debug.print("Could not open file {}", .{err});
        return;
    };

    defer file.close();

    const stat = file.stat() catch |err| {
        std.debug.print("Failed to get stat for file: {}", .{err});
        return;
    };

    file.seekTo(stat.size) catch |err| {
        std.debug.print("Failed to seed to end of file: {}", .{err});
        return;
    };

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ "(" ++ @tagName(scope) ++ ") ";
    var buffer: [256]u8 = undefined;
    const message = std.fmt.bufPrint(buffer[0..], prefix ++ format ++ "\n", args) catch |err| {
        std.debug.print("Failed to format log message: {}", .{err});
        return;
    };

    file.writeAll(message) catch |err| {
        std.debug.print("Failed to write to log file {}", .{err});
        return;
    };
}
