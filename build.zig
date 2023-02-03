const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var ls_exe = b.addExecutable("ls", "src/bin/ls.zig");
    ls_exe.setTarget(target);
    ls_exe.setBuildMode(mode);
    ls_exe.addPackagePath("asynts-argparse", "src/asynts_argparse.zig");
    ls_exe.install();

    var ls_with_yazap_exe = b.addExecutable("ls-with-yazap", "src/bin/ls_with_yazap.zig");
    ls_with_yazap_exe.setTarget(target);
    ls_with_yazap_exe.setBuildMode(mode);
    ls_with_yazap_exe.addPackagePath("yazap", "libs/yazap/src/lib.zig");
    ls_with_yazap_exe.install();

    var asynts_template_lib = b.addStaticLibrary("asynts-template", "src/asynts_template/lib.zig");
    asynts_template_lib.setTarget(target);
    asynts_template_lib.setBuildMode(mode);
    asynts_template_lib.install();

    var blog_exe = b.addExecutable("blog", "src/bin/blog.zig");
    blog_exe.setTarget(target);
    blog_exe.setBuildMode(mode);
    blog_exe.addPackagePath("asynts-template", "src/asynts_template/lib.zig");
    blog_exe.install();

    var source_files = [_][]const u8{
        "src/asynts_template/common.zig",
        "src/asynts_template/escape.zig",
        "src/asynts_template/Lexer.zig",
        "src/asynts_template/lib.zig",
        "src/asynts_template/Parser.zig",
    };

    var test_step = b.step("test", "Run library tests");
    for (source_files) |source_file| {
        var tests = b.addTest(source_file);
        tests.setTarget(target);
        tests.setBuildMode(mode);

        test_step.dependOn(&tests.step);
    }
}
