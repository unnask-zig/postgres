const std = @import("std");
const Allocator = std.mem.Allocator;

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

//todo rewrite to use position and len for writing.
//
//
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

pub fn appendByte(self: *Self, byte: u8) Allocator.Error!void {
    const new_len = self.bytes.len + @sizeOf(byte);
    try self.checkCapacity(new_len);
}

pub fn appendSlice(self: *Self, bytes: []const u8) Allocator.Error!void {
    const new_len = self.bytes.len + bytes.len;
    try self.checkCapacity(new_len);

    const slice = self.allocatedSlice()[self.bytes.len..];
    @memcpy(slice[0..bytes.len], bytes);
}

test "message.initCapacity" {
    var msg: Self = try Self.initCapacity(std.testing.allocator, 50);

    try std.testing.expect(msg.bytes.len == 0);
    try std.testing.expect(msg.capacity == 50);

    msg.deinit();
}
