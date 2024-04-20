//https://www.postgresql.org/docs/15/protocol-message-formats.html
// All the messages above marked with a (F).

//In general, the messages here probably won't be built over time, so providing
//just a function for each message seems to be the easiest approach.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = @import("message_buffer.zig").MessageBufferWriter;

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
pub fn startupMessage(writer: Writer, user: []const u8, database: ?[]const u8, options: ?[]const u8, replication: ?[]const u8) !void {
    const version: i32 = 196608;

    //I went with an ArrayList type before considering that I'd need to write
    //to a specific spot in the list. Looks like ArrayList + its writer
    //is not going to handle that all that well as it is not seekable.
    //annoying!
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeInt(i32, version, std.builtin.Endian.big);
    try writer.write("user");
    try writer.writeByte(0);
    try writer.write(user);
    try writer.writeByte(0);
    if (database) |db| {
        try writer.write("user");
        try writer.writeByte(0);
        try writer.write(db);
        try writer.writeByte(0);
    }
    if (options) |opts| {
        try writer.write("options");
        try writer.writeByte(0);
        try writer.write(opts);
        try writer.writeByte(0);
    }
    if (replication) |rep| {
        try writer.write("repication");
        try writer.writeByte(0);
        try writer.write(rep);
        try writer.writeByte(0);
    }

    try writer.writeByte(0);
}

//sync
//terminate

const MessageBuffer = @import("message_buffer.zig").MessageBuffer;
test "startupMessage only user" {
    const buf = MessageBuffer.init(std.testing.allocator);

    const msg = startupMessage(buf.writer, "test", null, null, null, null);

    const compare = []u8{ 0, 0, 0, 19, 0, 0, 3, 0, 'u', 's', 'e', 'r', 0, 't', 'e', 's', 't', 0, 0 };

    _ = msg;
    _ = compare;
}
