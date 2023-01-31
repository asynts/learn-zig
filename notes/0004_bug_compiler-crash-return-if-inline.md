### Notes

-   This code was originally found in Yazap.

-   This is a minimal example that crashes the 0.10.1 compiler:

    ```zig
    const std = @import("std");

    const Braces = std.meta.Tuple(&[2]type{ u8, u8 });

    inline fn foo() Braces {
        return if (true) .{ '<', '>' } else .{ '[', ']' };
    }

    pub fn main() void {
        var braces = foo();
        std.debug.print("{}\n", .{ braces[0] });
    }
    ```

    ```none
    zig build-exe ./foo.zig
    ```

-   This snippet also reproduces the crash:
    ```zig
    const std = @import("std");

    const Braces2 = struct {
        lhs: u8,
    };

    inline fn foo() Braces2 {
        return if (true) .{ .lhs = '<' } else .{ .lhs = '[' };
    }

    pub fn main() void {
        var braces = foo();
        std.debug.print("{}\n", .{ braces.lhs });
    }
    ```

-   This bug seems to be resolved in `trunk`.

-   I was not able to find a matching issue.

-   I could bisect this but I am too lazy.
