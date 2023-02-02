const std = @import("std");
const asynts_template = @import("asynts-template");

const Blog = struct {
    const Self = @This();

    title: []const u8,
    entries: []const Entry,

    fn generateHtml(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("title", self.title);
        try variables.put("entries_html", "FIXME");

        // FIXME: This code is very redundant.
        var entries_html = std.ArrayList(u8).init(allocator);
        defer entries_html.deinit();
        for (self.entries) |entry| {
            var entry_html = try entry.generateHtml(allocator);
            defer allocator.free(entry_html);

            try entries_html.appendSlice(entry_html);
        }
        try variables.put("entries_html", entries_html.items);

        return try asynts_template.Parser.evaluate(
            allocator,
            \\<html>
            \\    <head>
            \\        <meta charset="utf-8"></meta>
            \\        <title>{title}</title>
            \\    </head>
            \\    <body>
            \\        <h1>{title}</h1>
            \\        <div>
            \\            {entries_html:html}
            \\        </div>
            \\    </body>
            \\</html>
            \\
            ,
            &variables,
        );
    }
};

const Entry = struct {
    const Self = @This();

    author: []const u8,
    title: []const u8,
    contents: []const u8,
    tags: []const []const u8,
    comments: []const Comment,

    fn generateHtml(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("title", self.title);
        try variables.put("author", self.author);
        try variables.put("contents", self.contents);

        // FIXME: This code is very redundant.
        var tags_html = std.ArrayList(u8).init(allocator);
        defer tags_html.deinit();
        for (self.tags) |tag| {
            var variables_2 = std.StringHashMap([]const u8).init(allocator);
            defer variables_2.deinit();

            try variables_2.put("tag", tag);

            var tag_html = try asynts_template.Parser.evaluate(
                allocator,
                \\<div>{tag}</div>
                \\
                ,
                &variables_2
            );
            defer allocator.free(tag_html);

            try tags_html.appendSlice(tag_html);
        }
        try variables.put("tags_html", tags_html.items);

        // FIXME: This code is very redundant.
        var comments_html = std.ArrayList(u8).init(allocator);
        defer comments_html.deinit();
        for (self.comments) |comment| {
            var comment_html = try comment.generateHtml(allocator);
            defer allocator.free(comment_html);

            try comments_html.appendSlice(comment_html);
        }
        try variables.put("comments_html", comments_html.items);

        return try asynts_template.Parser.evaluate(
            allocator,
            \\<div>
            \\    <h2>{title} (by {author})</h2>
            \\    <div>
            \\        {tags_html:html}
            \\    </div>
            \\    <div>
            \\        {contents}
            \\    </div>
            \\    <div>
            \\        {comments_html:html}
            \\    </div>
            \\</div>
            \\
            ,
            &variables,
        );
    }
};

const Comment = struct {
    const Self = @This();

    author: []const u8,
    contents: []const u8,
    comments: []const Comment,

    fn generateHtml(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("author", self.author);
        try variables.put("contents", self.contents);

        // FIXME: This code is very redundant.
        var comments_html = std.ArrayList(u8).init(allocator);
        defer comments_html.deinit();
        for (self.comments) |comment| {
            var comment_html = try comment.generateHtml(allocator);
            defer allocator.free(comment_html);

            try comments_html.appendSlice(comment_html);
        }
        try variables.put("comments_html", comments_html.items);

        return try asynts_template.Parser.evaluate(
            allocator,
            \\<div>
            \\    <div>{contents} &mdash; {author}</div>
            \\    <div>{comments_html:html}</div>
            \\</div>
            \\
            ,
            &variables
        );
    }
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

    var result = try blog.generateHtml(allocator);
    defer allocator.free(result);
    std.debug.print("{s}", .{ result });
}
