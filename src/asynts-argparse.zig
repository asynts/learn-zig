const std = @import("std");

pub const ValueEnum = enum {
    boolean,
    string,
};
pub const Value = union(ValueEnum) {
    boolean: bool,
    string: []const u8,
};

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

    pub fn declare(self: *Self, key: []const u8, default_value: Value) !void {
        try self.values.put(key, default_value);
    }

    pub fn get(comptime T: type, self: *const Self, key: []const u8) !T {
        switch (self.values.get(key).?) {
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

// FIXME: Consider splitting this into two enums.
//        One for positional arguments, the other for options.
pub const ActionEnum = enum {
    store_true,
    store_false,
    store_string,
};

const Option = struct {
    key_name: []const u8,
    action: ActionEnum,

    long_name: []const u8,
};
const PositionalArgument = struct {
    key_name: []const u8,
    action: ActionEnum,
    name: []const u8,
};

pub const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // Uses 'Option.long_name' as key.
    options: std.StringHashMap(Option),

    positional_arguments: std.ArrayList(PositionalArgument),

    pub fn init(allocator: std.mem.Allocator) Self {
        // FIXME: Add help option here.
        //        Use a special action to print help page.

        return Self{
            .allocator = allocator,

            .options = std.StringHashMap(Option).init(allocator),
            .positional_arguments = std.ArrayList(PositionalArgument).init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.options.deinit();
        self.positional_arguments.deinit();
    }

    pub fn add_option(
        self: *Self,
        key_name: []const u8,
        action: ActionEnum,
        long_name: []const u8) !void
    {
        switch (action) {
            .store_true,
            .store_false,
            .store_string => {},
        }

        var optionEntry = try self.options.getOrPut(long_name);

        if (optionEntry.found_existing) {
            @panic("option name already used by other option");
        }

        optionEntry.value_ptr.* = Option{
            .key_name = key_name,
            .action = action,
            .long_name = long_name,
        };
    }

    pub fn add_positional_argument(
        self: *Self,
        key_name: []const u8,
        action: ActionEnum,
        name: []const u8) !void
    {
        switch (action) {
            .store_true,
            .store_false => @panic("action not supported for positional arguments"),

            .store_string => {},
        }

        try self.positional_arguments.append(PositionalArgument{
            .key_name = key_name,
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

                var key = try lexer.take();

                if (self.options.get(key)) |option| {
                    switch (option.action) {
                        .store_true => try namespace.values.put(key, Value{ .boolean = true }),
                        .store_false => try namespace.values.put(key, Value{ .boolean = false }),

                        .store_string => {
                            var value = lexer.take() catch {
                                try self._reportError(writer, "error: '{s}' not allowed without value", .{ option.long_name });
                                return;
                            };

                            try namespace.values.put(key, Value{
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
                        try namespace.values.put(argument.key_name, Value{ .string = value });
                        positional_argument_index += 1;
                    },

                    else => unreachable,
                }
            }
        }
    }

    pub fn parseFromSystem(self: *const Self, namespace: *Namespace) !void {
        // FIXME: Oops, we return this after using it.
        //        Use after free.
        var argv = try std.process.argsAlloc(self.allocator);
        defer self.allocator.free(argv);

        try self.parse(namespace, argv, std.io.getStdOut());
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
