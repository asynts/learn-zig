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

    var tests = b.addTest("src/asynts_template/lib.zig");
    tests.setTarget(target);
    tests.setBuildMode(mode);

    var test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);
}
