const std = @import("std");
const argparse = @import("asynts-argparse");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn getPermissionsString(metadata: std.fs.File.Metadata) [9:0]u8 {
    var permissions = metadata.permissions().inner;

    var permissions_string = "---------".*;

    if (permissions.unixHas(.user, .read)) {
        permissions_string[0] = 'r';
    }
    if (permissions.unixHas(.user, .write)) {
        permissions_string[1] = 'w';
    }
    if (permissions.unixHas(.user, .execute)) {
        permissions_string[2] = 'x';
    }

    if (permissions.unixHas(.group, .read)) {
        permissions_string[3] = 'r';
    }
    if (permissions.unixHas(.group, .write)) {
        permissions_string[4] = 'w';
    }
    if (permissions.unixHas(.group, .execute)) {
        permissions_string[5] = 'x';
    }

    if (permissions.unixHas(.other, .read)) {
        permissions_string[6] = 'r';
    }
    if (permissions.unixHas(.other, .write)) {
        permissions_string[7] = 'w';
    }
    if (permissions.unixHas(.other, .execute)) {
        permissions_string[8] = 'x';
    }

    return permissions_string;
}

const FileFilterEnum = enum {
    only_visible_files,
    only_hidden_files,
    all_files,
};
const ListFilesCommandConfig = struct {
    file_filter: FileFilterEnum,
    b_use_list_format: bool,
    dirpath_relative: []const u8,
};
fn listFilesCommand(config: ListFilesCommandConfig) !u8 {
    var dirpath_absolute = std.fs.realpathAlloc(allocator, config.dirpath_relative) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("error: file not found\n", .{});
            return 1;
        } else {
            return err;
        }
    };
    defer allocator.free(dirpath_absolute);

    var dir_handle = try std.fs.openIterableDirAbsolute(dirpath_absolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer dir_handle.close();

    if (config.file_filter == .all_files) {
        std.debug.print(".\n", .{});
        std.debug.print("..\n", .{});
    }

    var iterator = dir_handle.iterate();
    while (try iterator.next()) |entry| {
        // Maybe skip hidden files.
        if (config.file_filter == .only_visible_files) {
            var is_hidden_file = std.mem.startsWith(u8, entry.name, ".");
            if (is_hidden_file) {
                continue;
            }
        }

        if (config.b_use_list_format) {
            var filepath_absolute = try std.fs.path.join(allocator, &[_][]const u8{ dirpath_absolute, entry.name });
            defer allocator.free(filepath_absolute);

            var file_handle = try std.fs.openFileAbsolute(filepath_absolute, .{ .mode = .read_only });
            defer file_handle.close();

            var file_metadata = try file_handle.metadata();

            std.debug.print("{s}  {s}\n", .{
                getPermissionsString(file_metadata),
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

    try parser.addOption(
        .store_true,
        "--all",
    );
    try parser.addOption(
        .store_true,
        "--almost-all",
    );
    try parser.addOption(
        .store_true,
        "--list",
    );
    try parser.addPositionalArgument(
        .store_string,
        "[file]",
    );

    var namespace = argparse.Namespace.init(allocator);
    defer namespace.deinit();

    var argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    try parser.parse(&namespace, argv, std.io.getStdOut());

    var flag_all = try namespace.get(bool, "--all") orelse false;
    var flag_almost_all = try namespace.get(bool, "--almost-all") orelse false;
    var flag_list = try namespace.get(bool, "--list") orelse false;
    var arg_file = try namespace.get([]const u8, "[file]") orelse ".";

    var config = ListFilesCommandConfig{
        .file_filter = .only_visible_files,
        .b_use_list_format = false,
        .dirpath_relative = undefined,
    };

    if (flag_all) {
        config.file_filter = .all_files;
    }
    if (flag_almost_all) {
        config.file_filter = .only_hidden_files;
    }
    if (flag_list) {
        config.b_use_list_format = true;
    }

    config.dirpath_relative = arg_file;

    return try listFilesCommand(config);
}
