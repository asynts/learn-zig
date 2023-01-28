const std = @import("std");

// FIXME: Find a better name for this library.

pub const ValueEnum = enum {
    boolean,
    string,
};
pub const Value = union(ValueEnum) {
    boolean: bool,
    string: []const u8,
};

// FIXME: Find a better name for this.
pub const Namespace = struct {
    const Self = @This();

    values: std.StringHashMap(Value),

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

    // There are multiple 'Option' objects representing the same option.
    options: std.ArrayList(Option),
    long_options: std.StringHashMap(Option),
    short_options: std.StringHashMap(Option),

    positional_arguments: std.ArrayList(),

    pub fn init(allocator: std.mem.Allocator) Self {
        // FIXME: Add help option here.
        //        Use a special action to print help page.

        return Self{
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

    // FIXME: How can I report errors with this API?
    //        Maybe add an 'parse_impl' method that takes a buffer writer object.
    //        Then there is a normal 'parse(self: *const Self) !Namespace' method.
    pub fn parse(self: *const Self, argv: [][]const u8) !Namespace {
        // FIXME
        _ = self;
        _ = argv;
        @panic("not implemented");
    }
};
