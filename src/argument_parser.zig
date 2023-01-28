const std = @import("std");

pub const ArgumentType = enum {
    // FIXME: I don't think this should be called 'boolean', maybe 'flag'?
    boolean,
    string,
};

pub const Argument = struct {
    name: []const u8,
    short_name: ?u8,
    type_: ArgumentType,
};

pub const ParseOutput = struct {
    const Self = @This();

    // FIXME: I want something like python where you have a key and value.
    //        Thus multiple options can write the same value?
    flags: std.StringHashMap(bool),
    strings: std.StringHashMap([]const u8),

    // FIXME: I don't like unwrapping the value here.
    pub fn isFlagSet(self: *const Self, name: []const u8) !bool {
        return self.flags.get(name).?;
    }

    pub fn getStringValue(self: *const Self, name: []const u8) ?[]const u8 {
        return self.strings.get(name);
    }
};

pub const ArgumentParser = struct {
    const Self = @This();

    // FIXME: This is suboptimal.
    //        Everything should be an argument.
    //        We must ensure that there are no duplicates.
    arguments: std.StringHashMap(Argument),
    positional_arguments: std.ArrayList([]const u8),

    pub fn init() Self {
        ArgumentParser{};
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn add_argument(self: *Self, argument: Argument) !void {
        try self.arguments.put(argument.long_name, argument);
    }

    pub fn add_positional_argument(self: *Self, name: []const u8) !void {
        try self.positional_arguments.append(name);
    }

    pub fn parse(self: *const Self) !ParseOutput {
        // FIXME
        _ = self;
        @panic("not implemented");
    }
};
