const std = @import("std");
const Allocator = std.mem.Allocator;

// a couple of linked lists maintaining some buffers for use

const Buffer = std.ArrayList(u8);
const Queue = std.DoublyLinkedList(Buffer);
const BufferPool = @This();

used: *Queue,
free: *Queue,

pub fn init(self: BufferPool, allocator: Allocator) void {
    self.used = allocator.Create(Queue);
    self.free = allocator.Create(Queue);
}
