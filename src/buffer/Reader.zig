const std = @import("std");
const Buffer = @import("Buffer.zig");

// debating between []const u8 or Buffer...
buffer: *Buffer,
pos: usize,

const Self = @This();

pub fn readUntilDelimiter(self: *Self, delimiter: u8) ![]const u8 {
    const idx = std.mem.indexOfScalar(u8, self.buffer.bytes[self.pos..], delimiter) + 1;
    defer self.pos = idx;

    return self.buffer.bytes[self.pos..idx];
}

pub fn readByte(self: *Self) u8 {
    defer self.pos += 1;

    return self.buffer.bytes[self.pos];
}

pub fn readInt(self: *Self, comptime T: type) T {
    defer self.pos += @sizeOf(T);

    return std.mem.bigToNative(T, std.mem.bytesAsValue(T, self.buffer.bytes[self.pos..@sizeOf(T)]).*);
}

test "readByte good read" {
    var buf = Buffer.init(std.testing.allocator);
    defer buf.deinit();
    try buf.append('T');

    var reader = buf.reader();

    const ch = reader.readByte();

    try std.testing.expectEqual('T', ch);
}
