const std = @import("std");

const log = std.log.scoped(.input);

const State = enum {
    read,
    control,
    escape,
};

pub const Action = struct {
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

pub inline fn ctrlKey(comptime char: u8) u8 {
    return char & 0b00011111;
}

pub fn read(reader: anytype) !Action {
    var state = State.read;

    var input = Action{
        .tag = .none,
    };

    var buf: [3]u8 = undefined;
    const n = try reader.readAtLeast(&buf, 1);

    var i: u8 = 0;
    while (i < n) : (i += 1) {
        // const c = self.inputBuffer[i];
        const c = buf[i];

        switch (state) {
            .read => switch (c) {
                ctrlKey('c') => {
                    input.tag = .escape;
                    break;
                },
                '\x1b' => {
                    if (n == 1) {
                        input.tag = .escape;
                        break;
                    }

                    state = .escape;
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
                    input.tag = Action.Tag.moveFromKey(c);
                    break;
                },
                '0'...'9' => {},
                else => {},
            },
        }
    }

    return input;
}
