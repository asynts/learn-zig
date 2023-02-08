### Notes

-   The following snippet crashes the compiler:

    ```zig
    const std = @import("std");

    fn handle(x: anytype) !x {
        try std.io.getStdOut().writer().print("Hello, {any}\n", .{ x });
        return x;
    }

    pub fn main() !void {
        _ = try handle(error.Example);
    }
    ```

    ```none
    foo.zig:3:24: error: expected type 'type', found 'error{Example}'
    fn handle(x: anytype) !x {
                        ^
    thread 6383 panic: Zig compiler bug: attempted to destroy declaration with an attached error
    Unable to dump stack trace: debug info stripped
    Aborted (core dumped)
    ```
