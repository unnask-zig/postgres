const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = @import("Reader.zig");

allocator: Allocator,
capacity: usize,
bytes: []u8,

const Self = @This();

const BufferError = error{
    OutOfBounds,
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
    const count = @divExact(@typeInfo(T).int.bits, 8);
    std.debug.assert(index + count <= self.bytes.len);

    std.mem.writeInt(T, self.bytes[index..][0..count], value, endian);
}

pub fn replaceSliceAssumeBounds(self: *Self, index: usize, bytes: []const u8) void {
    const end = index + bytes.len;
    std.debug.assert(end <= self.bytes.len);

    @memcpy(self.bytes[index..][0..end], bytes);
}

pub fn replace(self: *Self, index: usize, byte: u8) BufferError!void {
    if (index > self.bytes.len) {
        return BufferError.OutOfBounds;
    }

    self.replaceAssumeBounds(index, byte);
}

pub fn replaceInt(self: *Self, comptime T: type, index: usize, value: T, endian: std.builtin.Endian) BufferError!void {
    const end = @divExact(@typeInfo(T).int.bits, 8);
    if (index + end > self.bytes.len) {
        return BufferError.OutOfBounds;
    }

    std.mem.writeInt(T, self.bytes[index..][0..end], value, endian);
}

pub fn replaceSlice(self: *Self, index: usize, bytes: []const u8) BufferError!void {
    const end = index + bytes.len;
    if (end > self.bytes.len) {
        return BufferError.OutOfBounds;
    }

    @memcpy(self.bytes[index..][0..end], bytes);
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

test "Buffer.appendInt big with space" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.big);

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 3);
    try std.testing.expectEqual(msg.bytes[2], 0);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.appendInt grow it" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 2);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 4);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.appendInt multiple appends" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 1);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);
    try msg.appendInt(i32, 196608, std.builtin.Endian.big);

    try std.testing.expectEqual(msg.bytes.len, 8);
    try std.testing.expectEqual(msg.capacity, 8);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
    try std.testing.expectEqual(msg.bytes[4], 0);
    try std.testing.expectEqual(msg.bytes[5], 3);
    try std.testing.expectEqual(msg.bytes[6], 0);
    try std.testing.expectEqual(msg.bytes[7], 0);
}

test "Buffer.appendSlice good with space" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6 };

    try msg.append(1);
    try msg.appendSlice(&bytes);

    try std.testing.expectEqual(msg.bytes.len, 7);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 1);
    try std.testing.expectEqual(msg.bytes[1], 1);
    try std.testing.expectEqual(msg.bytes[2], 2);
    try std.testing.expectEqual(msg.bytes[3], 3);
    try std.testing.expectEqual(msg.bytes[4], 4);
    try std.testing.expectEqual(msg.bytes[5], 5);
    try std.testing.expectEqual(msg.bytes[6], 6);
}

test "Buffer.appendSlice good and grow" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 1);
    defer msg.deinit();

    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6 };

    try msg.appendSlice(&bytes);

    try std.testing.expectEqual(msg.bytes.len, 6);
    try std.testing.expectEqual(msg.capacity, 6);
    try std.testing.expectEqual(msg.bytes[0], 1);
    try std.testing.expectEqual(msg.bytes[1], 2);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 4);
    try std.testing.expectEqual(msg.bytes[4], 5);
    try std.testing.expectEqual(msg.bytes[5], 6);
}

test "Buffer.appendSlice append after slice and grow" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 1);
    defer msg.deinit();

    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6 };

    try msg.appendSlice(&bytes);
    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    try std.testing.expectEqual(msg.bytes.len, 10);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 1);
    try std.testing.expectEqual(msg.bytes[1], 2);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 4);
    try std.testing.expectEqual(msg.bytes[4], 5);
    try std.testing.expectEqual(msg.bytes[5], 6);
    try std.testing.expectEqual(msg.bytes[6], 0);
    try std.testing.expectEqual(msg.bytes[7], 0);
    try std.testing.expectEqual(msg.bytes[8], 3);
    try std.testing.expectEqual(msg.bytes[9], 0);
}

test "Buffer.appendSlice append two slices" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 1);
    defer msg.deinit();

    const bytes = [_]u8{ 1, 2, 3, 4, 5, 6 };

    try msg.appendSlice(&bytes);
    try msg.appendSlice(&bytes);

    try std.testing.expectEqual(msg.bytes.len, 12);
    try std.testing.expectEqual(msg.capacity, 12);
    try std.testing.expectEqual(msg.bytes[0], 1);
    try std.testing.expectEqual(msg.bytes[1], 2);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 4);
    try std.testing.expectEqual(msg.bytes[4], 5);
    try std.testing.expectEqual(msg.bytes[5], 6);
    try std.testing.expectEqual(msg.bytes[6], 1);
    try std.testing.expectEqual(msg.bytes[7], 2);
    try std.testing.expectEqual(msg.bytes[8], 3);
    try std.testing.expectEqual(msg.bytes[9], 4);
    try std.testing.expectEqual(msg.bytes[10], 5);
    try std.testing.expectEqual(msg.bytes[11], 6);
}

test "Buffer.replaceAssumeBounds good" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);
    msg.replaceAssumeBounds(1, 10);

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 10);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.replaceIntAssumeBounds good" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 574393472, std.builtin.Endian.little);
    msg.replaceIntAssumeBounds(i32, 0, 196608, std.builtin.Endian.little);

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.replaceSliceAssumeBounds good" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    const rep = [_]u8{ 1, 2, 3, 4 };
    msg.replaceSliceAssumeBounds(0, &rep);

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 1);
    try std.testing.expectEqual(msg.bytes[1], 2);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 4);
}

test "Buffer.replace good" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    msg.replace(1, 5) catch {
        try std.testing.expectEqual(true, false);
    };

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 5);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.replace oob" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    msg.replace(5, 5) catch |err| {
        try std.testing.expectEqual(BufferError.OutOfBounds, err);
    };

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.replaceInt good" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 574393472, std.builtin.Endian.little);
    msg.replaceInt(i32, 0, 196608, std.builtin.Endian.little) catch {
        try std.testing.expectEqualStrings("Expected No Error", "But got one");
    };

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}

test "Buffer.replaceInt oob" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 574393472, std.builtin.Endian.little);
    msg.replaceInt(i32, 1, 196608, std.builtin.Endian.little) catch |err| {
        try std.testing.expectEqual(BufferError.OutOfBounds, err);
    };

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 128);
    try std.testing.expectEqual(msg.bytes[1], 140);
    try std.testing.expectEqual(msg.bytes[2], 60);
    try std.testing.expectEqual(msg.bytes[3], 34);
}

test "Buffer.replaceSlice good" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    const rep = [_]u8{ 1, 2, 3, 4 };
    msg.replaceSlice(0, &rep) catch {
        try std.testing.expectEqualStrings("Expected No Error", "But got one");
    };

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 1);
    try std.testing.expectEqual(msg.bytes[1], 2);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 4);
}

test "Buffer.replaceSlice oob" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 10);
    defer msg.deinit();

    try msg.appendInt(i32, 196608, std.builtin.Endian.little);

    const rep = [_]u8{ 1, 2, 3, 4 };
    msg.replaceSlice(1, &rep) catch |err| {
        try std.testing.expectEqual(BufferError.OutOfBounds, err);
    };

    try std.testing.expectEqual(msg.bytes.len, 4);
    try std.testing.expectEqual(msg.capacity, 10);
    try std.testing.expectEqual(msg.bytes[0], 0);
    try std.testing.expectEqual(msg.bytes[1], 0);
    try std.testing.expectEqual(msg.bytes[2], 3);
    try std.testing.expectEqual(msg.bytes[3], 0);
}
