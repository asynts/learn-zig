### Notes

-   Using `@typeInfo` we can get access to the names of the fields that a structure has.
    However, we have no way of using this information to access the fields at runtime.

    In my opinion, it should be possible to use `@typeInfo` to create an execution plan at comptime.
    That plan could then be executed at runtime.

    However, I am missing a `@fieldsAsTuple` function.
    In my opinion, that function should return a tuple with the fields in a structure in the same order they appear in `@typeInfo`.
    Then the indices into `@typeInfo` could be made avaliable at runtime.

-   The use case is to implement a formatting library that creates an array of instructions at comptime that are evaluated at runtime.
    In theory, it should only be slightly slower than generating code like `std.fmt.format` does and it should drastically reduce the memory usage.

    Here is the code that I came up with:

    ```zig
    // Parser.zig

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
        null: void,
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

                instructions: [counter_context.counter]Instruction = [_]Instruction{ .null } ** counter_context.counter,
                offset: usize = 0,

                fn emit(self: *Self, chunk: Chunk) void {
                    switch (chunk) {
                        .raw_literal => |literal| {
                            self.instructions[self.offset] = Instruction{ .emit_literal = .{ .value = literal } };
                        },
                        .variable_name => |variable_name| {
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
            parseTemplate(input_template, &collect_context);

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
                },
                else => unreachable,
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
    ```

    ```zig
    // Lexer.zig
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
    ```

-   I should note, that my interpreted version probably doesn't have any meaningful advantages.
    In order for this to become useful, I would have to call the `format` functions from the implementation and do a large switch case
    on the types of the parameters.

    Then the function could be marked as never inline and then I can inline everything else into it.
