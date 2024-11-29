const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const proto = @import("protocol/protocol.zig");

//postgres protocol documentation found here
//https://www.postgresql.org/docs/current/protocol.html

const AddressInfo = struct {
    host: []const u8,
    port: u16,
};

const ConnectionInfo = struct {
    address: AddressInfo,
    user: []const u8,
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
        return Self{
            .allocator = allocator,
            .conn_info = conn_info,
        };
    }

    pub fn initValues(allocator: Allocator, host: []const u8, port: u8, user: []const u8, password: ?[]const u8, database: ?[]const u8) Self {
        const info = ConnectionInfo{
            .address = .{
                .host = host,
                .port = port,
            },
            .user = user,
            .password = password,
            .database = database,
        };

        return init(allocator, info);
    }

    pub fn connect(self: *Self) !void {
        const stream = try std.net.tcpConnectToHost(self.allocator, self.conn_info.address.host, self.conn_info.address.port);

        try proto.startup(self.allocator, stream, self.conn_info.user, self.conn_info.password, self.conn_info.database);
    }
    //pub fn connect(self: *Self) !void {}
    //pub fn disconnect(self: *Self) void {}
};

test "Play" {
    var pg = Postgres.init(std.testing.allocator, .{
        .address = .{
            .host = "localhost",
            .port = 5432,
        },
        .user = "test",
        .password = "test",
        .database = "test",
    });

    try pg.connect();
}

//test "Parse Connection String" {
//    const info = ConnectionInfo.initFromConnStr("host=127.0.0.1;port=1234;user=test;password=test;database=testdatabase");
//    try std.testing.expectEqualStrings("127.0.0.1", info.host.?);
//    try std.testing.expectEqualStrings("1234", info.port.?);
//    try std.testing.expectEqualStrings("test", info.user.?);
//    try std.testing.expectEqualStrings("test", info.password.?);
//    try std.testing.expectEqualStrings("testdatabase", info.database.?);
//}
