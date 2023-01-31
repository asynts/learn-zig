const std = @import("std");

const Lexer = @import("./Lexer.zig");
const Parser = @import("./Parser.zig");

pub const Generator = struct {
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

    pub fn run(self: *const Self, arguments: anytype, comptime inputTemplate: []const u8) ![]const u8 {
        comptime var lexer = Lexer.init(inputTemplate);

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        var writer = buffer.writer();

        inline while (comptime !lexer.isEnd()) {
            comptime var raw_literal = lexer.consumeUntil('{');
            try writer.print("{s}", .{ raw_literal });

            if (comptime lexer.consumeChar('{')) {
                comptime var variable_name = lexer.consumeUntil('}');

                if (comptime !lexer.consumeChar('}')) {
                    return error.SyntaxError;
                }

                try writer.print("{s}", .{ @field(arguments, variable_name) });
            }
        }

        return buffer.toOwnedSlice();
    }
};

test {
    var allocator = std.testing.allocator;

    var generator = Generator.init(allocator);
    defer generator.deinit();

    var output = generator.run(.{}, "Hello, world!") catch unreachable;
    defer allocator.free(output);

    try std.testing.expect(std.mem.eql(u8, output, "Hello, world!"));
}

test {
    var allocator = std.testing.allocator;

    var generator = Generator.init(allocator);
    defer generator.deinit();

    var output = generator.run(.{ .name = "Alice" }, "Hello, {name}!") catch unreachable;
    defer allocator.free(output);

    try std.testing.expect(std.mem.eql(u8, output, "Hello, Alice!"));
}
