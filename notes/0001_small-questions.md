### Open

-   How to use `std.debug.print` with a boolean?

-   How to access the last element of `std.ArrayList`?

-   Why is `std.ascii.startsWithCaseInsensitive` not listed in the API documentation?
    This seems to apply to other functions as well.

    It seems what I was looking at was for an older version of Zig.

-   How to I make sure that the errors overlap with error names from other libraries?

-   How to return error from failable function as normal value?

-   I don't like `anytype`.
    Concepts were added to C++ for a reason.

-   What should I use instead of `std.debug.print` when I want to handle errors?

-   How to return errors as values?

    ```zig
    fn createError() !error {
        // ???
    }
    ```

-   Does `std.fmt.format` support type erasure or is this like inlining in fmtlib?

-   Can we use `comptime` functions to define constraints for type parameters?

-   How can we evaluate an expression in a condition with at comptime?

    Example:
    ```zig
    comptime var condition: bool = undefined;
    comptime {
        condition = foo();
    }
    if (condition) {
        // ...
    }
    ```

    I tried making the `self` parameter `comptime` for a struct:
    ```zig
    struct {
        fn foo(comptime self: *Self) {
            // ...
        }
    }
    ```
    However, that did not help.

    Answer: Adding a `comptime` prefix works:

    ```zig
    if (comptime foo()) {
        // ...
    }
    ```

### Closed

-   Question: What are the general naming conventions for `snake_case` and `camelCase`?

    Answer: There is an official style guide: https://ziglang.org/documentation/0.10.1/#Style-Guide
    This was pointed out by Prajwal here: https://github.com/asynts/learn-zig/commit/0daee1ebc4bd6cbd5345bf96378e1aaef778c916#r98425724

-   Question: How to check if an optional has a value without unwrapping it?

    Answer: We can simply check for `null`:
    ```zig
    if (foo_opt == null) {
        return;
    }
    ```
