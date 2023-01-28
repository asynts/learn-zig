const std = @import("std");

const argument_parser = @import("../argument_parser.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn getPermissionsString(metadata: std.fs.File.Metadata) [9:0]u8 {
    var permissions = metadata.permissions().inner;

    var permissionsString = "---------".*;

    if (permissions.unixHas(.user, .read)) {
        permissionsString[0] = 'r';
    }
    if (permissions.unixHas(.user, .write)) {
        permissionsString[1] = 'w';
    }
    if (permissions.unixHas(.user, .execute)) {
        permissionsString[2] = 'x';
    }

    if (permissions.unixHas(.group, .read)) {
        permissionsString[3] = 'r';
    }
    if (permissions.unixHas(.group, .write)) {
        permissionsString[4] = 'w';
    }
    if (permissions.unixHas(.group, .execute)) {
        permissionsString[5] = 'x';
    }

    if (permissions.unixHas(.other, .read)) {
        permissionsString[6] = 'r';
    }
    if (permissions.unixHas(.other, .write)) {
        permissionsString[7] = 'w';
    }
    if (permissions.unixHas(.other, .execute)) {
        permissionsString[8] = 'x';
    }

    return permissionsString;
}

const LsCommandConfig = struct {
    dirpathRelative: []const u8,
    b_show_hidden_files: bool,
    b_show_dot_dot: bool,
    b_long_listing_format: bool,
};
fn lsCommand(config: LsCommandConfig) !u8 {
    var dirpathAbsolute = try std.fs.realpathAlloc(allocator, config.dirpathRelative);
    defer allocator.free(dirpathAbsolute);

    var dirHandle = try std.fs.openIterableDirAbsolute(dirpathAbsolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer dirHandle.close();

    if (config.b_show_dot_dot) {
        std.debug.print(".\n", .{});
        std.debug.print("..\n", .{});
    }

    var iterator = dirHandle.iterate();
    while (try iterator.next()) |entry| {
        // Maybe skip hidden files.
        if (!config.b_show_hidden_files) {
            var is_hidden_file = std.mem.startsWith(u8, entry.name, ".");
            if (is_hidden_file) {
                continue;
            }
        }

        if (config.b_long_listing_format) {
            var filepathAbsolute = try std.fs.path.join(allocator, &[_][]const u8{ dirpathAbsolute, entry.name });
            defer allocator.free(filepathAbsolute);

            var fileHandle = try std.fs.openFileAbsolute(filepathAbsolute, .{ .mode = .read_only });
            defer fileHandle.close();

            var fileMetadata = try fileHandle.metadata();

            std.debug.print("{s}  {s}\n", .{
                getPermissionsString(fileMetadata),
                entry.name,
            });
        } else {
            std.debug.print("{s}\n", .{ entry.name });
        }
    }

    return 0;
}

pub fn main() !u8 {
    // We need to call this early since 'defer' statements are called in reverse order.
    // If we called it at the end of 'main' it would run too early.
    defer _ = gpa.detectLeaks();

    var parser = argument_parser.ArgumentParser.init();

    try parser.add_argument(argument_parser.Argument{
        .name = "all",
        .short_name = 'a',
        .type_ = argument_parser.ArgumentType.boolean,
    });
    try parser.add_argument(argument_parser.Argument{
        .name = "almost-all",
        .short_name = null,
        .type_ = argument_parser.ArgumentType.boolean,
    });
    try parser.add_argument(argument_parser.Argument{
        .name = "list",
        .short_name = 'l',
        .type_ = argument_parser.ArgumentType.boolean,
    });

    try parser.add_positional_argument("file");

    var args = parser.parse();

    var config = LsCommandConfig{
        .b_show_hidden_files = false,
        .b_show_dot_dot = false,
        .b_long_listing_format = false,
        .dirpathRelative = ".",
    };

    if (args.isFlagSet("all")) {
        config.b_show_hidden_files = true;
        config.b_show_dot_dot = true;
    }
    if (args.isFlagSet("almost-all")) {
        config.b_show_hidden_files = true;
        config.b_show_dot_dot = false;
    }
    if (args.isFlagSet("list")) {
        config.b_long_listing_format = true;
    }
    if (args.getStringValue("file")) |filepath| {
        config.dirpathRelative = filepath;
    }

    return try lsCommand(config);
}
