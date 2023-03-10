const std = @import("std");
const asynts_template = @import("asynts-template");

// FIXME: This could be done more efficiently with a writer.
fn mapSliceToHtml(allocator: std.mem.Allocator, comptime T: type, slice: []const T) anyerror![]const u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var writer = buffer.writer();

    for (slice) |entry| {
        try entry.writeHtml(writer, allocator);
    }

    return buffer.toOwnedSlice();
}

const Blog = struct {
    const Self = @This();

    title: []const u8,
    entries: []const Entry,

    fn writeHtml(self: *const Self, writer: anytype, allocator: std.mem.Allocator) !void {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("title", self.title);
        try variables.put("entries_html", "FIXME");
        try variables.put("style_css",
            \\div {
            \\    margin: 1px;
            \\    padding: 1px;
            \\    border: 1px solid black;
            \\}
            \\
        );

        var entries_html = try mapSliceToHtml(allocator, Entry, self.entries);
        defer allocator.free(entries_html);
        try variables.put("entries_html", entries_html);

        try asynts_template.evaluate(
            writer,
            \\<html>
            \\    <head>
            \\        <meta charset="utf-8" />
            \\        <title>{title}</title>
            \\        <style>{style_css:trusted}</style>
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

    fn toHtmlOwned(self: *const Self, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        var writer = buffer.writer();

        try self.writeHtml(writer, allocator);

        return buffer.toOwnedSlice();
    }
};

const Entry = struct {
    const Self = @This();

    author: []const u8,
    title: []const u8,
    contents: []const u8,
    tags: []const Tag,
    comments: []const Comment,

    fn writeHtml(self: *const Self, writer: anytype, allocator: std.mem.Allocator) !void {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("title", self.title);
        try variables.put("author", self.author);
        try variables.put("contents", self.contents);

        var tags_html = try mapSliceToHtml(allocator, Tag, self.tags);
        defer allocator.free(tags_html);
        try variables.put("tags_html", tags_html);

        var comments_html = try mapSliceToHtml(allocator, Comment, self.comments);
        defer allocator.free(comments_html);
        try variables.put("comments_html", comments_html);

        try asynts_template.evaluate(
            writer,
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

    fn writeHtml(self: *const Self, writer: anytype, allocator: std.mem.Allocator) !void {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("author", self.author);
        try variables.put("contents", self.contents);

        var comments_html = try mapSliceToHtml(allocator, Comment, self.comments);
        defer allocator.free(comments_html);
        try variables.put("comments_html", comments_html);

        try asynts_template.evaluate(
            writer,
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

const Tag = struct {
    const Self = @This();

    name: []const u8,

    fn writeHtml(self: *const Self, writer: anytype, allocator: std.mem.Allocator) !void {
        var variables = std.StringHashMap([]const u8).init(allocator);
        defer variables.deinit();

        try variables.put("name", self.name);

        try asynts_template.evaluate(
            writer,
            \\<div>{name}</div>
            \\
            ,
            &variables,
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
                .tags = &[_]Tag{
                    Tag{ .name = "hello" },
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
                .tags = &[_]Tag{
                    Tag{ .name = "exploit" },
                    Tag{ .name = "xss" },
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

    var result = try blog.toHtmlOwned(allocator);
    defer allocator.free(result);
    std.debug.print("{s}", .{ result });
}
