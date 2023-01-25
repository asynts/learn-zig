const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{});
const allocator: std.mem.Allocator = gpa.allocator();

pub fn main() !void {
    var argument_iterator = std.process.args();

    // Skip executable name.
    _ = argument_iterator.skip();

    // Positional argument for path to open.
    var path_relative = argument_iterator.next() orelse ".";
    var path_absolute = try std.fs.realpathAlloc(allocator, path_relative);

    var path_directory = try std.fs.openIterableDirAbsolute(path_absolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer path_directory.close();

    for (path_directory.iterate()) |entry| {
        std.debug.print(entry.name);
    }

    try gpa.detectLeaks();
}
