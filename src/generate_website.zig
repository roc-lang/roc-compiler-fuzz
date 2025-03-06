const std = @import("std");
const FuzzResult = @import("FuzzResult.zig");

pub fn main() !void {
    var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_impl.deinit();
    const gpa = gpa_impl.allocator();

    var arena_impl = std.heap.ArenaAllocator.init(gpa);
    defer arena_impl.deinit();
    const arena = arena_impl.allocator();

    const file = try std.fs.cwd().openFile("data.json", .{});
    defer file.close();
    const content = try file.readToEndAlloc(arena, 10 * 1024);
    const data = try std.json.parseFromSliceLeaky([]FuzzResult, arena, content, .{});

    std.fs.cwd().makeDir("www") catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };
    var out_dir = try std.fs.cwd().openDir("www", .{});
    defer out_dir.close();
    const index_html = try out_dir.createFile("index.html", .{});
    defer index_html.close();

    var buffered = std.io.bufferedWriter(index_html.writer());
    defer buffered.flush() catch @panic("Flush failed");
    // TODO: look into using a templating tool and making a nicer site.
    // Maybe https://github.com/kristoff-it/superhtml/
    try buffered.writer().writeAll(
        \\<!DOCTYPE html>
        \\<html>
        \\<head><title>Roc Compiler Fuzz</title></head>
        \\<body>
        \\
        \\<h1>
        \\  Roc Compiler Fuzz Results
        \\  <a href="https://github.com/roc-lang/roc-compiler-fuzz/blob/main/data.json">Raw data</a>
        \\</h1>
        \\
        \\<table>
        \\  <tr>
        \\    <th>Commit</th>
        \\    <th>Fuzzer</th>
        \\    <th>Command</th>
        \\    <th>Timestamp</th>
        \\    <th>Coverage</th>
        \\    <th>Count</th>
        \\  </tr>
        \\
    );
    for (data) |result| {
        var branch: ?[]const u8 = null;
        if (!std.mem.eql(u8, result.branch, "main")) {
            branch = try std.fmt.allocPrint(arena,
                \\<a href="https://github.com/roc-lang/roc/commit/{s}">{s}</a>
            , .{
                result.branch,
                result.branch,
            });
        }
        var cmd: ?[]const u8 = null;
        if (result.kind != .success) {
            cmd = try std.fmt.allocPrint(arena,
                \\zig build repro-{s} -- -b {s}
            , .{
                result.fuzzer,
                if (result.encoded_failure.len > 0) result.encoded_failure else "''",
            });
        }
        var count: []const u8 = undefined;
        switch (result.kind) {
            .success => {
                count = try std.fmt.allocPrint(arena,
                    \\{} runs
                , .{
                    result.total_execs,
                });
            },
            .crash => {
                count = try std.fmt.allocPrint(arena,
                    \\{} crashes
                , .{
                    result.unique_crashes,
                });
            },
            .hang => {
                count = try std.fmt.allocPrint(arena,
                    \\{} hangs
                , .{
                    result.unique_hangs,
                });
            },
        }
        try buffered.writer().print(
            \\  <tr>
            \\    <td><a href="https://github.com/roc-lang/roc/tree/{s}">{s}</a>{s}</td>
            \\    <td>{s}</td>
            \\    <td>{s}</td>
            \\    <td>{}</td>
            \\    <td>{}/{} ~ {}%</td>
            \\    <td>{s}</td>
            \\  </tr>
            \\
        , .{
            result.commit_sha,
            result.commit_sha[0..7],
            if (branch) |b| b else "",
            // TODO add link to fuzzer specific page.
            result.fuzzer,
            if (cmd) |c| c else "No Failures!",
            result.start_timestamp,
            result.edges_found,
            result.total_edges,
            result.edges_found * 100 / result.total_edges,
            count,
        });
    }

    try buffered.writer().writeAll(
        \\</table>
        \\</body>
        \\</html>
        \\
    );
}
