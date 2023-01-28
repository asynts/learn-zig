const std = @import("std");
const yazap = @import("yazap");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const Config = struct {
    path_relative: []const u8,
    b_show_hidden_files: bool,
    b_show_dot_dot: bool,
};

fn ls_command(config: Config) !u8 {
    var path_absolute = try std.fs.realpathAlloc(allocator, config.path_relative);
    defer allocator.free(path_absolute);

    var path_directory = try std.fs.openIterableDirAbsolute(path_absolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer path_directory.close();

    if (config.b_show_dot_dot) {
        std.debug.print(".\n", .{});
        std.debug.print("..\n", .{});
    }

    var iterator = path_directory.iterate();
    while (try iterator.next()) |entry| {
        if (!config.b_show_hidden_files) {
            var is_hidden_file = std.mem.startsWith(u8, entry.name, ".");
            if (is_hidden_file) {
                continue;
            }
        }

        std.debug.print("{s}\n", .{ entry.name });
    }

    return 0;
}

pub fn main() !u8 {
    // We need to call this early since 'defer' statements are called in reverse order.
    // If we called it at the end of 'main' it would run too early.
    defer _ = gpa.detectLeaks();

    var app = yazap.Yazap.init(allocator, "ls", "List directory contents");
    defer app.deinit();

    var root_cmd = app.rootCommand();

    try root_cmd.addArg(yazap.flag.boolean("all", 'a', "do not ignore entries starting with ."));
    try root_cmd.addArg(yazap.flag.boolean("almost-all", 'A', "do not list implied . and .."));

    try root_cmd.takesSingleValue("file");

    var args = try app.parseProcess();

    var config = Config{
        .b_show_hidden_files = false,
        .b_show_dot_dot = false,
        .path_relative = ".",
    };

    if (args.isPresent("all")) {
        config.b_show_hidden_files = true;
        config.b_show_dot_dot = true;
    }
    if (args.isPresent("almost-all")) {
        config.b_show_hidden_files = true;
        config.b_show_dot_dot = false;
    }
    if (args.valueOf("file")) |filepath| {
        config.path_relative = filepath;
    }

    return try ls_command(config);
}
