const std = @import("std");
const Lexer = @import("./Lexer.zig");
const escape = @import("./escape.zig");
const common = @import("./common.zig");

// FIXME: Add error enum.

const dangerous_tag_names = dangerous_tag_names: {
    var names = [_][]const u8 {
        // Allows direct injection of malicious code.
        "script",
        "style",

        // Other less common elements that are considered dangerous.
        "iframe",
        "embed",
        "applet",
        "link",
        "listing",
        "meta",
        "noscript",
        "object",
        "plaintext",
        "xmp",
    };

    std.sort.sort([]const u8, &names, u8, std.mem.lessThan);

    break :dangerous_tag_names names;
};
// We are simply trying to protect the developer.
// There are surely ways to bypass this check.
pub fn isDangerousTagName(name: []const u8) bool {
    if (std.sort.binarySearch([]const u8, name, &dangerous_tag_names, u8, std.mem.order) != null) {
        return true;
    }

    return false;
}

const dangerous_attribute_names = dangerous_attribute_names: {
    var names = [_][]const u8 {
        // Do not allow the user to control style.
        "style",

        // Anything with an URL can use 'javascript:' protocol.
        "href",
        "src",

        // Other less common things that can contain URLs.
        "codebase",
        "cite",
        "background",
        "action",
        "longdesc",
        "profile",
        "usemap",
        "classid",
        "formaction",
        "icon",
        "manifest",
        "formaction",
        "poster",
        "srcset",
        "archive",
        "content",

        // Note that custom attributes like 'data-*' are still allowed.
        "data",
    };

    std.sort.sort([]const u8, &names, u8, std.mem.lessThan);

    break :dangerous_attribute_names names;
};
// We are simply trying to protect the developer.
// There are surely ways to bypass this check.
pub fn isDangerousAttributeName(attribute_name: []const u8, tag_name: []const u8) bool {
    // This includes stuff like 'online' but otherwise we might miss something.
    if (std.mem.startsWith(u8, attribute_name, "on")) {
        return true;
    }

    if (std.sort.binarySearch([]const u8, tag_name, &dangerous_tag_names, u8, std.mem.order) != null) {
        return true;
    }

    if (std.sort.binarySearch([]const u8, attribute_name, &dangerous_attribute_names, u8, std.mem.order) != null) {
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

pub fn verifyPlaceholderSafeInContext(placeholder: Lexer.Placeholder, context: escape.EscapeContext) !void {
    if (placeholder.mode == .trusted) {
        return;
    }

    switch (context) {
        .html_body => |tag| {
            if (common.isDangerousTagName(tag.tag_name)) {
                return error.PlaceholderInDangerousContext;
            }
        },
        .attribute_value => |attribute| {
            if (placeholder.mode == .unescaped_html_body) {
                return error.HtmlPlaceholderInAttributeValue;
            }

            if (common.isDangerousAttributeName(attribute.attribute_name, attribute.tag_name)) {
                return error.PlaceholderInDangerousContext;
            }
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
    try std.testing.expect(!isDangerousAttributeName("script", "div"));
}

test "dangerous attribute name" {
    try std.testing.expect(isDangerousAttributeName("onload", "div"));
    try std.testing.expect(!isDangerousTagName("onload"));
}
