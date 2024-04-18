const std = @import("std");

pub const MessageBuffer = std.ArrayList(u8);
pub const MessageBufferWriter = MessageBuffer.Writer;
