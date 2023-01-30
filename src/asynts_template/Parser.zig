const std = @import("std");

const Lexer = @import("./Lexer.zig");

pub const Chunk = union(enum) {
    raw_literal: []const u8,
    variable_name: []const u8,
};

/// Parses template which uses '{variable_name}' to insert variables by that name.
/// Instead of evaluating the substitution directly, it uses callback functions.
pub fn parseTemplate(
    comptime input_template: []const u8,
    comptime context: anytype,
) void {
    // FIXME: Is it possible to mark the entire function as 'comptime'?
    comptime {
        var lexer = Lexer.init(input_template);

        while (!lexer.isEnd()) {
            var raw_literal = lexer.consumeUntil('{');
            if (raw_literal.len >= 1) {
                context.emit(.{ .raw_literal = raw_literal });
            }

            if (lexer.consumeChar('{')) {
                var variable_name = lexer.consumeUntil('}');
                context.emit(.{ .variable_name = variable_name });

                if (!lexer.consumeChar('}')) {
                    return error.SyntaxError;
                }
            }
        }
    }
}

const Instruction = union(enum) {
    emit_literal: struct {
        value: []const u8,
    },
    emit_variable: struct {
        value: *[]const u8,
    },
};

/// Uses 'parseTemplate' to generate a list of instructions at compile time.
/// Then evaluates these instructions at runtime.
///
/// The idea is that this will hopefully result in a smaller binary than just generating code directly.
pub fn evaluate(allocator: std.mem.Allocator, arguments: anytype, comptime input_template: []const u8) ![]const u8 {
    comptime var instructions = prepare_instructions: {
        // FIXME: In the future, it may be possible to allocate in 'comptime'.
        //        Then we won't have to count how many chunks will be emitted.

        // Count how many chunks will be emitted.
        var counter_context = struct {
            const Self = @This();

            counter: usize = 0,

            fn emit(self: *Self, chunk: Chunk) void {
                _ = chunk;
                self.counter += 1;
            }
        }{};
        parseTemplate(input_template, &counter_context);

        // Collect the instructions in an array.
        var collect_context = struct {
            const Self = @This();

            instructions: [counter_context.counter]Instruction = [_]Instruction{ undefined } ** counter_context.counter,
            offset: usize = 0,

            fn emit(self: *Self, chunk: Chunk) void {
                switch (chunk) {
                    .raw_literal => |literal| {
                        std.debug.print("visiting 'raw_literal'\n", .{});
                        self.instructions[self.offset] = .{
                            .emit_literal {
                                .value = literal,
                            },
                        };
                    },
                    .variable_name => |variable_name| {
                        std.debug.print("visiting 'variable_name'\n", .{});
                        self.instructions[self.offset] = .{
                            .emit_variable {
                                // FIXME: This can not work, since the address is only known at runtime.
                                //        Instead, I need an offset or something like that.
                                //
                                //        The best option would be a tuple of the fields of arguments.
                                //        Then I could obtain the index with typeinfo and then index into the tuple at runtime.
                                .value = &@field(arguments, variable_name),
                            }
                        };
                    },
                }

                self.offset += 1;
            }
        }{};

        break :prepare_instructions collect_context.instructions;
    };

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var writer = buffer.writer();

    for (instructions) |instruction| {
        switch (instruction) {
            .emit_literal => |inst| {
                std.debug.print("literal instruction\n", .{});
                try writer.print("{s}", .{ inst.value });
            },
            .emit_variable => |inst| {
                std.debug.print("variable instruction", .{});
                try writer.print("{s}", .{ inst.value.* });
            }
        }
    }

    return buffer.toOwnedSlice();
}

test {
    var allocator = std.testing.allocator;

    var actual = evaluate(allocator, .{ .name = "Alice" }, "Hello, {name}!") catch unreachable;
    defer allocator.free(actual);

    std.debug.print("VALUE: '{s}'\n", .{ actual });
    try std.testing.expect(std.mem.eql(u8, "Hello, Alice!", actual));
}
