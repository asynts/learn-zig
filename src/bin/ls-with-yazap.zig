const std = @import("std");
const yazap = @import("yazap");

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

const FileFilterEnum = enum {
    only_visible_files,
    only_hidden_files,
    all_files,
};
const LsCommandConfig = struct {
    file_filter: FileFilterEnum,
    b_use_list_format: bool,
    dirpathRelative: []const u8,
};
fn lsCommand(config: LsCommandConfig) !u8 {
    var dirpathAbsolute = std.fs.realpathAlloc(allocator, config.dirpathRelative) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("error: file not found\n", .{});
            return 1;
        } else {
            return err;
        }
    };
    defer allocator.free(dirpathAbsolute);

    var dirHandle = try std.fs.openIterableDirAbsolute(dirpathAbsolute, .{
        .access_sub_paths = false,
        .no_follow = false,
    });
    defer dirHandle.close();

    if (config.file_filter == .all_files) {
        std.debug.print(".\n", .{});
        std.debug.print("..\n", .{});
    }

    var iterator = dirHandle.iterate();
    while (try iterator.next()) |entry| {
        // Maybe skip hidden files.
        if (config.file_filter == .only_visible_files) {
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

    var app = yazap.Yazap.init(allocator, "ls-with-yazap", "List files in directory");
    defer app.deinit();

    var root_cmd = app.rootCommand();

    try root_cmd.addArg(yazap.flag.boolean("all", 'a', "do not ignore entries starting with ."));
    try root_cmd.addArg(yazap.flag.boolean("almost-all", 'A', "do not list implied . and .."));
    try root_cmd.addArg(yazap.flag.boolean("list", 'l', "use long listing format"));

    try root_cmd.takesSingleValue("file");

    var args = try app.parseProcess();

    var flag_all = args.isPresent("all");
    var flag_almost_all = args.isPresent("almost-all");
    var flag_list = args.isPresent("list");
    var arg_file = args.valueOf("file") orelse ".";

    var config = LsCommandConfig{
        .file_filter = .only_visible_files,
        .b_use_list_format = false,
        .dirpathRelative = undefined,
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

    config.dirpathRelative = arg_file;

    return try lsCommand(config);
}
