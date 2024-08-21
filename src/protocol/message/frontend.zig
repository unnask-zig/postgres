//https://www.postgresql.org/docs/15/protocol-message-formats.html
// All the messages above marked with a (F).

//In general, the messages here probably won't be built over time, so providing
//just a function for each message seems to be the easiest approach.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Buffer = std.ArrayList(u8);

inline fn writeSize(buffer: *Buffer, pos: usize) void {
    //const count = @divExact(@typeInfo(T).Int.bits, 8);
    //const end = self.pos + count;
    //try self.checkCapacity(end);

    //todo: Note that postgres messages can only be i32 big.
    //maybe ArrayList isn't the approach to take
    const size: i32 = @intCast(buffer.items.len);

    std.mem.writeInt(i32, &buffer.items[pos..][0..4], size, std.builtin.Endian.big);
}

inline fn writeStr(writer: Buffer.Writer, str: []u8) !void {
    try writer.writeAll(str);
    try writer.writeByte(0);
}

//bind(F) message.
pub fn bind(buffer: Buffer, portal: u8, stmt: []u8, formats: []i16, values: [][]u8, result_formats: []i16) !void {
    buffer.resize(0);

    var writer = buffer.writer();
    try writer.writeByte('B');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);

    try writeStr(portal);
    try writeStr(stmt);

    writer.writeInt(i16, @intCast(formats.len), std.builtin.Endian.big);
    for (formats) |format| {
        writer.writeInt(i16, format, std.builtin.Endian.big);
    }

    writer.writeInt(i16, @intCast(values.len), std.builtin.Endian.big);
    for (values) |value| {
        writer.writeInt(i32, @intCast(value.len), std.builtin.Endian.big);
        writer.writeAll(value);
    }

    writer.writeInt(i16, @intCast(result_formats.len), std.builtin.Endian.big);
    for (result_formats) |result_format| {
        writer.writeInt(i16, result_format, std.builtin.Endian.big);
    }
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
pub fn startupMessage(buffer: Buffer, user: []const u8, database: ?[]const u8, options: ?[]const u8, replication: ?[]const u8) !void {
    const version: i32 = 196608;

    buffer.resize(0);
    var writer = buffer.writer();

    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeInt(i32, version, std.builtin.Endian.big);
    try writer.writeAll("user");
    try writer.writeByte(0);
    try writer.writeAll(user);
    try writer.writeByte(0);
    if (database) |db| {
        try writer.writeAll("user");
        try writer.writeByte(0);
        try writer.writeAll(db);
        try writer.writeByte(0);
    }
    if (options) |opts| {
        try writer.writeAll("options");
        try writer.writeByte(0);
        try writer.writeAll(opts);
        try writer.writeByte(0);
    }
    if (replication) |rep| {
        try writer.writeAll("repication");
        try writer.writeByte(0);
        try writer.writeAll(rep);
        try writer.writeByte(0);
    }

    try writer.writeByte(0);
    writeSize(buffer, 0);
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
