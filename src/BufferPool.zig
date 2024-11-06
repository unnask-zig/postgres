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

pub fn addUsed(self: *BufferPool, buffer: *Buffer) void {
    self.used.append(buffer);
}

//pub fn acquireBuffer() --do what needs be done to move a buffer from unused to used

pub fn acquireBuffer(self: *BufferPool) !Buffer {
    _ = self;
}

//pub fn findBuffer() --find a buffer base on some properties
//pub fn getBuffer() --just grab a buffer off the top of the pool
//pub fn addUsed() -- add a new buffer to the used list
//pub fn release() --release a used buffer back to the free pool
