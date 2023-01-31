const std = @import("std");

const Lexer = @import("./Lexer.zig");

const Self = @This();

// FIXME: Do as much as possible at compile time.
// FIXME: Parse at compile time to verify and then at runtime assume that it's valid syntax.

fn consumeOpenTag(lexer: *Lexer) ?[]const u8 {
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

    if (!lexer.consumeChar('>')) {
        lexer.offset = start_offset;
        return null;
    }

    return tag_name;
}

fn consumeCloseTag(lexer: *Lexer) ?[]const u8 {
    var start_offset = lexer.offset;

    if (!lexer.consumeString("</")) {
        lexer.offset = start_offset;
        return null;
    }

    var tag_name = lexer.consumeUntil('>');

    if (!lexer.consumeChar('>')) {
        lexer.offset = start_offset;
        return null;
    }

    return tag_name;
}

// FIXME: Does zig have generators?
//        Maybe they could be used with 'inline for'?

fn evaluateTag(writer: anytype, lexer: *Lexer) !bool {
    var open_tag_name = consumeOpenTag(lexer)
        orelse return false;

    try writer.print("<{s}>", .{ open_tag_name });

    var contents_1 = lexer.consumeUntil('<');
    try writer.print("{s}", .{ contents_1});

    if (consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        try writer.print("</{s}>", .{ close_tag_name });

        return true;
    }

    while (try evaluateTag(writer, lexer)) {
        var contents_2 = lexer.consumeUntil('<');
        try writer.print("{s}", .{ contents_2});
    }

    if (consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        try writer.print("</{s}>", .{ close_tag_name });

        return true;
    }

    return error.TagNotClosed;
}

fn evaluate(allocator: std.mem.Allocator, input: []const u8) ![]const u8 {
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

    var tag_found = try evaluateTag(writer, &lexer);
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

    var actual = try evaluate(allocator, input);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo>x</foo>", actual);
}

test "nested tags accepted" {
    var allocator = std.testing.allocator;
    var input = "<foo><bar></bar></foo>";

    var actual = try evaluate(allocator, input);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo><bar></bar></foo>", actual);
}

test "inline text included in output" {
    var allocator = std.testing.allocator;
    var input = "<foo>x<bar>y</bar>z</foo>";

    var actual = try evaluate(allocator, input);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo>x<bar>y</bar>z</foo>", actual);
}

test "forbid characters before tag" {
    var allocator = std.testing.allocator;
    var input = "x<foo></foo>";

    var actual = evaluate(allocator, input);

    try std.testing.expectError(error.CharactersOutsideOfTag, actual);
}

test "forbid characters after tag" {
    var allocator = std.testing.allocator;
    var input = "<foo></foo>x";

    var actual = evaluate(allocator, input);

    try std.testing.expectError(error.CharactersOutsideOfTag, actual);
}

test "discard surrounding whitespace" {
    var allocator = std.testing.allocator;
    var input = " <foo></foo> ";

    var actual = try evaluate(allocator, input);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo></foo>", actual);
}

test "preserve whitespace in tags" {
    var allocator = std.testing.allocator;
    var input = "<foo> <bar>  </bar> x </foo> ";

    var actual = try evaluate(allocator, input);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo> <bar>  </bar> x </foo>", actual);
}
