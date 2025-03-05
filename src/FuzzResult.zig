const Self = @This();

pub const Kind = enum {
    success,
    crash,
    hang,
};

branch: []const u8,
commit_sha: []const u8,
commit_timestamp: u64,
start_timestamp: u64,
fuzzer: []const u8,
// These are all summary statistics
edges_found: u64,
total_edges: u64,
unique_crashes: u64,
unique_hangs: u64,
total_execs: u64,
kind: Kind,
// Only set on actual failure.
encoded_failure: []const u8,

pub fn lessThan(_: void, lhs: Self, rhs: Self) bool {
    // 1. Prefer new commits to old commits.
    if (lhs.commit_timestamp > rhs.commit_timestamp) {
        return true;
    } else if (lhs.commit_timestamp < rhs.commit_timestamp) {
        return false;
    }
    // 2. Prefer failure results to success results.
    if (lhs.kind != .success and rhs.kind == .success) {
        return true;
    } else if (lhs.kind == .success and rhs.kind != .success) {
        return false;
    }

    // 3. Prefer shorter failures.
    if (lhs.encoded_failure.len < rhs.encoded_failure.len) {
        return true;
    } else if (lhs.encoded_failure.len > rhs.encoded_failure.len) {
        return false;
    }

    // 4. Prefer newer runs.
    if (lhs.start_timestamp > rhs.start_timestamp) {
        return true;
    } else if (lhs.start_timestamp < rhs.start_timestamp) {
        return false;
    }
    return false;
}
