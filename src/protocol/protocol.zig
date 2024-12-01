const std = @import("std");
const Allocator = std.mem.Allocator;
const Connection = std.http.Client.Connection;

const fe = @import("message/frontend.zig");
const be = @import("message/backend.zig");

const Buffer = @import("../Buffer.zig").Buffer;

pub fn startup(allocator: Allocator, stream: std.net.Stream, user: []const u8, password: ?[]const u8, database: ?[]const u8) !void {
    var buffer = try Buffer.initCapacity(allocator, 1024);
    defer buffer.deinit();

    // Alternative is to use Allocator.dupeZ earlier to store everything as zero terminated, then have
    // startup message accept a zero terminated string. Arguments to be made either way.
    try fe.startupMessage(&buffer, user, database, null, null);

    _ = try stream.write(buffer.items);

    var rbuff: [1024]u8 = undefined;
    _ = try stream.read(&rbuff);

    const response = try be.deserialize(allocator, &rbuff);

    switch (response) {
        .auth_ok => {
            std.debug.print("Auth OL\n", .{});
        },
        .auth_cleartext_pass => {
            std.debug.print("Auth Cleartext Pass\n", .{});
        },
        .auth_md5_pass => {
            std.debug.print("Auth md5_pass\n", .{});
        },
        .auth_sasl => |mechanism| {
            _ = mechanism;
            std.debug.print("Auth SASL\n", .{});
        },
        else => {
            std.debug.print("Unsupport response\n", .{});
        },
    }

    _ = password;
}

//protocol has two phases:
//startup & normal operation

//startup:
//    frontend opens and authenticates. If good, backend sends status information. Then enters normal mode

//normal:
//    frontend sends queries and other commands
//    backend sends back query results and other responses
//    sometimes, (such as NOTIFY), the backend sends unsolicited messages
//    termination is normally from the frontend, but the backend can force
//    SQL queries executed by "simple query" protocol or "extended query" protocol
//    simple:
//        frontend sends a textual query string which is parsed and immediately processed
//    extended:
//        processing queries split to multiple steps (parsing, binding of parms, execution)

//    additional normal most subprotocols fo special operations such as COPY

//all comms through a stream of messages
//typically try to read entire message into buffer before processing contents
//take care to never send incompelte messages

//extended query overview
//state retained between steps represented by two objects:
//prepared statements and portals.
//prepared statements represents the result of parsing and semantic analysis of the string
//portals represent a ready-to-execute or already-partially-executed statement with any
//    missing parameters filled in.
//parse step which creates a prepared statement
//bind step with creates a portal given a prepared statement and values for parameters
//execute step that runs the portals query (which may need to run multiple times if selecting to fetch limited numbers of rows)
//backend can keep track of multiple prepared statements and portals within the same session

//postgres supports the formats BINARY (code 1) or TEXT (code 0), but the spec is open for more.
//text is usually the more portal choice.
//desired format is specified by "format code".
//string do not have a following null byte!

//https://www.postgresql.org/docs/15/protocol-flow.html
