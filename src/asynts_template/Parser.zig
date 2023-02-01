const std = @import("std");

const escape = @import("./escape.zig");
const Lexer = @import("./Lexer.zig");

const Self = @This();

// FIXME: Do as much as possible at compile time.
//        Parse at compile time to verify and then at runtime assume that it's valid syntax.
//        Alternatively, construct an array of instructions that determines how we escape.

// FIXME: Does zig have generators?
//        Maybe they could be used with 'inline for'?

// FIXME: I should extract the grammar from this and ensure that it makes sense.

// FIXME: Add support for immediately closed tags with '<foo />'.

fn consumeOpenTagStart(lexer: *Lexer) !?[]const u8 {
    var start_offset = lexer.offset;

    if (!lexer.consumeChar('<')) {
        lexer.offset = start_offset;
        return null;
    }

    if (lexer.consumeChar('/')) {
        lexer.offset = start_offset;
        return null;
    }

    var tag_name = lexer.consumeUntilAny(" \t\n>");

    // FIXME: Verify that the tag name is valid.

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

fn consumeRawContent(lexer: *Lexer, context: escape.EscapeContext) []const u8 {
    switch (context) {
        .html_body => return lexer.consumeUntilAny("<{"),
        .attribute_value => return lexer.consumeUntilAny("\"{"),
    }
}

// FIXME: Add support for '&escape;'.
fn evaluateContents(
    writer: anytype,
    lexer: *Lexer,
    variables: ?*std.StringHashMap([]const u8),
    context: escape.EscapeContext,
) !void {
    var contents_1 = consumeRawContent(lexer, context);
    try writer.print("{s}", .{ contents_1 });

    while (try consumePlaceholder(lexer)) |placeholder|
    {
        if (variables == null) {
            return error.UnresolvedPlaceholder;
        }

        if (variables.?.get(placeholder.name)) |value| {
            try escape.writeEscaped(writer, value, context);
        } else {
            return error.UnresolvedPlaceholder;
        }

        var contents_2 = consumeRawContent(lexer, context);
        try writer.print("{s}", .{ contents_2 });
    }
}

fn evaluateAttribute(
    writer: anytype,
    lexer: *Lexer,
    variables: ?*std.StringHashMap([]const u8)
) !bool {
    var attribute_name = lexer.consumeUntilAny("=> \t\n");

    if (attribute_name.len == 0) {
        return false;
    }

    // Include space that was consumed by caller of this function.
    try writer.print(" {s}", .{ attribute_name });

    // FIXME: Validate attribute name.

    // Attribute value is optional.
    if (lexer.consumeChar('=')) {
        if (!lexer.consumeChar('"')) {
            return error.InvalidAttribute;
        }
        try writer.print("=\"", .{});

        try evaluateContents(writer, lexer, variables, .attribute_value);

        if (!lexer.consumeChar('"')) {
            return error.InvalidAttribute;
        }
        try writer.print("\"", .{});
    }

    return true;
}

fn evaluateOpenTag(
    writer: anytype,
    lexer: *Lexer,
    variables: ?*std.StringHashMap([]const u8)
) !?[]const u8 {
    var open_tag_name = try consumeOpenTagStart(lexer)
        orelse return null;

    try writer.print("<{s}", .{ open_tag_name });

    _ = lexer.consumeWhitespace();

    while (try evaluateAttribute(writer, lexer, variables)) {
        if (lexer.consumeWhitespace().len == 0) {
            break;
        }
    }

    _ = lexer.consumeWhitespace();

    if (!lexer.consumeChar('>')) {
        std.debug.print("evaluateOpenTag: remaining='{s}'\n", .{lexer.remaining()});
        return error.InvalidTag;
    }
    try writer.print(">", .{});

    return open_tag_name;
}

fn evaluateTag(
    writer: anytype,
    lexer: *Lexer,
    variables: ?*std.StringHashMap([]const u8),
) !bool {
    var open_tag_name = try evaluateOpenTag(writer, lexer, variables)
        orelse return false;

    try evaluateContents(writer, lexer, variables, .html_body);

    if (try consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        try writer.print("</{s}>", .{ close_tag_name });

        return true;
    }

    while (try evaluateTag(writer, lexer, variables)) {
        try evaluateContents(writer, lexer, variables, .html_body);
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

pub fn evaluate(
    allocator: std.mem.Allocator,
    input: []const u8,
    variables: ?*std.StringHashMap([]const u8)
) ![]const u8 {
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

    // Remove trailing whitespace but keep final newline if the input included it.
    var trailing_whitespace = lexer.consumeWhitespace();
    if (std.mem.indexOf(u8, trailing_whitespace, "\n") != null) {
        try writer.print("\n", .{});
    }

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

test "trivial attribute" {
    var allocator = std.testing.allocator;
    var input =
        \\<foo x="42"></foo>
        ;

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(
        \\<foo x="42"></foo>
        , actual);
}

test "basic attribute support" {
    var allocator = std.testing.allocator;
    var input =
        \\<foo y="13"  z="1">
        \\  <bar x="42"></bar>
        \\</foo>
        ;

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(
        \\<foo y="13" z="1">
        \\  <bar x="42"></bar>
        \\</foo>
        , actual);
}

test "persist final newline" {
    var allocator = std.testing.allocator;
    var input = "<foo></foo> \n ";

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings("<foo></foo>\n", actual);
}

test "attributes without values" {
    var allocator = std.testing.allocator;
    var input =
        \\<foo x y="42" z></foo>
        ;

    var actual = try evaluate(allocator, input, null);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(
        \\<foo x y="42" z></foo>
        , actual);
}

test "trivial attribute with placeholder" {
    var allocator = std.testing.allocator;
    var input =
        \\<foo example="{example}"></foo>
        ;

    var variables = std.StringHashMap([]const u8).init(allocator);
    defer variables.deinit();

    try variables.put("example", "quote='\"' & script='<script>alert(1)</script>'");

    var actual = try evaluate(allocator, input, &variables);
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(
        \\<foo example="quote='&quot;' &amp; script='<script>alert(1)</script>'"></foo>
        , actual);
}
