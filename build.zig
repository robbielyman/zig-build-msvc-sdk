const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const sdk_version = b.option([]const u8, "sdk_version", "which version of the MSVC to install") orelse "10.0.20348";

    const xwin_output_directory = b.option([]const u8, "xwin_output_directory", "where xwin should splat its output") orelse ".xwin";
    // TODO: manage installation of xwin via zig build?
    // const cargo_install_xwin = b.addSystemCommand(&.{"cargo", "install", "xwin"});
    const xwin_splat = b.addSystemCommand(&.{
        "xwin",      "--accept-license",     "--arch",                  "x86_64,aarch64",
        "--variant", "desktop",              "--sdk-version",           sdk_version,
        "splat",     "--include-debug-libs", "--include-debug-symbols", "--preserve-ms-arch-notation",
        "--output",
    });
    const xwin_out_directory_lazy_path = xwin_splat.addOutputDirectoryArg(xwin_output_directory);
    const install_include_dir = b.addInstallDirectory(.{
        .source_dir = xwin_out_directory_lazy_path.path(b, "sdk/include"),
        .install_dir = .{ .custom = "sdk" },
        .install_subdir = "include",
    });
    const install_xwin_headers = b.addInstallDirectory(.{
        .source_dir = xwin_out_directory_lazy_path.path(b, "crt/include"),
        .install_dir = .header,
        .install_subdir = "",
    });
    const install_xwin_lib = b.addInstallDirectory(.{
        .source_dir = xwin_out_directory_lazy_path.path(b, "crt/lib"),
        .install_dir = .lib,
        .install_subdir = "",
    });
    const install_xwin_kernel_lib = b.addInstallDirectory(.{
        .source_dir = xwin_out_directory_lazy_path.path(b, "sdk/lib"),
        .install_dir = .{ .custom = "sdk" },
        .install_subdir = "lib",
    });

    const steps: []const *std.Build.Step = &.{
        &install_include_dir.step,
        &install_xwin_headers.step,
        &install_xwin_lib.step,
        &install_xwin_kernel_lib.step,
    };

    const arch: []const u8 = switch (target.result.cpu.arch) {
        .aarch64 => "arm64",
        .x86_64 => "x64",
        else => "x64",
    };

    const data = try std.fmt.allocPrint(
        b.allocator,
        \\# The directory that contains `stdlib.h`.
        \\include_dir={s}
        \\
        \\# On Windows it's the directory that includes `vcruntime.h`.
        \\sys_include_dir={s}
        \\
        \\crt_dir={s}
        \\
        \\# The directory that contains `vcruntime.lib`.
        \\msvc_lib_dir={s}
        \\
        \\# The directory that contains `kernel32.lib`.
        \\kernel32_lib_dir={s}
        \\
        \\gcc_dir=
    ,
        .{
            try std.fs.path.join(b.allocator, &.{
                b.install_prefix,
                "sdk",
                "include",
                "ucrt",
            }),
            try std.fs.path.join(b.allocator, &.{
                b.install_prefix,
                "include",
            }),
            try std.fs.path.join(b.allocator, &.{
                b.install_prefix,
                "sdk",
                "lib",
                "ucrt",
                arch,
            }),
            try std.fs.path.join(b.allocator, &.{
                b.install_prefix,
                "lib",
                arch,
            }),
            try std.fs.path.join(b.allocator, &.{
                b.install_prefix,
                "sdk",
                "lib",
                "um",
                arch,
            }),
        },
    );

    const write_libc_file = b.addWriteFile("libc.txt", data);
    const libc_file = write_libc_file.getDirectory().path(b, "libc.txt");
    for (steps) |step| write_libc_file.step.dependOn(step);

    const lib = b.addStaticLibrary(.{
        .target = target,
        .name = "xwin",
        .optimize = optimize,
        .root_source_file = b.path("xwin.zig"),
    });

    if (target.result.abi != .msvc or target.query.isNative()) return;

    lib.step.dependOn(&write_libc_file.step);
    lib.libc_file = libc_file;
    lib.linkLibC();
    b.installArtifact(lib);
}
