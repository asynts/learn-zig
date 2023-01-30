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

### Closed

-   What are the general naming conventions for `snake_case` and `camelCase`?

    Answer: There is an official style guide: https://ziglang.org/documentation/0.10.1/#Style-Guide
    This was pointed out by Prajwal here: https://github.com/asynts/learn-zig/commit/0daee1ebc4bd6cbd5345bf96378e1aaef778c916#r98425724

-   How to check if an optional has a value without unwrapping it:

    ```zig
    if (foo_opt) |_| {
        // something
    }
    ```

    Or something like this:

    ```zig
    if (foo_opt) |_| {
        // nothing
    } else {
        // Exit early if null.
        return;
    }
    ```

    Answer: We can simply check for `null`:

    ```zig
    if (foo_opt == null) {
        return;
    }
    ```
