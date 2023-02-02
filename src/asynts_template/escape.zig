const std = @import("std");

// FIXME: Verify that this is enough.
fn writeEscapedIntoHtmlBody(writer: anytype, input: []const u8) !void {
    for (input) |char| {
        if (char == '&') {
            try writer.print("&amp;", .{});
        } else if (char == '<') {
            try writer.print("&lt;", .{});
        } else if (char == '>') {
            try writer.print("&gt;", .{});
        } else {
            try writer.print("{c}", .{ char });
        }
    }
}

// FIXME: Verify that this is enough.
fn writeEscapedIntoAttributeValue(writer: anytype, input: []const u8) !void {
    for (input) |char| {
        if (char == '&') {
            try writer.print("&amp;", .{});
        } else if (char == '"') {
            try writer.print("&quot;", .{});
        } else {
            try writer.print("{c}", .{ char });
        }
    }
}

pub const EscapeContext = union(enum) {
    html_body: struct {
        tag_name: []const u8,
    },
    attribute_value: struct {
        tag_name: []const u8,
        attribute_name: []const u8,
    },
};
pub fn writeEscaped(writer: anytype, input: []const u8, context: EscapeContext) !void {
    switch (context) {
        .html_body => return writeEscapedIntoHtmlBody(writer, input),
        .attribute_value => return writeEscapedIntoAttributeValue(writer, input),
    }
}

pub fn escapeAlloc(allocator: std.mem.Allocator, input: []const u8, context: EscapeContext) ![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try writeEscaped(buffer.writer(), input, context);

    return buffer.toOwnedSlice();
}

test "escape in html body" {
    var allocator = std.testing.allocator;

    var actual = try escapeAlloc(allocator, "<foo> &amp; x<<\"", .{ .html_body = .{ .tag_name = "example" } });
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("&lt;foo&gt; &amp;amp; x&lt;&lt;\"", actual);
}

test "escape in attribute value" {
    var allocator = std.testing.allocator;

    var escape_context = EscapeContext{
        .attribute_value = .{
            .attribute_name = "example",
            .tag_name = "div",
        },
    };

    var actual = try escapeAlloc(allocator, "<foo> &amp; x<<\"", escape_context);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo> &amp;amp; x<<&quot;", actual);
}
