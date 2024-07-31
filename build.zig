const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) !void {
    _ = b; // autofix
    std.debug.print("Building!\n", .{});
}
