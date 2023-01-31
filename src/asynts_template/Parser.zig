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

/// Assumes that the input is well-formed.
/// We avoid memory allocations by using recursion, effectively allocating on the stack.
fn evaluate(lexer: *Lexer) !bool {
    var open_tag_name = consumeOpenTag(lexer)
        orelse return false;

    var contents = lexer.consumeUntil('<');
    _ = contents;

    if (consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        return true;
    }

    while (try evaluate(lexer)) { }

    if (consumeCloseTag(lexer)) |close_tag_name| {
        if (!std.mem.eql(u8, open_tag_name, close_tag_name)) {
            return error.UnexpectedCloseTag;
        }

        return true;
    }

    return error.TagNotClosed;
}

test {
    var input = "<foo>x</foo>";
    var lexer = Lexer.init(input);

    var actual = try evaluate(&lexer);

    try std.testing.expect(actual);
}
