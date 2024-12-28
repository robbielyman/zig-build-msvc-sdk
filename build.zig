const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const xwin_output_directory = b.option([]const u8, "xwin_output_directory", "where the output of xwin is stored") orelse ".xwin";
    const xwin_out_directory_lazy_path = b.path(xwin_output_directory);
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

    const write_libc_file = b.addNamedWriteFiles("msvc_libc");
    _ = write_libc_file.add("libc.txt", data);
    for (steps) |step| write_libc_file.step.dependOn(step);
}
