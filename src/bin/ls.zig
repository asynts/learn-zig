const std = @import("std");
const yazap = @import("yazap");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const Config = struct {
    b_show_hidden_files: bool,
    b_hide_dot_dot_override: bool,
};

pub fn main() !void {
    // We need to call this early since 'defer' statements are called in reverse order.
    // If we called it at the end of 'main' it would run too early.
    defer _ = gpa.detectLeaks();

    var app = yazap.App.init(allocator, "ls", "List directory contents");
    defer app.deinit();

    var root_cmd = app.rootCommand();

    try root_cmd.addArg(yazap.flag.boolean("all", 'a', "do not ignore entries starting with ."));
    try root_cmd.addArg(yazap.flag.boolean("almost-all", 'A', "do not list implied . and .."));

    try root_cmd.addArg(yazap.flag.argOne("file", 'f', null));

    var args = try app.parseProcess();

    // var config = Config{
    //     .b_show_hidden_files = undefined,
    //     .b_hide_dot_dot_override = undefined,
    // };

    _ = args;
    // _ = args.valueOf("all");

//     if (args.valueOf("all")) |value| {
//         _ = value;
// //        config.b_show_hidden_files = true;
//     } else {
//         //config.b_show_hidden_files = false;
//     }

    // var argument_iterator = std.process.args();

    // // Skip executable name.
    // _ = argument_iterator.skip();

    // // Path to inspect.
    // var path_relative = argument_iterator.next() orelse ".";

    // var path_absolute = try std.fs.realpathAlloc(allocator, path_relative);
    // defer allocator.free(path_absolute);

    // var path_directory = try std.fs.openIterableDirAbsolute(path_absolute, .{
    //     .access_sub_paths = false,
    //     .no_follow = false,
    // });
    // defer path_directory.close();

    // var iterator = path_directory.iterate();
    // while (try iterator.next()) |entry| {
    //     std.debug.print("{s}\n", .{ entry.name });
    // }
}
