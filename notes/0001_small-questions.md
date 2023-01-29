### Open

-   How to use `std.debug.print` with a boolean?

-   How to access the last element of `std.ArrayList`?

-   Why is `std.ascii.startsWithCaseInsensitive` not listed in the API documentation?
    This seems to apply to other functions as well.

    It seems what I was looking at was for an older version of Zig.

-   How to I make sure that the errors overlap with error names from other libraries?

-   How to return error from failable function as normal value?

-   What are the general naming conventions for `snake_case` and `camelCase`?

-   I don't like `anytype`.
    Concepts were added to C++ for a reason.

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

-   What should I use instead of `std.debug.print` when I want to handle errors?
