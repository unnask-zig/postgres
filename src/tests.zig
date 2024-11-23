comptime {
    //Protocol
    _ = @import("protocol/message/frontend.zig");
    _ = @import("protocol/message/backend.zig");
    _ = @import("buffer/buffer.zig");

    _ = @import("postgres.zig");
}

const pg = @import("postgres.zig");
