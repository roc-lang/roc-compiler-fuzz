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
        \\<head><title>Roc Compiler Fuzz</title>
        \\<meta name="viewport" content="width=device-width, initial-scale=1">
        \\<style>
        \\:root {
        \\  --code-bg: hsl(262 33% 96% / 1);
        \\  --gray: hsl(0 0% 18% / 1);
        \\  --orange: hsl(25 100% 18% / 1);
        \\  --green: hsl(115 100% 18% / 1);
        \\  --cyan: hsl(190 100% 18% / 1);
        \\  --blue: #05006d;
        \\  --violet: #7c38f5;
        \\  --violet-bg: hsl(262.22deg 87.1% 96%);
        \\  --magenta: #a20031;
        \\  --link-hover-color: #333;
        \\  --link-color: var(--violet);
        \\  --code-link-color: var(--violet);
        \\  --text-color: #000;
        \\  --text-hover-color: var(--violet);
        \\  --body-bg-color: #ffffff;
        \\  --border-color: #717171;
        \\  --faded-color: #4c4c4c;
        \\  --font-sans: -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;
        \\  --font-mono: SFMono-Regular, Consolas, "Liberation Mono", Menlo, Courier, monospace;
        \\}
        \\
        \\body {
        \\  font-family: var(--font-sans);
        \\  color: var(--text-color);
        \\  background-color: var(--body-bg-color);
        \\  line-height: 1.6;
        \\  max-width: 1200px;
        \\  margin: 0 auto;
        \\  padding: 2rem;
        \\}
        \\
        \\h1 {
        \\  color: var(--violet);
        \\  font-size: 2.5rem;
        \\  margin-bottom: 2rem;
        \\  display: flex;
        \\  align-items: center;
        \\  justify-content: space-between;
        \\  flex-wrap: wrap;
        \\  gap: 1rem;
        \\}
        \\
        \\h1 a {
        \\  font-size: 1rem;
        \\  padding: 0.5rem 1rem;
        \\  background-color: var(--violet-bg);
        \\  color: var(--violet);
        \\  text-decoration: none;
        \\  border-radius: 4px;
        \\  border: 1px solid var(--violet);
        \\  transition: all 0.2s ease;
        \\}
        \\
        \\h1 a:hover {
        \\  background-color: var(--violet);
        \\  color: white;
        \\}
        \\
        \\table {
        \\  width: 100%;
        \\  border-collapse: collapse;
        \\  margin-bottom: 2rem;
        \\  font-size: 0.95rem;
        \\}
        \\
        \\table th {
        \\  background-color: var(--violet-bg);
        \\  color: var(--text-color);
        \\  font-weight: bold;
        \\  text-align: left;
        \\  padding: 12px;
        \\  border-bottom: 2px solid var(--violet);
        \\}
        \\
        \\table td {
        \\  padding: 12px;
        \\  border-bottom: 1px solid var(--code-bg);
        \\}
        \\
        \\table tr:nth-child(even) {
        \\  background-color: var(--code-bg);
        \\}
        \\
        \\table tr:hover {
        \\  background-color: var(--violet-bg);
        \\}
        \\
        \\a {
        \\  color: var(--link-color);
        \\  text-decoration: none;
        \\}
        \\
        \\a:hover {
        \\  text-decoration: underline;
        \\  color: var(--link-hover-color);
        \\}
        \\
        \\pre {
        \\  background-color: var(--code-bg);
        \\  padding: 1rem;
        \\  border-radius: 4px;
        \\  overflow-x: auto;
        \\  font-family: var(--font-mono);
        \\}
        \\
        \\code {
        \\  font-family: var(--font-mono);
        \\  background-color: var(--code-bg);
        \\  padding: 0.2rem 0.4rem;
        \\  border-radius: 3px;
        \\}
        \\
        \\@media (prefers-color-scheme: dark) {
        \\  :root {
        \\    --code-bg: hsl(228.95deg 37.25% 15%);
        \\    --gray: hsl(0 0% 70% / 1);
        \\    --orange: hsl(25 98% 70% / 1);
        \\    --green: hsl(115 40% 70% / 1);
        \\    --cyan: hsl(176 84% 70% / 1);
        \\    --blue: hsl(243 43% 80% / 1);
        \\    --violet: #caadfb;
        \\    --violet-bg: hsl(262 25% 15% / 1);
        \\    --magenta: hsl(348 79% 80% / 1);
        \\    --link-hover-color: #fff;
        \\    --link-color: var(--violet);
        \\    --code-link-color: var(--violet);
        \\    --text-color: #eaeaea;
        \\    --body-bg-color: hsl(262 25% 8% / 1);
        \\    --border-color: var(--gray);
        \\    --faded-color: #bbbbbb;
        \\  }
        \\}
        \\
        \\@media only screen and (max-width: 768px) {
        \\  body {
        \\    padding: 1rem;
        \\  }
        \\
        \\  table {
        \\    display: block;
        \\    overflow-x: auto;
        \\  }
        \\
        \\  h1 {
        \\    font-size: 1.8rem;
        \\  }
        \\}
        \\</style>
        \\ <script>
        \\     const SECOND = 1000;
        \\     const MINUTE = 60 * SECOND;
        \\     const HOUR = 60 * MINUTE;
        \\     const DAY = 24 * HOUR;
        \\     window.addEventListener("DOMContentLoaded", () => {
        \\     // Select all <time> elements with the data-timestamp attribute
        \\     const timeElements = document.querySelectorAll("time[data-timestamp]");
        \\
        \\     // Loop through each <time> element
        \\     timeElements.forEach((timeEl) => {
        \\         // Retrieve the timestamp from the data attribute
        \\         const timestamp = Number(timeEl.getAttribute("data-timestamp"));
        \\
        \\         // Convert from seconds to milliseconds (if necessary)
        \\         // using the built-in Date object
        \\         const date = new Date(timestamp * 1000);
        \\
        \\         // Convert timestamps into freshness
        \\         let elapsed = Date.now() - date;
        \\         let freshness = "";
        \\         if(elapsed >= DAY) {
        \\             const days = Math.floor(elapsed/DAY);
        \\             freshness += String(days) + "d ";
        \\         }
        \\         elapsed %= DAY;
        \\         if(elapsed >= HOUR) {
        \\             const hours = Math.floor(elapsed/HOUR);
        \\             freshness += String(hours) + "h ";
        \\         }
        \\         elapsed %= HOUR;
        \\         const minutes = Math.floor(elapsed/MINUTE);
        \\         freshness += String(minutes) + "m ";
        \\         freshness += "ago";
        \\
        \\         // Write the output to the table.
        \\         timeEl.textContent = freshness;
        \\     });
        \\     });
        \\ </script>
        \\</head>
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
        \\    <th>Freshness</th>
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
                \\<code>zig build repro-{s} -- -b {s}</code>
            , .{
                result.fuzzer,
                if (result.encoded_failure.len > 0) result.encoded_failure else "''",
            });
        }
        var count: []const u8 = undefined;
        switch (result.kind) {
            .success => {
                count = try std.fmt.allocPrint(arena,
                    \\<strong style="color: var(--green);">{} runs</strong>
                , .{
                    result.total_execs,
                });
            },
            .crash => {
                count = try std.fmt.allocPrint(arena,
                    \\<strong style="color: var(--magenta);">{} crashes</strong>
                , .{
                    result.unique_crashes,
                });
            },
            .hang => {
                count = try std.fmt.allocPrint(arena,
                    \\<strong style="color: var(--orange);">{} hangs</strong>
                , .{
                    result.unique_hangs,
                });
            },
        }

        const coverage_percent = result.edges_found * 100 / result.total_edges;
        const coverage_display = try std.fmt.allocPrint(arena,
            \\{}/{} ({d}%)
        , .{
            result.edges_found,
            result.total_edges,
            coverage_percent,
        });

        try buffered.writer().print(
            \\  <tr>
            \\    <td><a href="https://github.com/roc-lang/roc/tree/{s}">{s}</a>{s}</td>
            \\    <td>{s}</td>
            \\    <td>{s}</td>
            \\    <td><time data-timestamp="{}"><!-- Will be replaced by javascript on load --></time></td>
            \\    <td>{s}</td>
            \\    <td>{s}</td>
            \\  </tr>
            \\
        , .{
            result.commit_sha,
            result.commit_sha[0..7],
            if (branch) |b| b else "",
            result.fuzzer,
            if (cmd) |c| c else "<i>Nil failures</i>",
            result.start_timestamp,
            coverage_display,
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
