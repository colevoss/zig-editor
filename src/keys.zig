const std = @import("std");

pub inline fn ctrlKey(comptime char: u8) u8 {
    return char & 0b00011111;
}

pub const Input = struct {
    tag: Tag,
    data: Data = 0,

    pub const Data = u8;

    pub const Tag = enum {
        illegal,
        none,

        escape,

        printable,

        move_up,
        move_down,
        move_left,
        move_right,

        pub fn moveFromKey(key: u8) Tag {
            return switch (key) {
                'h', 'D' => .move_left,
                'l', 'C' => .move_right,
                'k', 'A' => .move_up,
                'j', 'B' => .move_down,
                else => .illegal,
            };
        }
    };
};
