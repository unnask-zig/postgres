const std = @import("std");
const Allocator = std.mem.Allocator;

//Guess this isn't going to work so well due to needing length after writing.
//I mean, technically, just calcualate the length ahead of time, then write,
//but that seems annoying
//pub const MessageBuffer = std.ArrayList(u8);
//pub const MessageBufferWriter = MessageBuffer.Writer;

// Going to just write a separate repo that implements the generic
// reader and writer for a byte stream
//
// Actually, nah. It doesn't need to be that complex.

const MessageBuffer = struct {
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

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.allocatedSlice());
        self.capacity = 0;
        self.pos = 0;
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

            // Note that we are holding a fat pointer which is made up of
            //      ptr: usize, len: usize
            // and it is "perfectly fine" to modify these variables
            // if one can do so nicely.
            //
            // Modifying ptr here lets us have the capacity be larger
            // than the self.bytes.len, which makes things like traversal,
            // copying, etc, much more idiomatic feeling, and just more
            // ergonomic than having a separate "len" variable.

            const new = try self.allocator.alloc(u8, new_capacity);

            @memcpy(new[0..self.bytes.len], self.bytes);

            self.bytes.ptr = new.ptr;
            self.capacity = new_capacity;
            self.allocator.free(tmp);
        }
    }
};
