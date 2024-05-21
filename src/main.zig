//An SDF mesher by SSD
//Most of the cube marching code, including the tables, are from https://polycoding.net/marching-cubes/part-1/
//All of the SDF functions are adapted from https://iquilezles.org/articles/distfunctions/ under the MIT license

const std = @import("std");
const vec = @import("vector.zig");
const sdfUtils = @import("sdf.zig");

fn writeVertex(writer: anytype, vertex: vec.Vector3) !void {
    _ = try writer.write(&std.mem.toBytes(vertex.x));
    _ = try writer.write(&std.mem.toBytes(vertex.y));
    _ = try writer.write(&std.mem.toBytes(vertex.z));
}

fn writeSTL(writer: anytype, vertices: []const vec.Vector3) !void {
    try writer.writeByteNTimes(0, 80); //Write STL header
    try writer.writeInt(u32, @intCast(vertices.len / 3), .little); //Write number of triangles (each triangle is 3 vertices)

    var i: usize = 0;
    while (i < vertices.len) {
        try writer.writeByteNTimes(0, 4 * 3); //Write normal
        try writeVertex(writer, vertices[i]);
        i += 1;
        try writeVertex(writer, vertices[i]);
        i += 1;
        try writeVertex(writer, vertices[i]);
        i += 1;
        try writer.writeByteNTimes(0, 2); //Write attributes
    }
}

fn interp(edgeVertex1: vec.Vector3, valueAtVertex1: f32, edgeVertex2: vec.Vector3, valueAtVertex2: f32, threshold: f32) vec.Vector3 {
    return .{
        .x = (edgeVertex1.x + (threshold - valueAtVertex1) * (edgeVertex2.x - edgeVertex1.x) / (valueAtVertex2 - valueAtVertex1)),
        .y = (edgeVertex1.y + (threshold - valueAtVertex1) * (edgeVertex2.y - edgeVertex1.y) / (valueAtVertex2 - valueAtVertex1)),
        .z = (edgeVertex1.z + (threshold - valueAtVertex1) * (edgeVertex2.z - edgeVertex1.z) / (valueAtVertex2 - valueAtVertex1)),
    };
}

fn starSdfWrapper(pos: vec.Vector2) f32 {
    return sdfUtils.starSdf(pos, 0.5, 8, 3.0);
}

fn sdf(pos: vec.Vector3) f32 {
    const s1: f32 = sdfUtils.extrudeTwist(pos, starSdfWrapper, 1.0, -720.0);
    const s2: f32 = sdfUtils.extrudeTwist(pos, starSdfWrapper, 1.0, 720.0);
    return @max(s1, s2);
}

pub fn main() !void {
    const threshold: f32 = 0.0;
    _ = threshold;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();

    var verts: std.ArrayList(vec.Vector3) = std.ArrayList(vec.Vector3).init(allocator);
    defer verts.deinit();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try writeSTL(stdout, verts.items);

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
