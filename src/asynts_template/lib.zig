const std = @import("std");

const expect = std.testing.expect;

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
    pub fn run(self: *const Self, arguments: anytype, inputTemplate: []const u8) ![]const u8 {
        _ = arguments;

        // FIXME: Actually parse the input string.

        return self.allocator.dupe(u8, inputTemplate);
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
