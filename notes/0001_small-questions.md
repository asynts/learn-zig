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

-   Why do people make the `global_memory_allocator` a global variable?
    I would put it into `main` instead?!

-   Is it possible to mark an entire function as `comptime`?

-   Is there anything like `@must` to unwrap an error or panic?
    I suspect that `orelse unreachable` is meant for that?
    Does that provide a proper error trace?

-   What does `union(enum)` do?
    Does this allow me to drop the redundant enums?

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

-   Question: How can we evaluate an expression in a condition with at comptime?

    Answer: Adding a `comptime` prefix works:
    ```zig
    if (comptime foo()) {
        // ...
    }
    ```
