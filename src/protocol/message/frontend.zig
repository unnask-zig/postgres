//https://www.postgresql.org/docs/15/protocol-message-formats.html
// All the messages above marked with a (F).

//In general, the messages here probably won't be built over time, so providing
//just a function for each message seems to be the easiest approach.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Buffer = @import("../../Buffer.zig").Buffer;

//const Buffer = std.ArrayList(u8);

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
    const cpos: i32 = @intCast(pos);

    std.mem.writeInt(i32, buffer.items[pos..][0..4], size - cpos, std.builtin.Endian.big);
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
pub fn gssResponse(buffer: *Buffer, message_data: []const u8) !void {
    var writer = buffer.writer();

    try writer.writeByte('p');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(message_data);

    writeSize(buffer, 1);
}

//parse
pub fn parse(buffer: *Buffer, destination: [:0]const u8, query_str: [:0]const u8, object_ids: []const i32) !void {
    var writer = buffer.writer();

    try writer.writeByte('P');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(destination);
    try writer.writeAll(query_str);
    try writer.writeInt(i16, @intCast(object_ids.len), std.builtin.Endian.big);

    for (object_ids) |object_id| {
        try writer.writeInt(i32, object_id, std.builtin.Endian.big);
    }

    writeSize(buffer, 1);
}

//passwordMessage
pub fn password(buffer: *Buffer, passwd: [:0]const u8) !void {
    var writer = buffer.writer();

    try writer.writeByte('p');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(passwd);

    writeSize(buffer, 1);
}

//query
pub fn query(buffer: *Buffer, query_str: [:0]const u8) !void {
    var writer = buffer.writer();

    try writer.writeByte('Q');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(query_str);

    writeSize(buffer, 1);
}

//saslInitialResponse
pub fn saslInitialResponse(buffer: *Buffer, name: [:0]const u8, response: ?[]const u8) !void {
    var writer = buffer.writer();

    try writer.writeByte('p');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(name);

    if (response) |resp| {
        try writer.writeInt(i32, resp.len, std.builtin.Endian.big);
        try writer.writeAll(resp);
    } else {
        try writer.writeInt(i32, -1, std.builtin.Endian.big);
    }

    writeSize(buffer, 1);
}

//saslResponse
pub fn saslResponse(buffer: *Buffer, data: []const u8) !void {
    var writer = buffer.writer();

    try writer.writeByte('p');
    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeAll(data);

    writeSize(buffer, 1);
}

//sslRequest
pub fn sslRequest(buffer: *Buffer) !void {
    var writer = buffer.writer();
    const request_code: i32 = 80877103;

    try writer.writeInt(i32, 8, std.builtin.Endian.big);
    try writer.writeInt(i32, request_code, std.builtin.Endian.big);
}

//startupMessage
pub fn startupMessage(buffer: *Buffer, user: []const u8, database: ?[]const u8, options: ?[]const u8, replication: ?[]const u8) !void {
    const version: i32 = 196608;

    try buffer.resize(0);
    var writer = buffer.writer();

    try writer.writeInt(i32, 0, std.builtin.Endian.big);
    try writer.writeInt(i32, version, std.builtin.Endian.big);
    try writer.writeAll("user");
    try writer.writeByte(0);
    try writer.writeAll(user);
    try writer.writeByte(0);
    if (database) |db| {
        try writer.writeAll("database");
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
        try writer.writeAll("replication");
        try writer.writeByte(0);
        try writer.writeAll(rep);
        try writer.writeByte(0);
    }

    try writer.writeByte(0);
    writeSize(buffer, 0);
}

//sync
pub fn sync(buffer: *Buffer) !void {
    var writer = buffer.writer();

    writer.writeByte('S');
    writer.writeInt(i32, 4, std.builtin.Endian.big);
}

//terminate
pub fn terminate(buffer: *Buffer) !void {
    var writer = buffer.writer();

    writer.writeByte('X');
    writer.writeInt(i32, 4, std.builtin.Endian.big);
}

test "startupMessage only user" {
    var buf = Buffer.init(std.testing.allocator);
    defer buf.deinit();

    const msg = try startupMessage(&buf, "test", null, null, null);

    const compare = [_]u8{ 0, 0, 0, 19, 0, 0, 3, 0, 'u', 's', 'e', 'r', 0, 't', 'e', 's', 't', 0 };

    _ = msg;
    _ = compare;
}
