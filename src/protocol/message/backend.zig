const std = @import("std");
const Allocator = std.mem.Allocator;

const FixedBuffer = std.io.FixedBufferStream([]const u8);
// FixedBuffer.Reader is the type of the reader.

const AuthMD5Password = struct {
    salt: [4]u8 = undefined,
};

const KeyData = struct {
    process: i32,
    secret: i32,
};

const CommandComplete = struct {
    tag: []const u8,
};

const CopyData = struct {
    storage: []const u8,
};

const BackendMessage = union(enum) {
    authOk,
    authCleartextPass,
    //authKerberosV5,
    authMD5Pass: AuthMD5Password,
    //authSCMCred,
    //authGSS,
    //authGSSContinue,
    keyData: KeyData,
    bindComplete,
    closeComplete,
    commandComplete: CommandComplete,
    copyData: CopyData,
    copyDone,
    unsupported,
};

//authKerberosV5
//authSCMCredential
//authGSS
//authGSSContinue
//authSSPI
//authSASL
//authSASLContinue
//authSASLFinal
inline fn deserializeAuth(message: []const u8) BackendMessage {
    // The spec details that this is actually an int32, however, the max
    // value is 12, so no need to do this extra work for the moment.
    const msgType = message[8];
    return switch (msgType) {
        0 => .authOk,
        2 => .unsupported, //kerberos
        3 => .authCleartextPass,
        5 => {
            var tmp = AuthMD5Password{};
            @memcpy(&tmp.salt, message[9..13]);
            return BackendMessage{ .authMD5Pass = tmp };
        },
        6 => .unsupported, //authSCMCredential
        7 => .unsupported, //authGSS
        8 => .unsupported, //authGSSContinue
        9 => .unsupported, //authSSPI
        10 => .unsupported, //authSASL
        11 => .unsupported, //authSASLContinue
        12 => .unsupported, //authSASLFinal
        else => .unsupported,
    };
}

pub const PostgresDeserializeError = error{ MsgLength, BufferLength };

inline fn bigToType(comptime T: type, bytes: []const u8) T {
    return std.mem.bigToNative(i32, std.mem.bytesAsValue(i32, bytes[0..@sizeOf(T)]).*);
}

pub fn deserialize(allocator: Allocator, message: []const u8) !BackendMessage {
    if (message.len < 5) {
        return PostgresDeserializeError.MsgLength;
    }

    // Wondering if this is actually the way to go. Fixed buffer almost
    // definitely adds overhead, but it is also easier to manage.
    //var fbs = FixedBuffer{
    //    .buffer = message,
    //    .pos = 1,
    //};
    //var reader = fbs.reader();
    //const msgLen = try reader.readIntBig(i32);

    //if (msgLen > message.len) {
    //    return PostgresDeserializeError.BufferLength;
    //}

    // I think it will be better to direct read the buffer here, then in the
    // storage reads, use a fixed buffer there.
    const msgLen = bigToType(i32, message[1..5]) + 1;
    if (msgLen > message.len) {
        return PostgresDeserializeError.BufferLength;
    }

    return switch (message[0]) {
        'R' => return deserializeAuth(message),
        'K' => {
            return BackendMessage{ .keyData = .{
                .process = bigToType(i32, message[5..9]),
                .secret = bigToType(i32, message[9..13]),
            } };
        },
        '2' => .bindComplete,
        '3' => .closeComplete,
        'C' => {
            const tag = try allocator.alloc(u8, @intCast(msgLen - 5));
            @memcpy(tag, message[5..]);
            return BackendMessage{ .commandComplete = .{ .tag = tag } };
        },
        'd' => {
            const storage = try allocator.alloc(u8, @intCast(msgLen - 5));
            @memcpy(storage, message[5..]);
            return BackendMessage{ .copyData = .{ .storage = storage } };
        },
        'c' => .copyDone,
        else => .unsupported,
    };
}

//commandComplete
//copyData
//copyDone
//copyInResponse
//copyOutResponse
//copyBothResponse
//dataRow
//emptyQueryResponse
//errorResponse
//functionCallResponse
//negotiateProtocolVersion
//noData
//noticeResponse
//notificationResponse
//parameterDescription
//parameterStatus
//parseComplete
//portalSuspended
//readyForQuery
//rowDescription

test "BackendMessage.authOK good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 8, 0, 0, 0, 0 };

    const des = try deserialize(std.testing.allocator, &msg);

    try std.testing.expectEqual(des, BackendMessage.authOk);
}

test "BackendMessage.authCleartextPass good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 8, 0, 0, 0, 3 };

    const des = try deserialize(std.testing.allocator, &msg);

    try std.testing.expectEqual(des, BackendMessage.authCleartextPass);
}

test "BackendMessage.authMD5Pass good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 12, 0, 0, 0, 5, 1, 2, 3, 4 };

    const des = try deserialize(std.testing.allocator, &msg);
    var tmp = AuthMD5Password{};
    tmp.salt = [4]u8{ 1, 2, 3, 4 };

    try std.testing.expectEqual(des, BackendMessage{ .authMD5Pass = tmp });
}

test "BackendMessage.keyData good message" {
    const msg = [_]u8{ 'K', 0, 0, 0, 12, 0, 0, 1, 1, 0, 0, 1, 2 };

    const des = try deserialize(std.testing.allocator, &msg);
    const tmp = KeyData{
        .process = 257,
        .secret = 258,
    };

    try std.testing.expectEqual(des, BackendMessage{ .keyData = tmp });
}

test "BackendMessage.bindComplete good message" {
    const msg = [_]u8{ '2', 0, 0, 0, 4 };

    const des = try deserialize(std.testing.allocator, &msg);

    try std.testing.expectEqual(des, BackendMessage.bindComplete);
}

test "BackendMessage.closeComplete good message" {
    const msg = [_]u8{ '3', 0, 0, 0, 4 };

    const des = try deserialize(std.testing.allocator, &msg);

    try std.testing.expectEqual(des, BackendMessage.closeComplete);
}

test "BackendMessage.commandComplete good message" {
    const msg = [_]u8{ 'C', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };

    const des = try deserialize(std.testing.allocator, &msg);
    defer std.testing.allocator.free(des.commandComplete.tag);

    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.commandComplete);
    switch (des) {
        .commandComplete => |cc| try std.testing.expect(std.mem.eql(u8, cc.tag, "insert")),
        else => try std.testing.expect(1 == 2),
    }
}

test "BackendMessage.copyData good message" {
    const msg = [_]u8{ 'd', 0, 0, 0, 10, 'i', 'n', 's', 'e', 'r', 't' };

    const des = try deserialize(std.testing.allocator, &msg);
    defer std.testing.allocator.free(des.copyData.storage);

    try std.testing.expect(@as(BackendMessage, des) == BackendMessage.copyData);
    switch (des) {
        .copyData => |cc| try std.testing.expect(std.mem.eql(u8, cc.storage, "insert")),
        else => try std.testing.expect(1 == 2),
    }
}

test "BackendMessage.copyDone good message" {
    const msg = [_]u8{ 'c', 0, 0, 0, 4 };

    const des = try deserialize(std.testing.allocator, &msg);

    try std.testing.expectEqual(des, BackendMessage.copyDone);
}
