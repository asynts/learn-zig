const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    // We need to call this early since 'defer' statements are called in reverse order.
    // If we called it at the end of 'main' it would run too early.
    defer _ = gpa.detectLeaks();

    var argument_iterator = std.process.args();

    // Skip executable name.
    _ = argument_iterator.skip();

    // Path to inspect.
    var path_relative = argument_iterator.next() orelse ".";

    var path_absolute = try std.fs.realpathAlloc(allocator, path_relative);
    defer allocator.free(path_absolute);

    var path_directory = try std.fs.openIterableDirAbsolute(path_absolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer path_directory.close();

    var iterator = path_directory.iterate();
    while (try iterator.next()) |entry| {
        std.debug.print("{s}\n", .{ entry.name });
    }
}
