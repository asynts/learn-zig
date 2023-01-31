const std = @import("std");

const escape = @import("./escape.zig");
const Lexer = @import("./Lexer.zig");

const Self = @This();

// FIXME: Do as much as possible at compile time.
//        Parse at compile time to verify and then at runtime assume that it's valid syntax.
//        Alternatively, construct an array of instructions that determines how we escape.

// FIXME: Does zig have generators?
//        Maybe they could be used with 'inline for'?

fn consumeOpenTag(lexer: *Lexer) !?[]const u8 {
    var start_offset = lexer.offset;

    if (!lexer.consumeChar('<')) {
        lexer.offset = start_offset;
        return null;
    }

    if (lexer.consumeChar('/')) {
        lexer.offset = start_offset;
        return null;
    }

    var tag_name = lexer.consumeUntil('>');

    // FIXME: Verify that the tag name is valid.

    if (!lexer.consumeChar('>')) {
        lexer.offset = start_offset;
        return error.InvalidTag;
    }

    return tag_name;
}

fn consumeCloseTag(lexer: *Lexer) !?[]const u8 {
    var start_offset = lexer.offset;

    if (!lexer.consumeString("</")) {
        lexer.offset = start_offset;
        return null;
    }

    var tag_name = lexer.consumeUntil('>');

    // FIXME: Verify that the tag name is valid.

    if (!lexer.consumeChar('>')) {
        lexer.offset = start_offset;
        return error.InvalidTag;
    }

    return tag_name;
}

const Placeholder = struct {
    name: []const u8,
};
fn consumePlaceholder(lexer: *Lexer) !?Placeholder {
    var start_offset = lexer.offset;

    if (!lexer.consumeChar('{')) {
        lexer.offset = start_offset;
        return null;
    }

    if (lexer.consumeChar('{')) {
        @panic("caller should consume escaped braces");
    }

    var placeholder_name = lexer.consumeUntil('}');

    // FIXME: Verify that the placeholder name is valid.

    if (!lexer.consumeChar('}')) {
        lexer.offset = start_offset;
        return error.InvalidPlaceholder;
    }

    return .{
        .name = placeholder_name,
    };
}

fn evaluateContents(
    writer: anytype,
    lexer: *Lexer,
    variables: ?*std.StringHashMap([]const u8),
) !void {
    var contents = lexer.consumeUntilAny("<{");
    try writer.print("{s}", .{ contents });

    while (try consumePlaceholder(lexer)) |placeholder|
    {
        if (variables == null) {
            return error.UnresolvedPlaceholder;
        }

        if (variables.?.get(placeholder.name)) |value| {
            try escape.writeEscaped(writer, value, .html_body);
        } else {
            return error.UnresolvedPlaceholder;
        }

        var contents_2 = lexer.consumeUntilAny("<{");
        try writer.print("{s}", .{ contents_2 });
    }
}

fn evaluateTag(writer: anytype, lexer: *Lexer, variables: ?*std.StringHashMap([]const u8)) !bool {
    var open_tag_name = try consumeOpenTag(lexer)
        orelse return false;

    try writer.print("<{s}>", .{ open_tag_name });

    try evaluateContents(writer, lexer, variables);

    if (try consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        try writer.print("</{s}>", .{ close_tag_name });

        return true;
    }

    while (try evaluateTag(writer, lexer, variables)) {
        try evaluateContents(writer, lexer, variables);
    }

    if (try consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        try writer.print("</{s}>", .{ close_tag_name });

        return true;
    }

    return error.TagNotClosed;
}

pub fn evaluate(allocator: std.mem.Allocator, input: []const u8, variables: ?*std.StringHashMap([]const u8)) ![]const u8 {
    var lexer = Lexer.init(input);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var writer = buffer.writer();

    _ = lexer.consumeWhitespace();

    if (lexer.isEnd()) {
        return error.NoTagFound;
    }

    if (lexer.peek() != '<') {
        return error.CharactersOutsideOfTag;
    }

    var tag_found = try evaluateTag(writer, &lexer, variables);
    std.debug.assert(tag_found);

    _ = lexer.consumeWhitespace();

    if (!lexer.isEnd()) {
        return error.CharactersOutsideOfTag;
    }

    return buffer.toOwnedSlice();
}

test "simple tag working" {
    var allocator = std.testing.allocator;
    var input = "<foo>x</foo>";

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo>x</foo>", actual);
}

test "nested tags accepted" {
    var allocator = std.testing.allocator;
    var input = "<foo><bar></bar></foo>";

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo><bar></bar></foo>", actual);
}

test "inline text included in output" {
    var allocator = std.testing.allocator;
    var input = "<foo>x<bar>y</bar>z</foo>";

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo>x<bar>y</bar>z</foo>", actual);
}

test "forbid characters before tag" {
    var allocator = std.testing.allocator;
    var input = "x<foo></foo>";

    var actual = evaluate(allocator, input, null);

    try std.testing.expectError(error.CharactersOutsideOfTag, actual);
}

test "forbid characters after tag" {
    var allocator = std.testing.allocator;
    var input = "<foo></foo>x";

    var actual = evaluate(allocator, input, null);

    try std.testing.expectError(error.CharactersOutsideOfTag, actual);
}

test "discard surrounding whitespace" {
    var allocator = std.testing.allocator;
    var input = " <foo></foo> ";

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo></foo>", actual);
}

test "preserve whitespace in tags" {
    var allocator = std.testing.allocator;
    var input = "<foo> <bar>  </bar> x </foo> ";

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo> <bar>  </bar> x </foo>", actual);
}

test "lookup placeholders" {
    var allocator = std.testing.allocator;
    var input = "<foo>{hello}, {world}!</foo>";

    var variables = std.StringHashMap([]const u8).init(allocator);
    defer variables.deinit();

    try variables.put("world", "world");
    try variables.put("hello", "Hello");

    var actual = try evaluate(allocator, input, &variables);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo>Hello, world!</foo>", actual);
}

test "error if placeholder unknown" {
    var allocator = std.testing.allocator;
    var input = "<foo>{hello}</foo>";

    var variables = std.StringHashMap([]const u8).init(allocator);
    defer variables.deinit();

    try variables.put("example", "This is an example!");

    var actual = evaluate(allocator, input, &variables);

    try std.testing.expectError(error.UnresolvedPlaceholder, actual);
}

test "error if no placeholders provided" {
    var allocator = std.testing.allocator;
    var input = "<foo>{hello}</foo>";

    var actual = evaluate(allocator, input, null);

    try std.testing.expectError(error.UnresolvedPlaceholder, actual);
}

test "escape in html body" {
    var allocator = std.testing.allocator;
    var input = "<foo>{hello}!</foo>";

    var variables = std.StringHashMap([]const u8).init(allocator);
    defer variables.deinit();

    try variables.put("hello", "<script>alert(1)</script> &");

    var actual = try evaluate(allocator, input, &variables);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo>&lt;script&gt;alert(1)&lt;/script&gt; &amp;!</foo>", actual);
}
