const std = @import("std");

pub fn build(b: *std.Build) void {
    const target   = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("betterkhmer", .{
        .root_source_file = b.path("src/betterkhmer.zig"),
        .target           = target,
        .optimize         = optimize,
    });
    mod.linkSystemLibrary("pcre2-8", .{});
    mod.link_libc = true;

    const test_exe = b.addExecutable(.{
        .name            = "test_normalize",
        .root_source_file = b.path("test/test_normalize.zig"),
        .target          = target,
        .optimize        = optimize,
    });
    test_exe.root_module.addImport("betterkhmer", mod);
    b.installArtifact(test_exe);

    const run = b.addRunArtifact(test_exe);
    if (b.args) |args| run.addArgs(args);

    const test_step = b.step("test", "Run fixture tests");
    test_step.dependOn(&run.step);
}
