const std = @import("std");
const Connection = std.http.Client.Connection;

const fep = @import("message/frontend.zig");

pub fn startup(connection: Connection,buffer: *Buffer, portal: [:0]const u8, stmt: [:0]const u8, formats: []const Formats, values: []const []const u8, result_formats: []const Formats) void {
    
    const smsg = fep.startupMessage(buffer, user, database, options, replication);
    _ = smsg;
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
