const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const update_database = b.addExecutable(.{
        .name = "update-database",
        .root_source_file = b.path("src/update_database.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(update_database);

    const run_update_datbase_cmd = b.addRunArtifact(update_database);
    run_update_datbase_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_update_datbase_cmd.addArgs(args);
    }

    const run_update_datbase_step = b.step("update-database", "Update the database with new fuzzing results");
    run_update_datbase_step.dependOn(&run_update_datbase_cmd.step);

    const generate_website = b.addExecutable(.{
        .name = "generate-website",
        .root_source_file = b.path("src/generate_website.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(generate_website);

    const run_generate_website_cmd = b.addRunArtifact(generate_website);
    run_generate_website_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_generate_website_cmd.addArgs(args);
    }

    const run_generate_website_step = b.step("generate-website", "Update the website based on the contents of the datbase");
    run_generate_website_step.dependOn(&run_generate_website_cmd.step);
}
