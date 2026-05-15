const std = @import("std");
const betterkhmer = @import("betterkhmer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    const fixtures = if (args.len > 1) args[1] else "../../fixtures";

    // basic test — ខ្មែរ
    const khmer = "\xe1\x9e\x81\xe1\x9f\x92\xe1\x9e\x98\xe1\x9f\x82\xe1\x9e\x9a";
    const got = try betterkhmer.normalize(alloc, khmer, "km");
    defer alloc.free(got);
    if (!std.mem.eql(u8, got, khmer)) {
        std.debug.print("basic FAILED\n", .{});
        std.process.exit(1);
    }
    std.debug.print("basic: ok\n", .{});

    // fixture tests
    var inp_buf: [4096]u8 = undefined;
    var exp_buf: [4096]u8 = undefined;
    const inp_path = try std.fmt.bufPrint(&inp_buf, "{s}/input.txt",    .{fixtures});
    const exp_path = try std.fmt.bufPrint(&exp_buf, "{s}/expected.txt", .{fixtures});

    const fi = try std.fs.cwd().openFile(inp_path, .{});
    defer fi.close();
    const fe = try std.fs.cwd().openFile(exp_path, .{});
    defer fe.close();

    var fi_buf = std.io.bufferedReader(fi.reader());
    var fe_buf = std.io.bufferedReader(fe.reader());
    var fi_r = fi_buf.reader();
    var fe_r = fe_buf.reader();

    var total: usize = 0;
    var failures: usize = 0;

    var in_line  = std.ArrayList(u8).init(alloc); defer in_line.deinit();
    var exp_line = std.ArrayList(u8).init(alloc); defer exp_line.deinit();

    while (true) {
        in_line.clearRetainingCapacity();
        exp_line.clearRetainingCapacity();
        fi_r.readUntilDelimiterArrayList(&in_line,  '\n', 65536) catch |e| {
            if (e == error.EndOfStream) break else return e;
        };
        fe_r.readUntilDelimiterArrayList(&exp_line, '\n', 65536) catch |e| {
            if (e == error.EndOfStream) break else return e;
        };

        const result = try betterkhmer.normalize(alloc, in_line.items, "km");
        defer alloc.free(result);

        if (!std.mem.eql(u8, result, exp_line.items)) {
            failures += 1;
            if (failures <= 10)
                std.debug.print("[{}] mismatch\n", .{total});
        }
        total += 1;
    }

    if (failures > 0) {
        std.debug.print("{}/{} fixture failures\n", .{ failures, total });
        std.process.exit(1);
    }
    std.debug.print("fixtures: {} ok\n", .{total});
}
