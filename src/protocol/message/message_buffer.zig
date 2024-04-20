const std = @import("std");

//Guess this isn't going to work so well due to needing length after writing.
//I mean, technically, just calcualate the length ahead of time, then write,
//but that seems annoying
pub const MessageBuffer = std.ArrayList(u8);
pub const MessageBufferWriter = MessageBuffer.Writer;

// Going to just write a separate repo that implements the generic
// reader and writer for a byte stream
