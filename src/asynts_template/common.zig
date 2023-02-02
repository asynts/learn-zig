const std = @import("std");

// FIXME: Add error enum.

const dangerous_tag_names = forbidden_tag_names: {
    var names = [_][]const u8{
        "script",
        "style",
    };

    std.sort.sort([]const u8, &names, u8, std.mem.lessThan);

    break :forbidden_tag_names names;
};

pub fn isDangerousTagName(name: []const u8) bool {
    if (std.sort.binarySearch([]const u8, name, &dangerous_tag_names, u8, std.mem.order) != null) {
        return true;
    }

    return false;
}

pub fn isDangerousAttributeName(name: []const u8) bool {
    // This includes stuff like 'online' but otherwise we might miss something.
    if (std.mem.startsWith(u8, name, "on")) {
        return true;
    }

    return false;
}

pub fn validateName(name: []const u8) !void {
    if (name.len == 0) {
        return error.InvalidName;
    }
    if (std.mem.startsWith(u8, name, "-")) {
        return error.InvalidName;
    }
    if (std.mem.endsWith(u8, name, "-")) {
        return error.InvalidName;
    }

    var has_seen_dash = true;
    for (name) |char| {
        if (char >= 'a' and char <= 'z') {
            has_seen_dash = false;
            continue;
        }

        // HTML is case-insensitive.
        // To avoid issues like '<sCRIPT>' enforce lowercase.
        if (char >= 'A' and char <= 'Z') {
            return error.UppercaseCharacterInName;
        }

        if (char == '-') {
            if (has_seen_dash) {
                return error.InvalidName;
            }

            has_seen_dash = true;
            continue;
        }
    }
}

test "reject uppercase" {
    try std.testing.expectError(error.UppercaseCharacterInName, validateName("sCRIPT"));
}

test "reject dashes at start and end" {
    try std.testing.expectError(error.InvalidName, validateName("-foo"));
    try std.testing.expectError(error.InvalidName, validateName("foo-"));
    try std.testing.expectError(error.InvalidName, validateName("-"));
    try std.testing.expectError(error.InvalidName, validateName("---"));
}

test "reject double dash" {
    try std.testing.expectError(error.InvalidName, validateName("foo--bar"));
}

test "accept normal tag names" {
    try validateName("div");
    try validateName("foo-bar");
}

test "dangerous tag name" {
    try std.testing.expect(isDangerousTagName("script"));
    try std.testing.expect(!isDangerousAttributeName("script"));
}

test "dangerous attribute name" {
    try std.testing.expect(isDangerousAttributeName("onload"));
    try std.testing.expect(!isDangerousTagName("onload"));
}
