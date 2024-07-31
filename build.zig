const std = @import("std");
const builtin = std.builtin;
const Build = std.Build;

pub fn build(b: *Build) !void {
    const version = try std.SemanticVersion.parse("0.5.2");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const md2html_step = b.step("md2html", "builds md2html");

    const shared_libs_opt = switch (target.result.os.tag) {
        // On Windows, given there is no standard lib install dir etc., we rather
        // by default build static lib.
        .windows => false,
        else => b.option(
            bool,
            "build_shared",
            "Build shared libraries",
        ) orelse true, // On Linux, MD4C is slowly being adding into some distros which prefer shared lib.
    };

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();
    if (optimize == .Debug) try flags.append("-DDEBUG");

    try flags.append("-DMD4C_USE_UTF8");
    const md4c_lib = if (shared_libs_opt) b.addSharedLibrary(.{
        .name = "md4c",
        .target = target,
        .optimize = optimize,
        .version = version,
    }) else b.addStaticLibrary(.{
        .name = "md4c",
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    md4c_lib.addCSourceFile(.{
        .file = b.path("src/md4c.c"),
        .flags = flags.items,
    });
    md4c_lib.addIncludePath(b.path("src/"));
    md4c_lib.installHeader(b.path("src/md4c.h"), "md4c.h");

    const md4c_html_lib = if (shared_libs_opt) b.addSharedLibrary(.{
        .name = "md4c-html",
        .target = target,
        .optimize = optimize,
        .version = version,
    }) else b.addStaticLibrary(.{
        .name = "md4c-html",
        .target = target,
        .optimize = optimize,
        .version = version,
    });
    _ = flags.pop();
    md4c_html_lib.addCSourceFiles(.{
        .files = &.{
            "src/md4c-html.c",
            "src/entity.c",
        },
        .flags = flags.items,
    });
    md4c_html_lib.linkLibrary(md4c_lib);
    md4c_html_lib.addIncludePath(b.path("src"));
    md4c_html_lib.installHeader(b.path("src/md4c-html.h"), "md4c-html.h");

    md2html_step.dependOn(&md4c_lib.step);
    md2html_step.dependOn(&md4c_html_lib.step);

    b.installArtifact(md4c_lib);
    b.installArtifact(md4c_html_lib);

    const md2html_exe = b.addExecutable(.{
        .name = "md2html",
        .target = target,
        .optimize = optimize,
    });
    md2html_exe.addCSourceFiles(.{
        .files = &.{
            "md2html/md2html.c",
            "md2html/cmdline.c",
        },
        .flags = flags.items,
    });
    md2html_exe.linkLibrary(md4c_lib);
    md2html_exe.linkLibrary(md4c_html_lib);
    md2html_exe.defineCMacro(
        "MD_VERSION_MAJOR",
        try std.fmt.allocPrint(b.allocator, "{}", .{version.major}),
    );
    md2html_exe.defineCMacro(
        "MD_VERSION_MINOR",
        try std.fmt.allocPrint(b.allocator, "{}", .{version.minor}),
    );
    md2html_exe.defineCMacro(
        "MD_VERSION_RELEASE",
        try std.fmt.allocPrint(b.allocator, "{}", .{version.patch}),
    );

    const md2html_artifact = b.addInstallArtifact(
        md2html_exe,
        .{
            .dest_dir = .default,
            .dest_sub_path = "md2html/md2html",
        },
    );
    const manpage = b.addInstallFile(b.path("md2html/md2html.1"), "man1");
    md2html_artifact.step.dependOn(&manpage.step);
    md2html_step.dependOn(&md2html_artifact.step);

    const run_exe = b.addRunArtifact(md2html_artifact.artifact);
    const run_step = b.step("run", "run md2html");
    if (b.args) |args| run_exe.addArgs(args);
    run_step.dependOn(&run_exe.step);
}
