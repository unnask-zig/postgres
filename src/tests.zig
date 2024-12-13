comptime {
    //Protocol
    //    _ = @import("protocol/message/frontend.zig");
    //    _ = @import("protocol/message/backend.zig");
    _ = @import("buffer/Buffer.zig");
    _ = @import("buffer/Reader.zig");
    _ = @import("buffer/Writer.zig");

    //    _ = @import("postgres.zig");
}

const pg = @import("postgres.zig");
