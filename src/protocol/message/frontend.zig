//https://www.postgresql.org/docs/15/protocol-message-formats.html
// All the messages above marked with a (F).

//In general, the messages here probably won't be built over time, so providing
//just a function for each message seems to be the easiest approach.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = @import("message_buffer.zig").MessageWriter;

//bind(F) message.
//in general, we're just going to tack everythings bytes together, but this
//is annoying still.
//Allocs are "expensive", so we want those minimized.
//Probably best to build another struct that'll be used to build the message up.
//This way, we can build additional functionality to minimize the total number of
//syscalls occurring (for example, by copying the whole message out when the
//message is built, then reusing the byte buffer and never resizing unless necessary)
pub fn bind(writer: Writer, portal: u8, stmt: []u8, formats: []i16, values: []u8, result_formats: []i16) void {
    _ = result_formats;
    _ = values;
    _ = formats;
    _ = stmt;
    _ = portal;
    _ = writer;
}

//cancelRequest
//close
//copyData
//copyDone
//copyFail
//describe
//execute
//flush
//functionCall
//gssencRequest
//gssResponse
//parse
//passwordMessage
//query
//saslInitialResponse
//saslResponse
//sslRequest
//startupMessage
//sync
//terminate
