My goal is to implement a few simple tools in Zig to get familiar with the syntax.
I was thinking about `ls`, `tree`, `tar`, `jail` and `jq`.

### Development Environment

-   Install Visual Studio Code

-   Install `augusterame.zls-vscode` extension.

-   Install `zig` package in Arch Linux.

-   Currently, I am using a custom build of `zig` with whatever `zls` the extension installs.

### asynts_template

This is a project I created to play around with Zig a bit.
I don't think that this should be used by anyone for anything.

My original goal was to parse HTML templates at comptime and then to prepare a sequence of instructions
that can be executed efficiently at runtime.

-   However, it's extremely difficult to securely escape HTML.
    In a static context this is essentially impossible due to parser differentials.

-   HTML is a mess with a ton of edge cases.
    Since I was just playing around with this, I don't want to deal with all the edge cases.

-   Currently, Zig does not support allocations at comptime, not even with `std.heap.FixedBufferAllocator`.

Maybe, I'll come back to this project when support for comptime allocations has been added.
Probably, I will never get this project to a "production" state though.
