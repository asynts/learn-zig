const escape = @import("./escape.zig");
const common = @import("./common.zig");

const Self = @This();

input: []const u8,
offset: usize,

pub fn init(input: []const u8) Self {
    return Self{
        .input = input,
        .offset = 0,
    };
}

pub fn isEnd(self: *const Self) bool {
    return self.offset >= self.input.len;
}

pub fn peek(self: *const Self) u8 {
    return self.input[self.offset];
}

pub fn remaining(self: *const Self) []const u8 {
    return self.input[self.offset..];
}

pub fn consumeUntilAny(self: *Self, comptime chars: []const u8) []const u8 {
    var start_offset = self.offset;

    while (!self.isEnd()) {
        inline for (chars) |char| {
            if (self.peek() == char) {
                return self.input[start_offset..self.offset];
            }
        }

        self.offset += 1;
    }

    return self.input[start_offset..];
}

pub fn consumeUntil(self: *Self, comptime char: u8) []const u8 {
    return self.consumeUntilAny(&[_]u8 { char });
}

pub fn consumeChar(self: *Self, char: u8) bool {
    if (self.isEnd()) {
        return false;
    }

    if (self.peek() == char) {
        self.offset += 1;
        return true;
    }

    return false;
}

pub fn consumeString(self: *Self, string: []const u8) bool {
    var start_offset = self.offset;

    for (string) |char| {
        if (!self.consumeChar(char)) {
            self.offset = start_offset;
            return false;
        }
    }

    return true;
}


pub fn consumeWhitespace(self: *Self) []const u8 {
    var start_offset = self.offset;

    while (true) {
        if (self.consumeChar(' ')) {
            continue;
        }
        if (self.consumeChar('\t')) {
            continue;
        }
        if (self.consumeChar('\n')) {
            continue;
        }

        return self.input[start_offset..self.offset];
    }
}

pub fn consumeOpenTagStart(self: *Self) !?[]const u8 {
    var start_offset = self.offset;

    if (!self.consumeChar('<')) {
        self.offset = start_offset;
        return null;
    }

    if (self.consumeChar('/')) {
        self.offset = start_offset;
        return null;
    }

    var tag_name = self.consumeUntilAny(" \t\n>");
    try common.validateName(tag_name);

    return tag_name;
}

pub fn consumeCloseTag(self: *Self) !?[]const u8 {
    var start_offset = self.offset;

    if (!self.consumeString("</")) {
        self.offset = start_offset;
        return null;
    }

    var tag_name = self.consumeUntil('>');
    try common.validateName(tag_name);

    if (!self.consumeChar('>')) {
        self.offset = start_offset;
        return error.InvalidTag;
    }

    return tag_name;
}

pub const PlaceholderMode = enum {
    default,
    trusted,
};
pub const Placeholder = struct {
    name: []const u8,
    mode: PlaceholderMode,
};
pub fn consumePlaceholder(self: *Self) !?Placeholder {
    var start_offset = self.offset;

    if (!self.consumeChar('{')) {
        self.offset = start_offset;
        return null;
    }

    if (self.consumeChar('{')) {
        @panic("caller should consume escaped braces");
    }

    var placeholder_name = self.consumeUntilAny(":}");
    try common.validateName(placeholder_name);

    var placeholder_mode = PlaceholderMode.default;
    if (self.consumeChar(':')) {
        if (self.consumeString("trusted")) {
            placeholder_mode = .trusted;
        } else {
            return error.InvalidPlaceholder;
        }
    }

    if (!self.consumeChar('}')) {
        self.offset = start_offset;
        return error.InvalidPlaceholder;
    }

    return .{
        .name = placeholder_name,
        .mode = placeholder_mode,
    };
}

pub fn consumeRawContent(self: *Self, context: escape.EscapeContext) []const u8 {
    switch (context) {
        .html_body => return self.consumeUntilAny("<{"),
        .attribute_value => return self.consumeUntilAny("\"{"),
    }
}
