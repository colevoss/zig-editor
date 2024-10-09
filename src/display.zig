const std = @import("std");
const expect = std.testing.expect;

const log = std.log.scoped(.display);

pub const Display = struct {
    const Move = enum { up, down, left, right };

    cols: usize,
    rows: usize,

    // position in display
    cursorX: usize = 0,
    cursorY: usize = 0,

    offsetX: usize = 0,
    offsetY: usize = 0,

    // Count of rows in a file
    fileRows: usize,

    // amount of rows or columns to leave if there is more to scroll
    buffer: usize = 0,

    pub fn reset(self: *Display) void {
        self.cursorY = 0;
        self.cursorX = 0;
        self.offsetX = 0;
        self.offsetY = 0;
    }

    pub fn move(self: *Display, dir: Move, times: usize) void {
        var i: usize = 0;

        while (i < times) : (i += 1) {
            switch (dir) {
                .up => self.moveUp(),
                .down => self.moveDown(),
                .left => self.moveLeft(),
                .right => self.moveRight(),
            }
        }
    }

    // NOTE: These don't currently account for the file length changing
    pub fn moveUp(self: *Display) void {
        // cursor is at the top. cannot scroll further
        if (self.cursorY == 0) {
            return;
        }

        if (self.fileRows < self.rows or self.offsetY == 0) {
            self.cursorY -= 1;
            return;
        }

        if (self.cursorY > self.buffer) {
            self.cursorY -= 1;
            return;
        }

        // scroll the display "down" (show next line down)
        self.offsetY -= 1;
    }

    pub fn moveDown(self: *Display) void {
        // if cursor is on the last line of a file or the bottom of row of display
        if (self.cursorY == self.fileRows - 1 or self.cursorY == self.rows - 1) {
            return;
        }

        // if file is fewer rows than display, just move cursor down
        if (self.fileRows < self.rows) {
            self.cursorY = @addWithOverflow(self.cursorY, 1)[0];
            return;
        }

        // rows + offsetY represents the last displayed row of the file
        // thus subtracting that from the file row count tells us how many rows
        // are below the fold of the editor, or how many lines can be scrolled yet
        const fileRowsBelowFold = self.fileRows - (self.rows + self.offsetY);
        if (fileRowsBelowFold == 0) {
            self.cursorY = @addWithOverflow(self.cursorY, 1)[0];
            return;
        }

        // bufferRow represents which row the cursor should stop on when moving down
        const bufferRow = self.rows - self.buffer;
        // have not reached buffer yet
        if (self.cursorY < bufferRow - 1) {
            self.cursorY = @addWithOverflow(self.cursorY, 1)[0];
            return;
        }

        // scroll the display "down" (show next line down)
        self.offsetY = @addWithOverflow(self.offsetY, 1)[0];
    }

    pub fn moveLeft(self: *Display) void {
        if (self.cursorX == 0) {
            return;
        }

        self.cursorX -= 1;
    }

    pub fn moveRight(self: *Display) void {
        self.cursorX = @addWithOverflow(self.cursorX, 1)[0];
    }
};

test "moveDown moves cursor down until it hits buffer" {
    var display = Display{
        .cols = 10,
        .rows = 10,

        .fileRows = 100,
        .buffer = 5,
    };

    display.move(.down, 2);
    try expect(display.cursorY == 2);

    display.move(.down, 3);
    try expect(display.cursorY == 4);

    display.move(.down, 3);
    try expect(display.cursorY == 4);

    display.move(.down, 10);
    try expect(display.cursorY == 4);
}

test "moveDown does not move past end of file" {
    var display = Display{
        .cols = 10,
        .rows = 20,
        .fileRows = 10,
        .buffer = 0,
    };

    display.move(.down, 1);
    try expect(display.cursorY == 1);

    display.move(.down, 9);
    try expect(display.cursorY == 9);
}

test "moveDown scrolls display if buffer has been met but has not reached end of file" {
    var display = Display{
        .cols = 10,
        .rows = 20,
        .fileRows = 100,
        .buffer = 10,
    };

    // should scroll one row
    display.move(.down, 10);
    try expect(display.cursorY == 9);
    try expect(display.offsetY == 1);

    display.move(.down, 4);
    try expect(display.offsetY == 5);
}

test "moveDown moves cursor down if end of file has been scrolled to" {
    var display = Display{
        .cols = 10,
        .rows = 10,
        .fileRows = 25,
        .buffer = 5,
    };

    display.move(.down, 5);
    try expect(display.offsetY == 1); // scrolled one row
    try expect(display.cursorY == 4);

    display.move(.down, 5);
    try expect(display.offsetY == 6); // scrolled up 5 more rows
    try expect(display.cursorY == 4); // cursor stays

    display.move(.down, 5);
    try expect(display.offsetY == 11); // Scrolled up 5 more rows
    try expect(display.cursorY == 4); // cursor still stays

    display.move(.down, 5);
    try expect(display.offsetY == 15); // Scrolled as far as we could
    try expect(display.cursorY == 5); // cursor moves down one

    // move down a ton
    display.move(.down, 100);
    try expect(display.offsetY == 15); // scrolled as far as we could
    try expect(display.cursorY == 9); // Maxed out at bottom of display
}
