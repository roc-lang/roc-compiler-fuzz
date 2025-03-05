const std = @import("std");
const FuzzResult = @import("FuzzResult.zig");

const result_limit = 20;

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    var arena_impl = std.heap.ArenaAllocator.init(gpa);
    defer arena_impl.deinit();
    const arena = arena_impl.allocator();

    const args = try std.process.argsAlloc(arena);
    if (args.len != 4) {
        std.debug.print(
            \\ Expected usage:
            \\ ./app ROC_REPO_PATH FUZZER_NAME FUZZ_OUTPUT_PATH
            \\
        , .{});
        std.process.exit(1);
    }

    const roc_repo_path = args[1];
    const fuzzer_name = args[2];
    const fuzz_output_path = args[3];

    var roc_repo_dir = std.fs.cwd().openDir(roc_repo_path, .{}) catch {
        std.debug.print("unable to find roc repo directory: {s}\n", .{roc_repo_path});
        std.process.exit(1);
    };
    defer roc_repo_dir.close();

    const branch = try run_cmd(arena, roc_repo_dir, &[_][]const u8{ "git", "branch", "--show-current" });
    const commit_sha = try run_cmd(arena, roc_repo_dir, &[_][]const u8{ "git", "show", "--no-patch", "--format=%H" });
    const commit_timestamp_str = try run_cmd(arena, roc_repo_dir, &[_][]const u8{ "git", "show", "--no-patch", "--format=%ct" });
    const commit_timestamp = try std.fmt.parseInt(u64, commit_timestamp_str, 10);

    // load fuzzer stats
    var combined_stats = FuzzerStats{};
    var fuzz_output_dir = try std.fs.cwd().openDir(fuzz_output_path, .{ .iterate = true });
    defer fuzz_output_dir.close();
    {
        var it = fuzz_output_dir.iterate();
        while (try it.next()) |entry| {
            if (try load_fuzzer_stats(arena, fuzz_output_dir, entry)) |stats| {
                if (combined_stats.start_timestamp == 0) {
                    combined_stats.start_timestamp = stats.start_timestamp;
                }
                combined_stats.start_timestamp = @min(combined_stats.start_timestamp, stats.start_timestamp);
                combined_stats.edges_found = @max(combined_stats.edges_found, stats.edges_found);
                combined_stats.total_edges = @max(combined_stats.total_edges, stats.total_edges);
                combined_stats.unique_crashes = @max(combined_stats.unique_crashes, stats.unique_crashes);
                combined_stats.unique_hangs = @max(combined_stats.unique_hangs, stats.unique_hangs);
                combined_stats.total_execs += stats.total_execs;
            }
        }
    }
    if (combined_stats.start_timestamp == 0 or combined_stats.total_execs == 0) {
        std.debug.print("No fuzzer stats where loaded. Maybe the fuzzer failed to run?\n", .{});
        std.process.exit(1);
    }

    // Try `main` and `default` as primary fuzzer names.
    var fuzzer_dir_name: ?[]const u8 = null;
    for (&[_][]const u8{ "main", "default" }) |dir_name| {
        if (fuzz_output_dir.access(dir_name, .{})) |_| {
            fuzzer_dir_name = dir_name;
            break;
        } else |_| {}
    }

    if (fuzzer_dir_name == null) {
        std.debug.print("unable to find main or default fuzzer in output directory: {s}\n", .{fuzz_output_path});
        std.process.exit(1);
    }

    std.debug.print("Found primary fuzzer: {s}\n", .{fuzzer_dir_name.?});

    var hang_results = std.ArrayList(FuzzResult).init(gpa);
    defer hang_results.deinit();
    var crash_results = std.ArrayList(FuzzResult).init(gpa);
    defer crash_results.deinit();
    for (&[_]FuzzResult.Kind{ .crash, .hang }) |kind| {
        const dir_name = if (kind == .crash) "crashes" else "hangs";
        const dir_path = try std.fs.path.join(arena, &.{ fuzzer_dir_name.?, dir_name });
        var dir = try fuzz_output_dir.openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) {
                continue;
            }
            var file = try dir.openFile(entry.name, .{});
            defer file.close();

            // read content ignoring crazy big files
            const content = file.readToEndAlloc(gpa, 1024 * 1024) catch {
                continue;
            };
            defer gpa.free(content);

            // Base64 encode the data to make it copy and paste friendly.
            const base64_size = std.base64.standard.Encoder.calcSize(content.len);
            const buffer = try arena.alloc(u8, base64_size);
            const base64_content = std.base64.standard.Encoder.encode(buffer, content);

            var results = if (kind == .hang) &hang_results else &crash_results;
            try results.append(.{
                .branch = branch,
                .commit_sha = commit_sha,
                .commit_timestamp = commit_timestamp,
                .start_timestamp = combined_stats.start_timestamp,
                .fuzzer = fuzzer_name,
                .edges_found = combined_stats.edges_found,
                .total_edges = combined_stats.total_edges,
                .total_execs = combined_stats.total_execs,
                .unique_crashes = combined_stats.unique_crashes,
                .unique_hangs = combined_stats.unique_hangs,
                .kind = kind,
                .encoded_failure = base64_content,
            });
        }
    }

    std.mem.sort(FuzzResult, hang_results.items, {}, FuzzResult.lessThan);
    std.mem.sort(FuzzResult, crash_results.items, {}, FuzzResult.lessThan);

    // TODO: re-evaluate if we want to record more, but that might flood the results.
    // We record at most 2 results per run (1 hang and 1 crash).
    var results = std.ArrayList(FuzzResult).init(gpa);
    defer results.deinit();
    if (hang_results.items.len > 0) {
        try results.append(hang_results.items[0]);
    }
    if (crash_results.items.len > 0) {
        try results.append(crash_results.items[0]);
    }
    if (crash_results.items.len == 0 and hang_results.items.len == 0) {
        // No failures!
        // Record a success result instead.
        try results.append(.{
            .branch = branch,
            .commit_sha = commit_sha,
            .commit_timestamp = commit_timestamp,
            .start_timestamp = combined_stats.start_timestamp,
            .fuzzer = fuzzer_name,
            .edges_found = combined_stats.edges_found,
            .total_edges = combined_stats.total_edges,
            .total_execs = combined_stats.total_execs,
            .unique_crashes = combined_stats.unique_crashes,
            .unique_hangs = combined_stats.unique_hangs,
            .kind = .success,
            .encoded_failure = "",
        });
    }

    const new_entries_json = std.json.fmt(results.items, .{ .whitespace = .indent_tab });
    std.debug.print("New database entries:\n{s}\n", .{new_entries_json});

    const file_result = std.fs.cwd().openFile("data.json", .{ .mode = .read_write });
    if (file_result == error.FileNotFound) {
        // Database does not exist yet, make a new one.
        const file = try std.fs.cwd().createFile("data.json", .{});
        defer file.close();
        try file.writer().print("{s}", .{new_entries_json});
    } else {
        // Load and merge the database.
        var file = try file_result;
        defer file.close();
        const content = try file.readToEndAlloc(arena, 10 * 1024);
        const old_data = try std.json.parseFromSliceLeaky([]FuzzResult, arena, content, .{});

        try results.appendSlice(old_data);
        std.mem.sort(FuzzResult, results.items, {}, FuzzResult.lessThan);

        const out = if (results.items.len > result_limit) results.items[0..result_limit] else results.items;
        const out_json = std.json.fmt(out, .{ .whitespace = .indent_tab });
        // Truncate the file and write new output.
        try file.seekTo(0);
        try file.setEndPos(0);
        try file.writer().print("{s}", .{out_json});
    }
}

fn run_cmd(arena: std.mem.Allocator, roc_repo_dir: std.fs.Dir, argv: []const []const u8) ![]const u8 {
    const results = try std.process.Child.run(.{
        .allocator = arena,
        .argv = argv,
        .cwd_dir = roc_repo_dir,
    });
    if (results.term != .Exited or results.term.Exited != 0 or results.stderr.len != 0) {
        std.debug.print("Failed to execute subcommand: {any}\nTerm was: {any}\nError was: {s}\n", .{ argv, results.term, results.stderr });
        std.process.exit(1);
    }
    return std.mem.trim(u8, results.stdout, &std.ascii.whitespace);
}

fn load_fuzzer_stats(arena: std.mem.Allocator, fuzz_output_dir: std.fs.Dir, fuzzer_subdir: std.fs.Dir.Entry) !?FuzzerStats {
    if (fuzzer_subdir.kind != .directory) {
        return null;
    }
    const path = try std.fs.path.join(arena, &[_][]const u8{ fuzzer_subdir.name, "fuzzer_stats" });
    const file = try fuzz_output_dir.openFile(path, .{});
    defer file.close();
    const content = file.readToEndAlloc(arena, 10 * 1024) catch {
        return null;
    };
    var lines = std.mem.splitScalar(u8, content, '\n');
    var stats = FuzzerStats{};
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "start_time")) {
            stats.start_timestamp = try read_field(line);
        } else if (std.mem.startsWith(u8, line, "execs_done")) {
            stats.total_execs = try read_field(line);
        } else if (std.mem.startsWith(u8, line, "edges_found")) {
            stats.edges_found = try read_field(line);
        } else if (std.mem.startsWith(u8, line, "total_edges")) {
            stats.total_edges = try read_field(line);
        } else if (std.mem.startsWith(u8, line, "saved_crashes")) {
            stats.unique_crashes = try read_field(line);
        } else if (std.mem.startsWith(u8, line, "saved_hangs")) {
            stats.unique_hangs = try read_field(line);
        }
    }
    if (stats.start_timestamp == 0 or stats.total_execs == 0) {
        return null;
    }
    return stats;
}

fn read_field(field: []const u8) !u64 {
    var it = std.mem.splitScalar(u8, field, ':');
    std.debug.assert(it.next() != null);
    if (it.next()) |value_str| {
        const trimmed = std.mem.trim(u8, value_str, &std.ascii.whitespace);
        return try std.fmt.parseInt(u64, trimmed, 10);
    }
    return error.FieldMissing;
}

const FuzzerStats = struct {
    start_timestamp: u64 = 0,
    edges_found: u64 = 0,
    total_edges: u64 = 0,
    total_execs: u64 = 0,
    unique_crashes: u64 = 0,
    unique_hangs: u64 = 0,
};
