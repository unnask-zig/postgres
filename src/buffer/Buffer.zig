const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = @import("Reader.zig");

allocator: Allocator,
capacity: usize,
pos: usize,
bytes: []u8,

const Self = @This();

const BufferError = error{
    SeekOutOfBounds,
};

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
        .capacity = 0,
        .pos = 0,
        .bytes = &[_]u8{},
    };
}

pub fn initCapacity(allocator: Allocator, capacity: usize) Allocator.Error!Self {
    var tmp = init(allocator);
    try tmp.ensureCapacity(capacity);

    return tmp;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.allocatedSlice());
    self.capacity = 0;
    self.pos = 0;
}

fn allocatedSlice(self: *Self) []u8 {
    return self.bytes.ptr[0..self.capacity];
}

pub fn getPos(self: *Self) usize {
    return self.pos;
}

pub fn reader(self: *Self) Reader {
    return Reader{
        .buffer = self,
        .pos = 0,
    };
}

pub fn seekBy(self: *Self, amt: usize) BufferError!void {
    const tmp = self.pos +| amt;
    if (tmp > self.bytes.len) {
        return BufferError.SeekOutOfBounds;
    }
    self.pos += amt;
}

pub fn seekTo(self: *Self, pos: usize) BufferError!void {
    if (pos > self.bytes.len) {
        return BufferError.SeekOutOfBounds;
    }
    self.pos = pos;
}

pub fn ensureCapacity(self: *Self, new_capacity: usize) Allocator.Error!void {
    if (self.capacity >= new_capacity) {
        return;
    }

    const tmp = self.allocatedSlice();

    if (self.allocator.resize(tmp, new_capacity)) {
        self.capacity = new_capacity;
    } else {
        // Note that bytes is a fat pointer made up of
        //      ptr: usize, len: usize
        // and it is "perfeclt fine" to modify those components of the
        // fat pointer.
        // Thus simply just updating the bytes.ptr value will enable
        // the capacity to be larger than bytes.len. This helps in using
        // the bytes in a more ergonomic way.
        // However, one must be careful when giving the pointer away as
        // losing the capacity info would be bad

        const new = try self.allocator.alloc(u8, new_capacity);

        @memcpy(new[0..self.bytes.len], self.bytes);

        self.bytes.ptr = new.ptr;
        self.capacity = new_capacity;
        self.allocator.free(tmp);
    }
}

pub fn checkCapacity(self: *Self, needed_capacity: usize) Allocator.Error!void {
    if (self.capacity >= needed_capacity) {
        return;
    }

    //todo: is better growth properties needed?
    try self.ensureCapacity(needed_capacity);
}

pub fn writeByte(self: *Self, byte: u8) Allocator.Error!void {
    const end = self.pos + @sizeOf(u8);
    try self.checkCapacity(end);
    if (self.bytes.len < end) {
        self.bytes.len = end;
    }
    self.bytes[self.pos] = byte;
    self.pos = end;
}

pub fn writeAll(self: *Self, bytes: []const u8) Allocator.Error!void {
    const end = self.pos + bytes.len;
    try self.checkCapacity(end);

    const slice = self.allocatedSlice()[self.pos..][0..bytes.len];
    @memcpy(slice[0..bytes.len], bytes);
    self.pos = end;
}

pub fn writeInt(self: *Self, comptime T: type, value: T, endian: std.builtin.Endian) Allocator.Error!void {
    const count = @divExact(@typeInfo(T).Int.bits, 8);
    const end = self.pos + count;
    try self.checkCapacity(end);

    std.mem.writeInt(T, &self.bytes[self.pos..][0..count], value, endian);
    self.pos = end;
}

test "Buffer.init" {
    var msg = Self.init(std.testing.allocator);

    try std.testing.expect(msg.bytes.len == 0);
    try std.testing.expect(msg.pos == 0);
    try std.testing.expect(msg.capacity == 0);

    msg.deinit();
}

test "Buffer.initCapacity" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 50);

    try std.testing.expect(msg.bytes.len == 0);
    try std.testing.expect(msg.pos == 0);
    try std.testing.expect(msg.capacity == 50);

    msg.deinit();
}
