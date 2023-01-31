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

### Tasks

-   Look if this issue can be reproduced in the trunk compiler.

-   Look if there is already an open issue about this.
