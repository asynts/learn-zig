### Open

-   How to use `std.debug.print` with a boolean?

-   Why is `std.ascii.startsWithCaseInsensitive` not listed in the API documentation?
    This seems to apply to other functions as well.

    It seems what I was looking at was for an older version of Zig.

-   How to I make sure that the errors overlap with error names from other libraries?

-   How to return error from failable function as normal value?

-   I don't like `anytype`.
    Concepts were added to C++ for a reason.

    -   Can we use `comptime` functions to define constraints for type parameters?

-   What should I use instead of `std.debug.print` when I want to handle errors?

-   How to return errors as values?

    ```zig
    fn createError() !error {
        // ???
    }
    ```

-   Does `std.fmt.format` support type erasure or is this like inlining in fmtlib?

-   Why do people make the `global_memory_allocator` a global variable?
    I would put it into `main` instead?!

-   Is it possible to mark an entire function as `comptime`?

-   Is there anything like `@must` to unwrap an error or panic?
    I suspect that `orelse unreachable` is meant for that?
    Does that provide a proper error trace?

-   How to register the tests in multiple or all files.
    Currently, I need to do something like this:

    ```zig
    var tests_1 = b.addTest("src/asynts_template/lib.zig");
    tests_1.setTarget(target);
    tests_1.setBuildMode(mode);

    var tests_2 = b.addTest("src/asynts_template/Parser.zig");
    tests_2.setTarget(target);
    tests_2.setBuildMode(mode);

    var test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests_1.step);
    test_step.dependOn(&tests_2.step);
    ```

    -   It seems to automatically grab tests in all other included files.
        However, this seems to be a bit inconsistent, I should verify this.

-   How does Zig handle compilation units in general, what can be compiled in parallel.
    Does `build.zig` use parallelism?

-   How to test if something is an error without checking for explicit error?

-   Is there something like an efficient string builder?

-   Why does the following not work?

    ```zig
    fn foo(comptime T: type) {

    }

    fn bar() {
        // It does work with 'u8' though.
        foo(const u8);
    }
    ```

    Why is `const X` not considered a valid type?

-   Somehow, if I use a recursive function that returns an error, I need to use `anyerror!` why is that?
    What does it do?

-   How to add an existing library as package in `build.zig`?

-   How to propagate error information to the caller.

    -   There seems to be a proposal for `union(error)` which seems to address this issue, but that's still early.

    -   It would also be interesting if there is some way to get access to the AST of a `comptime` parameter.
        That would allow generating proper error messages that could be feed into `@compileError`.

-   Suppose, I fix a bug where an error wasn't handled correctly.
    In Zig that would be a breaking change, since the error enum changes.

    -   Is this good or bad, I can't tell?

-   How to associate values with an error in Zig?

    -   For example the line and column numbers.
        Can this be integrated into the `try` syntax?

    -   https://github.com/ziglang/zig/issues/2647

### Closed

-   Question: What are the general naming conventions for `snake_case` and `camelCase`?

    -   There is an official style guide: https://ziglang.org/documentation/0.10.1/#Style-Guide
        This was pointed out by Prajwal here: https://github.com/asynts/learn-zig/commit/0daee1ebc4bd6cbd5345bf96378e1aaef778c916#r98425724

-   Question: How to check if an optional has a value without unwrapping it?

    -   We can simply check for `null`:
        ```zig
        if (foo_opt == null) {
            return;
        }
        ```

-   Question: How can we evaluate an expression in a condition with at comptime?

    -   Adding a `comptime` prefix works:
        ```zig
        if (comptime foo()) {
            // ...
        }
        ```

-   Question: How to access the last element of `std.ArrayList`?

    -   The function is called `getLast` or `getLastOrNull`.

-   Question: What does `union(enum)` do?

    -   It allows us to use it in a switch case:
        ```zig
        const Foo = union(enum) {
            x: i32,
            y: f32,
        };
        fn example(foo: Foo) void {
            switch (foo) {
                .x => std.debug.print("integer\n", .{}),
                .y => std.debug.print("float\n", .{}),
            }
        }
        ```
        This can not be done with `union` alone.

-   Question: When is `pub` applicable, in a compilation unit?

    -   It makes the declaration avaliable to reference from a different file than it is declared in.

-   Question: How do the `*Z` functions in the standard library differ?

    -   These functions accept zero terminated strings.

-   Question: How to do polymorphism with Zig?

    -   Simply manually create a vtable and put it into the structure.
        Very similar how I would implement this in C.

    -   `std.mem.Allocator` uses this exact pattern:

        https://github.com/ziglang/zig/blob/03cdb4fb5853109e46bdc08d8a849a23780093ae/lib/std/mem/Allocator.zig

-   Questions: Is it possible to allocate memory during `comptime` with `std.heap.FixedBufferAllocator`?

    -   The implementation of `std.mem.Allocator` uses `@returnAddress` everywhere.
        That can not work at compile time.

    -   This may be resolved in 0.11.0 but it hasn't been implemented yet.

-   Question: How to deal with optional-optional values, e.g. when forwarding values from another function call?

    -   This can be done by first assigning it to a value:

        ```zig
        fn foo_1() ??i32 {
            // Return inner null.
            var value: ?i32 = null;
            return value;
        }

        fn foo_2() ??i32 {
            // Return outer null.
            return null;
        }
        ```

-   Question: How to do dependency injection in Zig?

    -   This can be done by using templates:

        ```zig
        fn ExampleServiceImpl(comptime LogService: type) type {
            // ...
        }

        const ExampleService = ExampleServiceImpl(LogService);
        ```

    -   If necessary, this can be done by manually creating a structure of function pointers that is kept along or inside the structure.
        This is done in the `std.mem.Allocator` implementation.
