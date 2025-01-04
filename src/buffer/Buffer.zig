const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = @import("Reader.zig");

allocator: Allocator,
capacity: usize,
bytes: []u8,

const Self = @This();

const BufferError = error{
    SeekOutOfBounds,
};

pub fn init(allocator: Allocator) Self {
    return Self{
        .allocator = allocator,
        .capacity = 0,
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
}

pub fn clear(self: *Self) void {
    @memset(self.bytes, 0);
    self.bytes.len = 0;
}

inline fn allocatedSlice(self: *Self) []u8 {
    return self.bytes.ptr[0..self.capacity];
}

pub fn reader(self: *Self) Reader {
    return Reader{
        .buffer = self,
        .pos = 0,
    };
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

pub fn append(self: *Self, byte: u8) Allocator.Error!void {
    const pos = self.bytes.len;
    const end = pos + @sizeOf(u8);
    try self.checkCapacity(end);
    self.bytes.len = end;
    self.bytes[pos] = byte;
}

pub fn appendInt(self: *Self, comptime T: type, value: T, endian: std.builtin.Endian) Allocator.Error!void {
    const count = @divExact(@typeInfo(T).int.bits, 8);
    const end = self.bytes.len + count;
    try self.checkCapacity(end);

    std.mem.writeInt(T, self.allocatedSlice()[self.bytes.len..][0..count], value, endian);
    self.bytes.len = end;
}

pub fn appendSlice(self: *Self, bytes: []const u8) Allocator.Error!void {
    const pos = self.bytes.len;
    const end = pos + bytes.len;
    try self.checkCapacity(end);

    const slice = self.allocatedSlice()[pos..][0..bytes.len];
    @memcpy(slice[0..bytes.len], bytes);
    self.bytes.len = end;
}

pub fn replaceAssumeBounds(self: *Self, index: usize, byte: u8) void {
    std.debug.assert(index < self.bytes.len);

    self.bytes[index] = byte;
}

pub fn replaceIntAssumeBounds(self: *Self, comptime T: type, index: usize, value: T, endian: std.builtin.Endian) void {
    const count = @divExact(@typeInfo(T).Int.bits, 8);
    std.debug.assert(self.bytes.len + count < index + count);

    std.mem.writeInt(T, &self.bytes[index..][0..count], value, endian);
}

test "Buffer.init" {
    var msg = Self.init(std.testing.allocator);

    try std.testing.expect(msg.bytes.len == 0);
    try std.testing.expect(msg.capacity == 0);

    msg.deinit();
}

test "Buffer.initCapacity" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 50);

    try std.testing.expect(msg.bytes.len == 0);
    try std.testing.expect(msg.capacity == 50);

    msg.deinit();
}

test "Buffer.ensureCapacity growth" {
    var msg: Self = Self.init(std.testing.allocator);
    defer msg.deinit();

    try msg.ensureCapacity(10);
    var slice = msg.allocatedSlice();

    try std.testing.expectEqual(10, slice.len);
    try std.testing.expectEqual(10, msg.capacity);

    try msg.ensureCapacity(20);
    slice = msg.allocatedSlice();

    try std.testing.expectEqual(20, slice.len);
    try std.testing.expectEqual(20, msg.capacity);
}

test "Buffer.ensureCapacity already big enough" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 20);
    defer msg.deinit();

    try msg.ensureCapacity(10);
    const slice = msg.allocatedSlice();

    try std.testing.expectEqual(20, slice.len);
    try std.testing.expectEqual(20, msg.capacity);
}

test "Buffer.ensureCapacity grow it" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 5);
    defer msg.deinit();

    try msg.ensureCapacity(10);
    const slice = msg.allocatedSlice();

    try std.testing.expectEqual(10, slice.len);
    try std.testing.expectEqual(10, msg.capacity);
}

test "Buffer.checkCapacity already big enough" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.checkCapacity(5);
    const slice = msg.allocatedSlice();

    try std.testing.expectEqual(10, slice.len);
    try std.testing.expectEqual(10, msg.capacity);
}

test "Buffer.checkCapacity same size" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.checkCapacity(10);
    const slice = msg.allocatedSlice();

    try std.testing.expectEqual(10, slice.len);
    try std.testing.expectEqual(10, msg.capacity);
}

test "Buffer.checkCapacity grow it" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.checkCapacity(20);
    const slice = msg.allocatedSlice();

    try std.testing.expectEqual(20, slice.len);
    try std.testing.expectEqual(20, msg.capacity);
}

test "Buffer.append good single append" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.append(244);

    try std.testing.expectEqual(msg.bytes.len, 1);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 244);
}

test "Buffer.append good multiple append" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.append(244);
    try msg.append(220);

    try std.testing.expectEqual(msg.bytes.len, 2);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 244);
    try std.testing.expectEqual(msg.bytes[1], 220);
}

test "Buffer.append append to grow" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 2);
    defer msg.deinit();

    try msg.append(244);
    try msg.append(220);
    try msg.append(123);

    try std.testing.expectEqual(msg.bytes.len, 3);
    try std.testing.expectEqual(msg.capacity, 3);
    try std.testing.expectEqual(msg.bytes[0], 244);
    try std.testing.expectEqual(msg.bytes[1], 220);
    try std.testing.expectEqual(msg.bytes[2], 123);
}

test "Buffer.clear" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.append(244);
    try msg.append(220);
    try msg.append(123);
    msg.clear();

    try std.testing.expectEqual(msg.bytes.len, 0);
    try std.testing.expectEqual(msg.capacity, 10);
    msg.bytes.len = 3;
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 0);
}

test "Buffer.clear already clear" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.append(244);
    try msg.append(220);
    try msg.append(123);
    msg.clear();

    try std.testing.expectEqual(msg.bytes.len, 0);
    try std.testing.expectEqual(msg.capacity, 10);
    msg.bytes.len = 3;
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 0);
    msg.bytes.len = 0;

    msg.clear();
    try std.testing.expectEqual(msg.bytes.len, 0);
    try std.testing.expectEqual(msg.capacity, 10);
    msg.bytes.len = 3;
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 0);
}

test "Buffer.appendInt little with space" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}
//pub fn appendInt(self: *Self, comptime T: type, value: T, endian: std.builtin.Endian) Allocator.Error!void {
//pub fn appendSlice(self: *Self, bytes: []const u8) Allocator.Error!void {
//pub fn replaceAssumeBounds(self: *Self, index: usize, byte: u8) void {
//pub fn replaceIntAssumeBounds(self: *Self, comptime T: type, index: usize, value: T, endian: std.builtin.Endian) void {
