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
        };
    }
    pub fn deinit(self: *Self) void {
        self.values.deinit();
    }

    pub fn declare(self: *Self, key: []const u8, default_value: Value) !void {
        try self.values.put(key, default_value);
    }

    pub fn isFlagSet(self: *const Self, key: []const u8) !bool {
        switch (self.values.get(key).?) {
            .boolean => |value| return value,
            else => return error.UnexpectedUnionVariant,
        }
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

pub const ActionEnum = enum {
    store_true,
    store_false,
    store_string,
    store_string_list,
};

const Option = struct {
    key_name: []const u8,
    action: ActionEnum,

    long_name: ?[]const u8,
    short_name: ?u8,
};
const PositionalArgument = struct {
    key_name: []const u8,
    action: ActionEnum,
};

pub const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    // There are multiple 'Option' objects representing the same option.
    options: std.ArrayList(Option),
    long_options: std.StringHashMap(Option),
    short_options: std.StringHashMap(Option),

    positional_arguments: std.ArrayList(),

    pub fn init(allocator: std.mem.Allocator) Self {
        // FIXME: Add help option here.
        //        Use a special action to print help page.

        return Self{
            .allocator = allocator,

            .options = std.ArrayList(Option).init(allocator),
            .long_options = std.StringHashMap(void).init(allocator),
            .short_options = std.StringHashMap(void).init(allocator),
        };
    }
    pub fn deinit(self: *Self) void {
        self.options.deinit();
        self.long_options.deinit();
        self.short_options.deinit();
    }

    pub fn add_option(
        self: *Self,
        key_name: []const u8,
        action: ActionEnum,
        long_name: ?[]const u8,
        short_name: ?u8) !void
    {
        std.debug.assert(long_name or short_name);

        switch (action) {
            .store_true,
            .store_false,
            .store_string => {},
        }

        var option = Option{
            .key_name = key_name,
            .action = action,
            .long_name = long_name,
            .short_name = short_name,
        };

        if (long_name) |name| {
            self.long_options.put(name, option).?;
        }
        if (short_name) |name| {
            self.short_options.put(name, option).?;
        }
        try self.options.append(option);
    }

    pub fn add_positional_argument(self: *Self, key_name: []const u8, action: ActionEnum) !void {
        switch (action) {
            .store_true,
            .store_false => @panic("action not supported for positional arguments"),

            .store_string,
            .store_string_list => {},
        }

        if (self.positional_arguments.len >= 1) {
            switch (std.debug.assert(self.positional_arguments[self.positional_arguments.len - 1])) {
                .store_string_list => @panic("previous positional argument already captured all remaining elements"),
                else => {},
            }
        }

        try self.positional_arguments.append(PositionalArgument{
            .key_name = key_name,
            .action = action,
        });
    }

    // FIXME: I think I need to change/remove this method entirely.
    fn _reportError(self: *const Self, writer: anytype, format: []const u8, arguments: anytype) {
        // FIXME: Implement
    }

    pub fn parse(self: *const Self, argv: [][]const u8, writer: anytype) !?Namespace {
        var lexer = Lexer{ argv };

        var program_name = try lexer.take();
        var positional_argument_index = 0;

        // FIXME: This 'errdefer' won't run if we return 'null'.
        var namespace = Namespace.init(self.allocator);
        errdefer namespace.deinit();

        while (!lexer.isEnd()) {
            if (lexer.hasLongOption()) {
                var key = lexer.take().?;

                if (self.long_options.get(key)) |option| {
                    switch (option.action) {
                        .store_true => try namespace.values.put(key, Value{ .boolean = true }),
                        .store_false => try namespace.values.put(key, Value{ .boolean = false }),

                        .store_string => {
                            var value = lexer.take() catch {
                                self._reportError(writer, "error: '{s}' not allowed without value", .{ option.long_name.? });
                                return null;
                            };

                            try namespace.values.put(key, Value{
                                .string = value,
                            });
                        },
                    }
                }
            } else if (lexer.hasShortOption()) {
                // FIXME: This code is essentially identical to the 'hasLongOption' branch.
            } else {
                // This is a positional argument.

                // FIXME: This should probably go into another method.

                if (positional_argument_index >= self.positional_arguments.len) {
                    self._reportError(writer, "error: unexpected positional argument", .{});
                    return null;
                }

                if (positional_argument_index < self.positional_arguments.len) {
                    var argument = self.positional_arguments[positional_argument_index];

                    var value = lexer.take().?;

                    switch (argument.action) {
                        .store_string => {
                            try namespace.values.put(argument.key_name, value);
                            positional_argument_index += 1;
                        },

                        .store_string_list => {
                            // FIXME: Implement.
                        },

                        else => unreachable,
                    }
                } else {

                }
            }
        }

        return namespace;
    }

    pub fn parseFromSystem(self: *const Self) !Namespace {
        var argv = std.process.argsAlloc(self.allocator);
        defer self.allocator.free(argv);

        try self.parse(argv, std.io.getStdOut());
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

    fn isEnd(self: *const Self) bool {
        return self.offset < self.argv.len;
    }

    fn hasLongOption(self: *const Self) bool {
        if (self.isEnd()) {
            return false;
        }

        return std.mem.startsWith(u8, self.peek().?, "--");
    }

    fn hasShortOption(self: *const Self) bool {
        if (self.isEnd()) {
            return false;
        }

        // The caller should check that first.
        std.debug.assert(!self.hasLongOption());

        return std.mem.startsWith(u8, self.peek().?, "-");
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
