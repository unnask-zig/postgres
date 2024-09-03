//https://www.postgresql.org/docs/15/protocol-message-formats.html
// All the messages above marked with a (F).

//In general, the messages here probably won't be built over time, so providing
//just a function for each message seems to be the easiest approach.

const std = @import("std");
const Allocator = std.mem.Allocator;

const Buffer = std.ArrayList(u8);

const Formats = enum(i16) {
    text = 0,
    binary = 1,
};

inline fn writeSize(buffer: *Buffer, pos: usize) void {
    //const count = @divExact(@typeInfo(T).Int.bits, 8);
    //const end = self.pos + count;
    //try self.checkCapacity(end);

    //todo: Note that postgres messages can only be i32 big.
    //maybe ArrayList isn't the approach to take
    const size: i32 = @intCast(buffer.items.len);

    std.mem.writeInt(i32, &buffer.items[pos..][0..4], size - pos, std.builtin.Endian.big);
}

inline fn writeStr(writer: *Buffer.Writer, str: []u8) !void {
    try writer.writeAll(str);
    try writer.writeByte(0);
}

//bind(F) message.
pub fn bind(buffer: *Buffer, portal: [:0]const u8, stmt: [:0]const u8, formats: []const Formats, values: []const []const u8, result_formats: []const Formats) !void {
    var writer = buffer.writer();
    try writer.writeByte('B');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);

    try writeStr(portal);
    try writeStr(stmt);

    try writer.writeInt(i16, @intCast(formats.len), std.builtin.Endian.big);
    for (formats) |format| {
        try writer.writeInt(i16, format, std.builtin.Endian.big);
    }

    try writer.writeInt(i16, @intCast(values.len), std.builtin.Endian.big);
    for (values) |value| {
        try writer.writeInt(i32, @intCast(value.len), std.builtin.Endian.big);
        try writer.writeAll(value);
    }

    try writer.writeInt(i16, @intCast(result_formats.len), std.builtin.Endian.big);
    for (result_formats) |result_format| {
        try writer.writeInt(i16, result_format, std.builtin.Endian.big);
    }

    writeSize(buffer, 1);
}

pub fn cancelRequest(buffer: *Buffer, process_id: i32, secret: i32) !void {
    const cancel_code: i32 = 80877102;

    var writer = buffer.writer();
    try writer.writeInt(i32, 16, std.builtin.Endian.big);
    try writer.writeInt(i32, cancel_code, std.builtin.Endian.big);
    try writer.writeInt(i32, process_id, std.builtin.Endian.big);
    try writer.writeInt(i32, secret, std.builtin.Endian.big);

    writeSize(buffer, 0);
}

const StatementType = enum {
    portal,
    prepared_statement,
};
pub fn close(buffer: *Buffer, comptime close_type: StatementType, name: [:0]const u8) !void {
    var writer = buffer.writer();

    try writer.writeByte('C');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    switch (close_type) {
        StatementType.portal => try writer.writeByte('P'),
        StatementType.prepared_statement => try writer.writeByte('S'),
    }
    try writer.writeAll(name);
    writeSize(buffer, 1);
}

//copyData
pub fn copyData(buffer: *Buffer, bytes: []const u8) !void {
    var writer = buffer.writer();

    //todo: naive implementation. may needs fixing. might make more sense to
    //      fix in whatever calls this function
    const size: i32 = @intCast(bytes.len + 4);

    try writer.writeByte('d');
    try writer.writeInt(i32, size, std.builtin.Endian.big);
    try writer.writeAll(bytes);
}

//copyDone
pub fn copyDone(buffer: *Buffer) !void {
    var writer = buffer.writer();
    try writer.writeByte('c');
    try writer.writeByte(4);
}

//copyFail
pub fn copyFail(buffer: *Buffer, msg: [:0]const u8) !void {
    var writer = buffer.writer();
    try writer.writeByte('f');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(msg);
    writeSize(buffer, 1);
}

//describe
pub fn describe(buffer: *Buffer, comptime describe_type: StatementType, name: [:0]const u8) !void {
    var writer = buffer.writer();
    try writer.writeByte('D');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    switch (describe_type) {
        StatementType.portal => try writer.writeByte('P'),
        StatementType.prepared_statement => try writer.writeByte('S'),
    }
    try writer.writeAll(name);
    writeSize(buffer, 1);
}

//execute
pub fn execute(buffer: *Buffer, portal: [:0]const u8, max_rows: i32) !void {
    var writer = buffer.writer();

    try writer.writeByte('E');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(portal);
    try writer.writeInt(i32, max_rows, std.builtin.Endian.big);
    writeSize(buffer, 1);
}

//flush
pub fn flush(buffer: *Buffer) !void {
    var writer = buffer.writer();

    writer.writeByte('H');
    writer.writeInt(i32, 4, std.builtin.Endian.big);
}

//functionCall
pub fn functionCall(buffer: *Buffer, object_id: i32, formats: []const Formats, values: []const []const u8, result_format: Formats) !void {
    var writer = buffer.writer();
    try writer.writeByte('F');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);

    try writer.writeInt(i32, object_id, std.builtin.Endian.big);

    try writer.writeInt(i16, @intCast(formats.len), std.builtin.Endian.big);
    for (formats) |format| {
        try writer.writeInt(i16, format, std.builtin.Endian.big);
    }

    try writer.writeInt(i16, @intCast(values.len), std.builtin.Endian.big);
    for (values) |value| {
        //todo: bug here for "NULL"
        //      a length of -1 represents NULL
        try writer.writeInt(i32, @intCast(value.len), std.builtin.Endian.big);
        try writer.writeAll(value);
    }

    try writer.writeInt(i16, result_format, std.builtin.Endian.big);
    writeSize(buffer, 1);
}

//gssencRequest
pub fn gssEncryptionRequest(buffer: *Buffer) !void {
    const gssenc_code: i32 = 80877104;

    var writer = buffer.writer();
    try writer.writeInt(i32, 8, std.builtin.Endian.big);
    try writer.writeInt(i32, gssenc_code, std.builtin.Endian.big);
}

//gssResponse

//parse

//passwordMessage

//query

//saslInitialResponse

//saslResponse

//sslRequest

//startupMessage
pub fn startupMessage(buffer: *Buffer, user: [:0]const u8, database: ?[:0]const u8, options: ?[:0]const u8, replication: ?[:0]const u8) !void {
    const version: i32 = 196608;

    buffer.resize(0);
    var writer = buffer.writer();

    const user_text: [:0]const u8 = "user";
    const database_text: [:0]const u8 = "database";
    const options_text: [:0]const u8 = "options";
    const replication_text: [:0]const u8 = "replication";

    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeInt(i32, version, std.builtin.Endian.big);
    try writer.writeAll(user_text);
    try writer.writeAll(user);
    if (database) |db| {
        try writer.writeAll(database_text);
        try writer.writeAll(db);
    }
    if (options) |opts| {
        try writer.writeAll(options_text);
        try writer.writeAll(opts);
    }
    if (replication) |rep| {
        try writer.writeAll(replication_text);
        try writer.writeAll(rep);
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
