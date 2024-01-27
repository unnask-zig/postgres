const std = @import("std");

const AuthMD5Password = struct {
    salt: [4]u8 = undefined,
};

const BackendKeyData = struct {
    process: i32,
    secret: i32,
};

const BackendMessage = union(enum) {
    authOk,
    authCleartextPass,
    //authKerberosV5,
    authMD5Pass: AuthMD5Password,
    //authSCMCred,
    //authGSS,
    //authGSSContinue,
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
inline fn deserializeauth(message: []const u8) BackendMessage {
    // The spec details that this is actually an int32, however, the max
    // value is 12, so no need to do this extra work for the moment.
    //const msgType = std.mem.bigToNative(i32, std.mem.bytesAsValue(i32, message[5..9]).*);
    const msgType = message[8];
    switch (msgType) {
        0 => return .authOk,
        2 => return .unsupported, //kerberos
        3 => return .authCleartextPass,
        5 => {
            var tmp = AuthMD5Password{};
            @memcpy(&tmp.salt, message[9..13]);
            return BackendMessage{ .authMD5Pass = tmp };
        },
        6 => return .unsupported, //authSCMCredential
        7 => return .unsupported, //authGSS
        8 => return .unsupported, //authGSSContinue
        9 => return .unsupported, //authSSPI
        10 => return .unsupported, //authSASL
        11 => return .unsupported, //authSASLContinue
        12 => return .unsupported, //authSASLFinal
        else => return .unsupported,
    }
    return .unsupported;
}

pub const PostgresDeserializeError = error{
    InvalidLength,
};

inline fn bigToType(comptime T: type, bytes: []const u8) T {
    return std.mem.bigToNative(i32, std.mem.bytesAsValue(i32, bytes).*);
}

pub fn deserialize(message: []const u8) !BackendMessage {
    //todo - measure
    //  std.mem.bytesAsValue vs std.mem.bytesToValue
    //  (pointer)               (copied)
    //const len = std.mem.bigToNative(i32, std.mem.bytesAsValue(i32, message[1..5]).*);
    const len = bigToType(i32, message[1..5]);

    if (len + 1 != message.len) {
        return PostgresDeserializeError.InvalidLength;
    }

    return switch (message[0]) {
        'R' => deserializeauth(message),
        'K' => .unsupported,
        else => .unsupported,
    };
}

//backendKeyData
//bindComplete
//closeComplete
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

    const des = try deserialize(&msg);

    try std.testing.expectEqual(des, BackendMessage.authOk);
}

test "BackendMessage.authCleartextPass good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 8, 0, 0, 0, 3 };

    const des = try deserialize(&msg);

    try std.testing.expectEqual(des, BackendMessage.authCleartextPass);
}

test "BackendMessage.authMD5Pass good message" {
    const msg = [_]u8{ 'R', 0, 0, 0, 12, 0, 0, 0, 5, 1, 2, 3, 4 };

    const des = try deserialize(&msg);
    var tmp = AuthMD5Password{};
    tmp.salt = [4]u8{ 1, 2, 3, 4 };

    try std.testing.expectEqual(des, BackendMessage{ .authMD5Pass = tmp });
}
