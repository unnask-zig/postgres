const std = @import("std");
const testing = std.testing;

//postgres protocol documentation found here
//https://www.postgresql.org/docs/current/protocol.html

const ConnectionInfo = struct {
    host: ?[]const u8 = null,
    port: ?[]const u8 = null,
    user: ?[]const u8 = null,
    password: ?[]const u8 = null,
    database: ?[]const u8 = null,

    const Self = @This();

    fn setParameter(info: *Self, key: []const u8, value: []const u8) void {
        if (std.mem.eql(u8, "host", key)) {
            info.host = value;
        } else if (std.mem.eql(u8, "port", key)) {
            info.port = value;
        } else if (std.mem.eql(u8, "user", key)) {
            info.user = value;
        } else if (std.mem.eql(u8, "password", key)) {
            info.password = value;
        } else if (std.mem.eql(u8, "database", key)) {
            info.database = value;
        } else {
            // probably return an error here
        }
    }

    pub fn initFromConnStr(str: []const u8) Self {
        var tmp: Self = .{};

        var it = std.mem.splitScalar(u8, str, ';');
        while (it.next()) |chunk| {
            var chunk_it = std.mem.splitScalar(u8, chunk, '=');
            const key = chunk_it.first();
            const value = chunk_it.rest();

            tmp.setParameter(key, value);
        }

        return tmp;
    }
};

test "Parse Connection String" {
    const info = ConnectionInfo.initFromConnStr("host=127.0.0.1;port=1234;user=test;password=test;database=testdatabase");

    try std.testing.expectEqualStrings("127.0.0.1", info.host.?);
}
