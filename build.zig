const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    var ls_exe = b.addExecutable("ls", "src/bin/ls.zig");
    ls_exe.setTarget(target);
    ls_exe.setBuildMode(mode);
    ls_exe.addPackagePath("asynts-argparse", "src/asynts-argparse.zig");
    ls_exe.install();

    var ls_with_yazap_exe = b.addExecutable("ls-with-yazap", "src/bin/ls-with-yazap.zig");
    ls_with_yazap_exe.setTarget(target);
    ls_with_yazap_exe.setBuildMode(mode);
    ls_with_yazap_exe.addPackagePath("yazap", "libs/yazap/src/lib.zig");
    ls_with_yazap_exe.install();
}
