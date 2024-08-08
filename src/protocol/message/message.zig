const std = @import("std");
const Allocator = std.mem.Allocator;

//todo: I do wonder a little if making this a seekable writer would be "nicer"
//to use
const Message = struct {
    const Self = @This();

    allocator: Allocator,

    capacity: usize,
    pos: usize,
    bytes: []u8,

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

    fn allocatedSlice(self: *Self) []u8 {
        return self.bytes.ptr[0..self.capacity];
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
};
