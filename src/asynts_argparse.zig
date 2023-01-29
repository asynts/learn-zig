const std = @import("std");

pub const ValueEnum = enum {
    boolean,
    string,
};
pub const Value = union(ValueEnum) {
    boolean: bool,
    string: []const u8,
};

// FIXME: Add usage page.

// FIXME: Add error enum.

// FIXME: What needs to be public?

// FIXME: Find a better name for this.
pub const Namespace = struct {
    const Self = @This();

    values: std.StringHashMap(Value),
    program_name: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .values = std.StringHashMap(Value).init(allocator),
            .program_name = null,
        };
    }
    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn get(self: *const Self, comptime T: type, key: []const u8) !?T {
        var value_opt = self.values.get(key);

        // FIXME: How to check if optional is empty?
        if (value_opt) |_| {

        } else {
            return null;
        }

        switch (value_opt.?) {
            .string => |value| {
                if (T == []const u8) {
                    return value;
                }
            },
            .boolean => |value| {
                if (T == bool) {
                    return value;
                }
            },
        }

        return error.UnexpectedUnionVariant;
    }
};

// FIXME: Add 'store_string_list'.
pub const ActionEnum = enum {
    store_true,
    store_false,
    store_string,
};

const Option = struct {
    action: ActionEnum,
    name: []const u8,
};
const PositionalArgument = struct {
    action: ActionEnum,
    name: []const u8,
};

pub const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // Uses 'Option.name' as key.
    long_options: std.StringHashMap(Option),

    positional_arguments: std.ArrayList(PositionalArgument),

    pub fn init(allocator: std.mem.Allocator) Self {
        // FIXME: Add help option here.
        //        Use a special action to print help page.

        return Self{
            .allocator = allocator,

            .long_options = std.StringHashMap(Option).init(allocator),
            .positional_arguments = std.ArrayList(PositionalArgument).init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.long_options.deinit();
        self.positional_arguments.deinit();
    }

    pub fn addOption(
        self: *Self,
        action: ActionEnum,
        long_name: []const u8) !void
    {
        switch (action) {
            .store_true,
            .store_false,
            .store_string => {},
        }

        var optionEntry = try self.long_options.getOrPut(long_name);

        if (optionEntry.found_existing) {
            @panic("option name already used by other option");
        }

        optionEntry.value_ptr.* = Option{
            .action = action,
            .name = long_name,
        };
    }

    pub fn addPositionalArgument(
        self: *Self,
        action: ActionEnum,
        name: []const u8) !void
    {
        switch (action) {
            .store_true,
            .store_false => @panic("action not supported for positional arguments"),

            .store_string => {},
        }

        try self.positional_arguments.append(PositionalArgument{
            .action = action,
            .name = name,
        });
    }

    fn _reportError(self: *const Self, writer: anytype, comptime format: []const u8, arguments: anytype) !void {
        var message = try std.fmt.allocPrint(self.allocator, format, arguments);
        defer self.allocator.free(message);

        try writer.writeAll(message);
    }

    // FIXME: Consider moving this into some executor class?
    pub fn parse(self: *const Self, namespace: *Namespace, argv: [][]const u8, writer: anytype) !void {
        var lexer = Lexer.init(argv);
        defer lexer.deinit();

        namespace.program_name = try lexer.take();

        var positional_argument_index: usize = 0;
        while (!lexer.isEnd()) {
            if (lexer.hasLongOption()) {
                // FIXME: Move this into a function like '_parseLongOption'.

                var long_name = try lexer.take();

                if (self.long_options.get(long_name)) |option| {
                    switch (option.action) {
                        .store_true => try namespace.values.put(option.name, Value{ .boolean = true }),
                        .store_false => try namespace.values.put(option.name, Value{ .boolean = false }),

                        .store_string => {
                            var value = lexer.take() catch {
                                try self._reportError(writer, "error: '{s}' not allowed without value", .{ option.name });
                                return;
                            };

                            try namespace.values.put(option.name, Value{
                                .string = value,
                            });
                        },
                    }
                }
            } else {
                // This is a positional argument.

                // FIXME: Move this into a function like '_parsePositionalArgument'.

                if (positional_argument_index >= self.positional_arguments.items.len) {
                    try self._reportError(writer, "error: unexpected positional argument", .{});
                    return;
                }

                var argument = self.positional_arguments.items[positional_argument_index];

                var value = try lexer.take();
                switch (argument.action) {
                    .store_string => {
                        try namespace.values.put(argument.name, Value{ .string = value });
                        positional_argument_index += 1;
                    },

                    else => unreachable,
                }
            }
        }
    }
};

const Lexer = struct {
    const Self = @This();

    argv: [][]const u8,
    offset: usize,

    fn init(argv: [][]const u8) Self {
        return Lexer{
            .argv = argv,
            .offset = 0,
        };
    }
    fn deinit(self: *Self) void {
        _ = self;
    }

    fn isEnd(self: *const Self) bool {
        return self.offset >= self.argv.len;
    }

    fn hasLongOption(self: *const Self) bool {
        if (self.isEnd()) {
            return false;
        }

        return std.mem.startsWith(u8, self.peek() catch unreachable, "--");
    }

    fn peek(self: *const Self) ![]const u8 {
        if (self.isEnd()) {
            return error.IndexOutOfRange;
        }

        return self.argv[self.offset];
    }

    fn take(self: *Self) ![]const u8 {
        var value = try self.peek();
        self.offset += 1;

        return value;
    }
};
