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

    pub fn peek(self: *const Self) u8 {
        return self.input[self.offset];
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

        if (self.peek() == char) {
            self.offset += 1;
            return true;
        }

        return false;
    }
};

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

    pub fn _parseTemplate(
        comptime inputTemplate: []const u8,
        comptime context: anytype,
        comptime emitLiteral: fn (context: anytype, literal: []const u8) void,
        comptime emitVariable: fn (context: anytype, name: []const u8) void,
    ) !void {
        // FIXME: Is it possible to mark the entire function as 'comptime'?
        comptime {
            var lexer = Lexer.init(inputTemplate);

            while (!lexer.isEnd()) {
                var raw_literal = lexer.consumeUntil('{');
                if (raw_literal.len >= 1) {
                    emitLiteral(raw_literal);
                }

                if (lexer.consumeChar('{')) {
                    var variable_name = lexer.consumeUntil('}');
                    emitVariable(variable_name);

                    if (!lexer.consumeChar('}')) {
                        return error.SyntaxError;
                    }
                }
            }
        }
    }

    pub fn runWithTypeErasure(self: *const Self, arguments: anytype, comptime inputTemplate: []const u8) ![]const u8 {
        const InstructionType = enum {
            emit_literal,
            emit_variable,
        };
        const Instruction = struct (InstructionType) {
            emit_literal: []const u8,
            emit_variable: []const u8,
        };

        comptime var instructions = compute_instructions: {
            // FIXME: We need to measure how many instructions there are.
            //        In the future, we could use memory allocations here, but Zig doesn't yet support that.
            var instructionCount: usize = 0;

            fn reserveInstruction(instructionCountPtr: *usize, []const u8) void {
                instructionCountPtr.* += 1;
            }

            self._parseTemplate(
                inputTemplate,
                &instructionCount,
                reserveInstruciton,
                reserveInstruction,
            ) orelse unreachable;

            const Context = struct {
                instructions: [instructionCount]Instruction,
                offset: usize,
            };

            var context = Context{
                .instructions = undefined,
                .offset = 0,
            };

            fn saveLiteral(context: *Context, literal: []const u8) void {
                context.*.instructions[context.*.offset] = .{ .emit_literal = literal };
                context.*.offset += 1;
            }
            fn saveVariable(context: *Context, variable_name: []const u8) void {
                context.*.instructions[context.*.offset] = .{ .emit_variable = variable_name };
                context.*.offset += 1;
            }

            self._parseTemplate(
                inputTemplate,
                &context,
                saveLiteral,
                saveVariable,
            ) orelse unreachable;

            break :compute_instructions context.instructions;
        };

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        var writer = buffer.writer();

        for (instructions) |instruction| {
            switch (instruction) {
                .emit_literal => |literal| {
                    try writer.print("{s}", .{ literal });
                },
                .emit_variable => |variable_name| {
                    // FIXME: I can't get the variable name here, fuck.
                    //        The variables could be thrown into a tuple and accessed by index.
                }
            }
        }
    }

    // FIXME: I think a better approach would be to prepare a sequence of instructions at comptime that is executed at runtime.
    //        With 'Literal' and 'VariableSubstitution' or something like that.
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

    try expect(std.mem.eql(u8, output, "Hello, world!"));
}

test {
    var allocator = std.testing.allocator;

    var generator = Generator.init(allocator);
    defer generator.deinit();

    var output = generator.run(.{ .name = "Alice" }, "Hello, {name}!") catch unreachable;
    defer allocator.free(output);

    try expect(std.mem.eql(u8, output, "Hello, Alice!"));
}
