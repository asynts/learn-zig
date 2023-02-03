### Notes

-   In Visual Studio it is possible to declare an example type in C++ templates.
    It would be nice if this is possible in Zig:

    ```zig
    fn foo(writer: anytype) !void {
        @exampleType(writer, std.fs.File);

        writer.print("Hello, world!\n", .{});
    }
    ```

    ```zig
    fn foo(comptime T: type, lhs: T, rhs: T) T {
        @exampleType(T, usize);

        return lhs + rhs;
    }
    ```
