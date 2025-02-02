const std = @import("std");
const Allocator = std.mem.Allocator;
const Buffer = @import("Buffer.zig");

// debating between []const u8 or Buffer...
buffer: *Buffer,
pos: usize,

const Self = @This();

const ReaderError = error{
    StartIndexOutOfRange,
    EndIndexOutOfRange,
};

pub fn peek(self: *Self) u8 {
    return self.buffer.bytes[self.pos];
}

pub fn readByte(self: *Self) u8 {
    defer self.pos += 1;

    return self.buffer.bytes[self.pos];
}

pub fn readInt(self: *Self, comptime T: type) T {
    defer self.pos += @sizeOf(T);
    const end = self.pos + @sizeOf(T);

    return std.mem.bigToNative(T, std.mem.bytesAsValue(T, self.buffer.bytes[self.pos..end]).*);
}

pub fn readIntoSlice(self: *Self, slice: []u8) void {
    const end = self.pos + slice.len;
    @memcpy(slice, self.buffer.bytes[self.pos..end]);
    self.pos = slice.len;
}

pub fn readUntilDelimiter(self: *Self, delimiter: u8) ![]const u8 {
    const idx = std.mem.indexOfScalar(u8, self.buffer.bytes[self.pos..], delimiter) + 1;
    defer self.pos = idx;

    return self.buffer.bytes[self.pos..idx];
}

pub fn dupeUntilDelimiter(self: *Self, delimiter: u8) ![]const u8 {
    const idx = std.mem.indexOfScalar(u8, self.buffer.bytes[self.pos..], delimiter) + 1;
    const tmp = self.buffer.bytes[self.pos..idx];
    defer self.pos = idx;

    return self.buffer.allocator.dupe(u8, tmp);
}

pub fn readUntilEnd(self: *Self) []const u8 {
    defer self.pos = self.buffer.bytes.len;

    return self.buffer.bytes[self.pos..];
}

//TODO: I am well aware of the inconsistency in this API
// Just deciding if I like using the Buffer allocator better, or if I like
// passing passing it in better. Will probably come down to use.
// Using the Buffers allocator more tighly couples these things together,
// but I don't think that matters for this.
pub fn dupeUntilEnd(self: *Self, allocator: Allocator) ![]u8 {
    const tmp = self.buffer.bytes[self.pos..];
    defer self.pos += tmp.len;

    return allocator.dupe(u8, tmp);
}

test "readByte good read" {
    var buf = Buffer.init(std.testing.allocator);
    defer buf.deinit();
    try buf.append('T');

    var reader = buf.reader();

    const ch = reader.readByte();

    try std.testing.expectEqual('T', ch);
}
