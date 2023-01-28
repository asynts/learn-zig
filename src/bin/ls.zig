const std = @import("std");
const yazap = @import("yazap");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const Config = struct {
    path_relative: []const u8,
    b_show_hidden_files: bool,
    b_hide_dot_dot_override: bool,
};

// FIXME: Why doesn't this function exist in 'std.ascii'?
fn stringStartsWith(haystack: []const u8, needle: []const u8) bool {
    return if (needle.len > haystack.len) false else stringEqual(haystack[0..needle.len], needle);
}

// FIXME: How to do this without defining a function?
fn stringEqual(lhs: []const u8, rhs: []const u8) bool {
    if (lhs.len != rhs.len) {
        return false;
    }

    // FIXME: This doesn't compile?
    return lhs[0..rhs.len] == rhs[0..rhs.len];
}

fn ls_command(config: Config) !u8 {
    var path_absolute = try std.fs.realpathAlloc(allocator, config.path_relative);
    defer allocator.free(path_absolute);

    var path_directory = try std.fs.openIterableDirAbsolute(path_absolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer path_directory.close();

    var iterator = path_directory.iterate();
    while (try iterator.next()) |entry| {
        var b_hidden_file = stringStartsWith(entry.name, ".");
        var b_dot_dot = (stringEqual(entry.name, ".") or stringEqual(entry.name, ".."));

        if (b_hidden_file and config.b_show_hidden_files) {
            if (!b_dot_dot or !config.b_hide_dot_dot_override) {
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

    try root_cmd.addArg(yazap.flag.argOne("file", 'f', null));

    var args = try app.parseProcess();

    var config = Config{
        .b_show_hidden_files = false,
        .b_hide_dot_dot_override = false,
        .path_relative = ".",
    };

    if (args.isPresent("all")) {
        config.b_show_hidden_files = true;
    }
    if (args.isPresent("almost-all")) {
        config.b_hide_dot_dot_override = true;
    }
    if (args.valueOf("file")) |filepath| {
        // FIXME: Do we have to free this value?
        config.path_relative = filepath;
    }

    std.debug.print("{any}\n", .{ config });

    return try ls_command(config);
}
