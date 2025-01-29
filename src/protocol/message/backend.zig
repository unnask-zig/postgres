const std = @import("std");
const Allocator = std.mem.Allocator;
const Buffer = @import("../../buffer/Buffer.zig");
const Reader = @import("../../buffer/Reader.zig");

// const FixedBuffer = std.io.FixedBufferStream([]const u8);
// FixedBuffer.Reader is the type of the reader.

const AuthMD5Password = struct {
    salt: [4]u8 = undefined,
};

const AuthSASL = struct {
    sasl_sha_256: bool = false,
    sasl_sha_256_plus: bool = false,
    reader: Reader,

    fn deserialize(reader: []const u8) !void {
        //const reader = std.io.fixedBufferStream(reader).reader();

        //todo: I have run in to "needing" a non-standard reader. Guess I
        //will make a ByteBuffer, Reader and Writer

        _ = reader;
    }
};

const KeyData = struct {
    process: i32,
    secret: i32,
};

const CommandComplete = struct {
    reader: Reader,
};

const CopyData = struct {
    reader: Reader,
};

const CopyResponse = struct {
    reader: Reader,
};

const DataRow = struct {
    reader: Reader,
};

const ErrorResponse = struct {
    reader: Reader,
};

const FunctionCallResponse = struct {
    reader: Reader,
};

const NegotiateProtocolVersion = struct {
    reader: Reader,
};

const NoticeResponse = struct {
    reader: Reader,
};

const NotificationResponse = struct {
    reader: Reader,
};

const ParameterDescription = struct {
    reader: Reader,
};

const ParameterStatus = struct {
    reader: Reader,
};

const ReadyForQuery = struct {
    status: u8,
};

const RowDescription = struct {
    reader: Reader,
};

const BackendMessage = union(enum) {
    auth_ok,
    auth_cleartext_pass,
    //authKerberosV5,
    auth_md5_pass: AuthMD5Password,
    //authSCMCredential
    //authGSS
    //authGSSContinue
    //authSSPI
    auth_sasl: AuthSASL,
    //authSASLContinue
    //authSASLFinal
    key_data: KeyData,
    bind_complete,
    close_complete,
    command_complete: CommandComplete,
    copy_data: CopyData,
    copy_done,
    copy_in_response: CopyResponse,
    copy_out_response: CopyResponse,
    copy_both_response: CopyResponse,
    data_row: DataRow,
    empty_query_response,
    error_response: ErrorResponse,
    function_call_response: FunctionCallResponse,
    negotiate_protocol_version: NegotiateProtocolVersion,
    no_data,
    notice_response: NoticeResponse,
    notification_response: NotificationResponse,
    parameter_description: ParameterDescription,
    parameter_status: ParameterStatus,
    parse_complete,
    portal_suspended,
    ready_for_query: ReadyForQuery,
    row_description: RowDescription,
    unsupported,
};

//
//authKerberosV5
//authSCMCredential
//authGSS
//authGSSContinue
//authSSPI
//authSASL
//authSASLContinue
//authSASLFinal
inline fn deserializeAuth(reader: *Reader) !BackendMessage {
    // The spec details that this is actually an int32, however, the max
    // value is 12, so no need to do this extra work for the moment.
    const msgType = reader.readInt(i32);
    return switch (msgType) {
        0 => .auth_ok,
        2 => .unsupported, //kerberos
        3 => .auth_cleartext_pass,
        5 => {
            var tmp = AuthMD5Password{};
            reader.readIntoSlice(&tmp.salt);
            return BackendMessage{ .auth_md5_pass = tmp };
        },
        6 => .unsupported, //authSCMCredential
        7 => .unsupported, //authGSS
        8 => .unsupported, //authGSSContinue
        9 => .unsupported, //authSSPI
        10 => {
            return .{ .auth_sasl = .{ .reader = reader.* } };
        },
        11 => .unsupported, //authSASLContinue
        12 => .unsupported, //authSASLFinal
        else => .unsupported,
    };
}

pub const PostgresDeserializeError = error{ MsgLength, BufferLength };

pub fn deserialize(message: *Buffer) !BackendMessage {
    if (message.bytes.len < 5) {
        return PostgresDeserializeError.MsgLength;
    }

    var msg_reader = message.reader();
    const msg_type = msg_reader.readByte();

    // I think it will be better to direct read the buffer here, then in the
    // reader reads, use a fixed buffer there.
    const msg_len: usize = @intCast(msg_reader.readInt(i32) + 1);
    if (msg_len > message.bytes.len) {
        return PostgresDeserializeError.BufferLength;
    }

    return switch (msg_type) {
        'R' => return try deserializeAuth(&msg_reader),
        'K' => {
            return BackendMessage{ .key_data = .{
                .process = msg_reader.readInt(i32),
                .secret = msg_reader.readInt(i32),
            } };
        },
        '2' => .bind_complete,
        '3' => .close_complete,
        'C' => {
            return .{ .command_complete = .{ .reader = msg_reader } };
        },
        'd' => {
            return BackendMessage{ .copy_data = .{ .reader = msg_reader } };
        },
        'c' => .copy_done,
        'G' => {
            return BackendMessage{ .copy_in_response = .{ .reader = msg_reader } };
        },
        'H' => {
            return BackendMessage{ .copy_out_response = .{ .reader = msg_reader } };
        },
        'W' => {
            return BackendMessage{ .copy_both_response = .{ .reader = msg_reader } };
        },
        'D' => {
            return BackendMessage{ .data_row = .{ .reader = msg_reader } };
        },
        'I' => .empty_query_response,
        'E' => {
            return BackendMessage{ .error_response = .{ .reader = msg_reader } };
        },
        'V' => {
            return BackendMessage{ .function_call_response = .{ .reader = msg_reader } };
        },
        'v' => {
            return BackendMessage{ .negotiate_protocol_version = .{ .reader = msg_reader } };
        },
        'n' => .no_data,
        'N' => {
            return BackendMessage{ .notice_response = .{ .reader = msg_reader } };
        },
        'A' => {
            return BackendMessage{ .notification_response = .{ .reader = msg_reader } };
        },
        't' => {
            return BackendMessage{ .parameter_description = .{ .reader = msg_reader } };
        },
        'S' => {
            return BackendMessage{ .parameter_status = .{ .reader = msg_reader } };
        },
        'p' => .parse_complete,
        's' => .portal_suspended,
        'Z' => {
            return BackendMessage{ .ready_for_query = .{
                .status = msg_reader.readByte(),
            } };
        },
        'T' => {
            return BackendMessage{ .row_description = .{ .reader = msg_reader } };
        },
        else => .unsupported,
    };
}

fn bufferFromSlice(allocator: Allocator, msg: []const u8) !Buffer {
    var buf = Buffer.init(allocator);
    try buf.appendSlice(msg);
    return buf;
}

test "BackendMessage.auth_ok good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 8, 0, 0, 0, 0 };
    var buf = try bufferFromSlice(std.testing.allocator, &msg);
    defer buf.deinit();

    const des = try deserialize(&buf);

    try std.testing.expectEqual(des, BackendMessage.auth_ok);
}

test "BackendMessage.auth_cleartext_pass good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 8, 0, 0, 0, 3 };
    var buf = try bufferFromSlice(std.testing.allocator, &msg);
    defer buf.deinit();

    const des = try deserialize(&buf);

    try std.testing.expectEqual(des, BackendMessage.auth_cleartext_pass);
}

test "BackendMessage.auth_md5_pass good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 12, 0, 0, 0, 5, 1, 2, 3, 4 };
    var buf = try bufferFromSlice(std.testing.allocator, &msg);
    defer buf.deinit();

    const des = try deserialize(&buf);

    var tmp = AuthMD5Password{};
    tmp.salt = [4]u8{ 1, 2, 3, 4 };

    try std.testing.expectEqual(des, BackendMessage{ .auth_md5_pass = tmp });
}

//test "BackendMessage.auth_sasl good message" {
//    const msg = [_]u8{ 'R', 0, 0, 0, 23, 0, 0, 0, 10, 's', 'c', 'r', 'a', 'm', '-', 's', 'h', 'a', '-', '2', '5', '6', 0, 0 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.auth_sasl.reader);
//    const tmp = AuthSASL{
//        .reader = &[_]u8{ 's', 'c', 'r', 'a', 'm', '-', 's', 'h', 'a', '-', '2', '5', '6', 0, 0 },
//    };
//
//    switch (des) {
//        .auth_sasl => |obj| try std.testing.expect(std.mem.eql(u8, obj.reader, tmp.reader)),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.key_data good message" {
//    const msg = [_]u8{ 'K', 0, 0, 0, 12, 0, 0, 1, 1, 0, 0, 1, 2 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    const tmp = KeyData{
//        .process = 257,
//        .secret = 258,
//    };
//
//    try std.testing.expectEqual(des, BackendMessage{ .key_data = tmp });
//}
//
//test "BackendMessage.bind_complete good message" {
//    const msg = [_]u8{ '2', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.bind_complete);
//}
//
//test "BackendMessage.close_complete good message" {
//    const msg = [_]u8{ '3', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.close_complete);
//}
//
//test "BackendMessage.command_complete good message" {
//    const msg = [_]u8{ 'C', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.command_complete.tag);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.command_complete);
//    switch (des) {
//        .command_complete => |cc| try std.testing.expect(std.mem.eql(u8, cc.tag, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.copy_data good message" {
//    const msg = [_]u8{ 'd', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.copy_data.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.copy_data);
//    switch (des) {
//        .copy_data => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.copy_done good message" {
//    const msg = [_]u8{ 'c', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.copy_done);
//}
//
//test "BackendMessage.copy_in_response good message" {
//    const msg = [_]u8{ 'G', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.copy_in_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.copy_in_response);
//    switch (des) {
//        .copy_in_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.copy_out_response good message" {
//    const msg = [_]u8{ 'H', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.copy_out_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.copy_out_response);
//    switch (des) {
//        .copy_out_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.copy_both_response good message" {
//    const msg = [_]u8{ 'W', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.copy_both_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.copy_both_response);
//    switch (des) {
//        .copy_both_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.data_row good message" {
//    const msg = [_]u8{ 'D', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.data_row.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.data_row);
//    switch (des) {
//        .data_row => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.empty_query_response good message" {
//    const msg = [_]u8{ 'I', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.empty_query_response);
//}
//
//test "BackendMessage.error_response good message" {
//    const msg = [_]u8{ 'E', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.error_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.error_response);
//    switch (des) {
//        .error_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.function_call_response good message" {
//    const msg = [_]u8{ 'V', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.function_call_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.function_call_response);
//    switch (des) {
//        .function_call_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.negotiate_protocol_version good message" {
//    const msg = [_]u8{ 'v', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.negotiate_protocol_version.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.negotiate_protocol_version);
//    switch (des) {
//        .negotiate_protocol_version => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.no_data good message" {
//    const msg = [_]u8{ 'n', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.no_data);
//}
//
//test "BackendMessage.notice_response good message" {
//    const msg = [_]u8{ 'N', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.notice_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.notice_response);
//    switch (des) {
//        .notice_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.notification_response good message" {
//    const msg = [_]u8{ 'A', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.notification_response.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.notification_response);
//    switch (des) {
//        .notification_response => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.parameter_description good message" {
//    const msg = [_]u8{ 't', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.parameter_description.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.parameter_description);
//    switch (des) {
//        .parameter_description => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.parameter_status good message" {
//    const msg = [_]u8{ 'S', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.parameter_status.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.parameter_status);
//    switch (des) {
//        .parameter_status => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
//
//test "BackendMessage.parse_complete good message" {
//    const msg = [_]u8{ 'p', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.parse_complete);
//}
//
//test "BackendMessage.portal_suspended good message" {
//    const msg = [_]u8{ 's', 0, 0, 0, 4 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//
//    try std.testing.expectEqual(des, BackendMessage.portal_suspended);
//}
//
//test "BackendMessage.ready_for_query good message" {
//    const msg = [_]u8{ 'Z', 0, 0, 0, 5, 0 };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    const tmp = ReadyForQuery{
//        .status = 0,
//    };
//
//    try std.testing.expectEqual(des, BackendMessage{ .ready_for_query = tmp });
//}
//
//test "BackendMessage.row_description good message" {
//    const msg = [_]u8{ 'T', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };
//
//    const des = try deserialize(std.testing.allocator, &msg);
//    defer std.testing.allocator.free(des.row_description.reader);
//
//    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.row_description);
//    switch (des) {
//        .row_description => |cc| try std.testing.expect(std.mem.eql(u8, cc.reader, "insert")),
//        else => try std.testing.expect(1 == 2),
//    }
//}
