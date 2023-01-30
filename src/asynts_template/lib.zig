const std = @import("std");

const expect = std.testing.expect;

pub const Lexer = struct {
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

    pub fn consumeUntil(self: *Self, marker: u8) []const u8 {
        var start_offset = self.offset;

        while (!self.isEnd()) {
            if (self.peek() == marker) {
                return self.input[start_offset..self.offset];
            }
            self.offset += 1;
        }

        return self.input[start_offset..];
    }

    pub fn consumeChar(self: *Self, char: u8) bool {
        if (self.isEnd()) {
            return false;
        }

        if (self.input[self.offset] == char) {
            self.offset += 1;
            return true;
        }

        return false;
    }
};

const Generator = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    // FIXME: Can we offload the parsing to compile time?
    //        Essentially, this should be a sequence of 'TextPlacementInstruction' and 'VariablePlacementInstruction'.
    //        Generating that at compile time should be possible?
    pub fn run(self: *const Self, arguments: anytype, comptime inputTemplate: []const u8) ![]const u8 {
        var lexer = Lexer.init(inputTemplate);

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        var writer = buffer.writer();

        while (!lexer.isEnd()) {
            var rawString = lexer.consumeUntil('{');
            try writer.print("{s}", rawString);

            if (lexer.consumeChar('{')) {
                var variableName = lexer.consumeUntil('}');

                if (!lexer.consumeChar('}')) {
                    return error.SyntaxError;
                }

                // FIXME: How can I get 'variableName' at compile time here?
                //        Look at how 'std.fmt.format' solves this issue.
                try writer.print("{s}", @field(arguments, variableName));
            }
        }

        return buffer.toOwnedSlice();
    }
};

test {
    var allocator = std.testing.allocator;

    var generator = Generator.init(allocator);
    defer generator.deinit();

    var template = generator.run(
        .{},
        \\<div class="Page">
        \\  <p>Hello, world!</p>
        \\</div>
        \\
    ) catch unreachable;
    defer allocator.free(template);

    try expect(std.mem.eql(
        u8,
        template,
        \\<div class="Page">
        \\  <p>Hello, world!</p>
        \\</div>
        \\
    ));
}

test {
    var allocator = std.testing.allocator;

    var generator = Generator.init(allocator);
    defer generator.deinit();

    var template = generator.run(
        .{
            .text = "Hi!"
        },
        \\<div class="Page">
        \\  <p>{text}</p>
        \\</div>
        \\
    ) catch unreachable;
    defer allocator.free(template);

    try expect(std.mem.eql(
        u8,
        template,
        \\<div class="Page">
        \\  <p>Hi!</p>
        \\</div>
        \\
    ));
}

// FIXME: Test: escape context dependent.
