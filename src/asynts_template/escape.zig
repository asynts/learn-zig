const std = @import("std");

// FIXME: Verify that this is enough.
fn escapeInHtmlBody(writer: anytype, input: []const u8) !void {
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

const EscapeContext = enum {
    html_body,
};
pub fn writeEscaped(writer: anytype, input: []const u8, context: EscapeContext) !void {
    switch (context) {
        .html_body => return escapeInHtmlBody(writer, input),
    }
}
