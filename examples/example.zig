const std = @import("std");
const betterkhmer = @import("betterkhmer");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const text = "\xe1\x9e\x81\xe1\x9f\x92\xe1\x9e\x98\xe1\x9f\x82\xe1\x9e\x9a"; // ខ្មែរ
    const result = try betterkhmer.normalize(alloc, text, "km");
    defer alloc.free(result);
    std.debug.print("{s}\n", .{result});
}
