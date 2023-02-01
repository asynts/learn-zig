const std = @import("std");

// FIXME: Add error enum.

const forbidden_tag_names = forbidden_tag_names: {
    var names = [_][]const u8{
        "script",
        "style",
    };

    std.sort.sort([]const u8, &names, u8, std.mem.lessThan);

    break :forbidden_tag_names names;
};

pub const ValidationContext = enum {
    tag_name,
    attribute_name,
};
pub fn validateName(name: []const u8, context: ValidationContext) !void {
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

    switch (context) {
        .tag_name => {
            if (std.sort.binarySearch([]const u8, name, &forbidden_tag_names, u8, std.mem.order) != null) {
                return error.ForbiddenName;
            }
        },
        .attribute_name => {
            // This includes stuff like 'online' but otherwise we might miss something.
            if (std.mem.startsWith(u8, name, "on")) {
                return error.ForbiddenName;
            }
        },
    }
}

test "reject uppercase" {
    try std.testing.expectError(error.UppercaseCharacterInName, validateName("sCRIPT", .tag_name));
}

test "reject dashes at start and end" {
    try std.testing.expectError(error.InvalidName, validateName("-foo", .tag_name));
    try std.testing.expectError(error.InvalidName, validateName("foo-", .tag_name));
    try std.testing.expectError(error.InvalidName, validateName("-", .tag_name));
    try std.testing.expectError(error.InvalidName, validateName("---", .tag_name));
}

test "reject double dash" {
    try std.testing.expectError(error.InvalidName, validateName("foo--bar", .tag_name));
}

test "accept normal tag names" {
    try validateName("div", .tag_name);
    try validateName("foo-bar", .tag_name);
}

test "reject forbidden tag names" {
    try std.testing.expectError(error.ForbiddenName, validateName("script", .tag_name));
    try validateName("script", .attribute_name);
}

test "reject forbidden attribute names" {
    try std.testing.expectError(error.ForbiddenName, validateName("onload", .attribute_name));
    try validateName("onload", .tag_name);
}
