const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

//postgres protocol documentation found here
//https://www.postgresql.org/docs/current/protocol.html

const ConnectionInfo = struct {
    address: std.net.Address,
    user: ?[]const u8 = null,
    password: ?[]const u8 = null,
    database: ?[]const u8 = null,

    const Self = @This();

    //fn setParameter(info: *Self, key: []const u8, value: []const u8) void {
    //    if (std.mem.eql(u8, "host", key)) {
    //        info.host = value;
    //    } else if (std.mem.eql(u8, "port", key)) {
    //        info.port = value;
    //    } else if (std.mem.eql(u8, "user", key)) {
    //        info.user = value;
    //    } else if (std.mem.eql(u8, "password", key)) {
    //        info.password = value;
    //    } else if (std.mem.eql(u8, "database", key)) {
    //        info.database = value;
    //    } else {
    //        // probably return an error here
    //    }
    //}

    //pub fn initFromConnStr(str: []const u8) Self {
    //    var tmp: Self = .{};
    //    var it = std.mem.splitScalar(u8, str, ';');
    //    while (it.next()) |chunk| {
    //        var chunk_it = std.mem.splitScalar(u8, chunk, '=');
    //        const key = chunk_it.first();
    //        const value = chunk_it.rest();
    //        tmp.setParameter(key, value);
    //    }
    //    return tmp;
    //}
};

const Postgres = struct {
    allocator: Allocator,
    conn_info: ConnectionInfo,

    const Self = @This();

    pub fn init(allocator: Allocator, conn_info: ConnectionInfo) Self {
        return Self{ .allocator = allocator, .conn_info = conn_info };
    }

    //pub fn connect(self: *Self) !void {}
    //pub fn disconnect(self: *Self) void {}
};

test "Play" {

    // Just typing things out to see what feels nice

    const pg = Postgres.init(std.testing.allocator, .{
        .address = std.net.Address.resolveIp("127.0.0.1", 5432),
        .user = "test",
        .password = "test",
        .database = "test",
    });

    //not sure I like this. Forces the user to call the std.net.Address. Maybe
    //const pg = Postgres.init(std.testing.allocator, .{
    //    .host = "127.0.0.1",
    //    .port = 5432,
    //    .user = "test",
    //    .password = "test",
    //    .database = "test",
    //});
    //
    //Connection strings are commonplace across a variety of implementations.
    //Nice advantage of being able to store connection info in a single field.
    //const pg = Postgres.connect("host=127.0.0.1;port=5432;user=test;password=test;database=test")
    //
    //const pg = Postgres.connect(.{
    //    .address = .{
    //      .host = "127.0.0.1",
    //      .port = 5432,
    //    },
    //    .user...
    //})

    _ = pg;
}

//test "Parse Connection String" {
//    const info = ConnectionInfo.initFromConnStr("host=127.0.0.1;port=1234;user=test;password=test;database=testdatabase");
//    try std.testing.expectEqualStrings("127.0.0.1", info.host.?);
//    try std.testing.expectEqualStrings("1234", info.port.?);
//    try std.testing.expectEqualStrings("test", info.user.?);
//    try std.testing.expectEqualStrings("test", info.password.?);
//    try std.testing.expectEqualStrings("testdatabase", info.database.?);
//}
