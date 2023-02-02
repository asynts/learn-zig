const std = @import("std");
const asynts_template = @import("asynts-template");

const Blog = struct {
    title: []const u8,
    entries: []const Entry,
};

const Entry = struct {
    author: []const u8,
    title: []const u8,
    contents: []const u8,
    tags: []const []const u8,
    comments: []const Comment,
};

const Comment = struct {
    author: []const u8,
    contents: []const u8,
    comments: []const Comment,
};

var gpa = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
}){};

pub fn main() !void {
    var allocator = gpa.allocator();
    defer if (gpa.deinit()) @panic("memory leak");

    var blog = Blog{
        .title = "Example Blog",
        .entries = &[_]Entry{
            Entry{
                .author = "Alice",
                .title = "Hello, world!",
                .contents =
                    \\Have a nice day.
                    \\
                ,
                .tags = &[_][]const u8{
                    "hello",
                },
                .comments = &[_]Comment{
                    Comment{
                        .author = "Bob",
                        .contents =
                            \\You too!
                        ,
                        .comments = &[_]Comment{},
                    },
                },
            },
            Entry{
                .author = "Bob",
                .title = "<script>alert(1)</script>",
                .contents =
                    \\<script>alert(2)</script>
                    \\{title:trusted}
                    \\&lt;script&gt;alert(3)&lt;/script&gt;
                    \\
                ,
                .tags = &[_][]const u8{
                    "exploit",
                    "xss",
                },
                .comments = &[_]Comment{
                    Comment{
                        .author = "Bob",
                        .contents =
                            \\Fuck, it didn't work"
                            ,
                        .comments = &[_]Comment{
                            Comment{
                                .author = "Alice",
                                .contents =
                                    \\You have been banned
                                    \\
                                ,
                                .comments = &[_]Comment{},
                            },
                        },
                    },
                },
            },
        },
    };

    _ = blog;

    var result = try asynts_template.Parser.evaluate(
        allocator,
        \\<div>
        \\    Hello, world!
        \\</div>
        \\
        ,
        null,
    );
    defer allocator.free(result);
    std.debug.print("{s}", .{ result });
}
