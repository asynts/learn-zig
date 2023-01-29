const std = @import("std");

const argparse = @import("asynts-argparse");

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
    b_hide_hidden_files: bool,
    b_hide_dot_dot_files: bool,
    b_use_list_format: bool,
    dirpathRelative: []const u8,
};
fn lsCommand(config: LsCommandConfig) !u8 {
    var dirpathAbsolute = try std.fs.realpathAlloc(allocator, config.dirpathRelative);
    defer allocator.free(dirpathAbsolute);

    var dirHandle = try std.fs.openIterableDirAbsolute(dirpathAbsolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer dirHandle.close();

    if (!config.b_hide_dot_dot_files) {
        std.debug.print(".\n", .{});
        std.debug.print("..\n", .{});
    }

    var iterator = dirHandle.iterate();
    while (try iterator.next()) |entry| {
        // Maybe skip hidden files.
        if (config.b_hide_hidden_files) {
            var is_hidden_file = std.mem.startsWith(u8, entry.name, ".");
            if (is_hidden_file) {
                continue;
            }
        }

        if (config.b_use_list_format) {
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

    var parser = argparse.Parser.init(allocator);
    defer parser.deinit();

    // FIXME: Default values in options?
    //        That would not work if multiple options refer to the same.
    //        I could use the call oder and assert.

    try parser.add_option(
        "hide_hidden_files",
        .store_false,
        "--all",
    );
    try parser.add_option(
        "hide_dot_dot_files",
        .store_true,
        "--almost-all",
    );
    try parser.add_option(
        "use_list_format",
        .store_true,
        "--list",
    );

    try parser.add_positional_argument(
        "file",
        .store_string,
        "[file]",
    );

    var namespace = argparse.Namespace.init(allocator);
    defer namespace.deinit();

    // FIXME: What is 'namespace.declare()' for?

    // FIXME: Find better way to define default values.
    try namespace.values.put("hide_hidden_files", .{ .boolean = true });
    try namespace.values.put("hide_dot_dot_files", .{ .boolean = false });
    try namespace.values.put("use_list_format", .{ .boolean = false });
    try namespace.values.put("file", .{ .string = "." });

    try parser.parseFromSystem(&namespace);

    var config = LsCommandConfig{
        // FIXME: Can I turn this into a member function?
        .b_hide_hidden_files = try argparse.Namespace.get(bool, &namespace, "hide_hidden_files"),
        .b_hide_dot_dot_files = try argparse.Namespace.get(bool, &namespace, "hide_dot_dot_files"),
        .b_use_list_format = try argparse.Namespace.get(bool, &namespace, "use_list_format"),
        .dirpathRelative = try argparse.Namespace.get([]const u8, &namespace, "file"),
    };
    return try lsCommand(config);
}
