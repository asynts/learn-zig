### Notes

-   This would be used to generate HTML that is served to the end user.

-   I could use heredocs to implement this.

-   Example:

    ```zig
    generate(
        .{
            .text = "Hello, world!"
        },
        \\<div class="Page">
        \\  <p>{text}</p>
        \\</div>
    )
    ```
