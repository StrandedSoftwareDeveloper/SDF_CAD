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

fn findSurface(startPoint: vec.Vector3, comptime sdfFunc: fn (pos: vec.Vector3) f32) vec.Vector3 {
    var point: vec.Vector3 = startPoint;
    const epsilon: f32 = 0.01;
    for (0..100) |i| {
        _ = i;

        const grad: vec.Vector3 = sdfUtils.gradient(point, sdfFunc);
        point = point.add(grad.multScalar(sdfFunc(point)));
        if (@abs(sdfFunc(point)) < epsilon) {
            break;
        }
    }
    return point;
}

fn initialTriangulation(seedPoint: vec.Vector3, front: *std.ArrayList(vec.Vector3)) !void {
    const normal: vec.Vector3 = sdfUtils.calcNormal(seedPoint, sdf);
    const tangent: vec.Vector3 = sdfUtils.calcTangent(normal).multScalar(0.1);
    const bitangent: vec.Vector3 = sdfUtils.calcBitangent(normal, tangent).multScalar(0.1);

    try front.append(seedPoint);
    try front.append(findSurface(seedPoint.add(tangent), sdf));
    try front.append(findSurface(seedPoint.add(bitangent), sdf));
}

fn pushFront() !void {}

fn starSdfWrapper(pos: vec.Vector2) f32 {
    return sdfUtils.starSdf(pos, 0.5, 8, 3.0);
}

fn sdf(pos: vec.Vector3) f32 {
    //const s1: f32 = sdfUtils.extrudeTwist(pos, starSdfWrapper, 1.0, -720.0);
    //const s2: f32 = sdfUtils.extrudeTwist(pos, starSdfWrapper, 1.0, 720.0);
    //return @max(s1, s2);
    return sdfUtils.sphereSdf(pos, .{ .x = 0.0, .y = 0.0, .z = 0.0 }, 1.0);
}

pub fn main() !void {
    const threshold: f32 = 0.0;
    _ = threshold;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();

    var verts: std.ArrayList(vec.Vector3) = std.ArrayList(vec.Vector3).init(allocator);
    defer verts.deinit();

    //Stack of fronts, where each front is an array of vertices
    var fronts: std.ArrayList(std.ArrayList(vec.Vector3)) = std.ArrayList(std.ArrayList(vec.Vector3)).init(allocator);
    defer fronts.deinit(); //Note: the internal arrays are garunteed to be deinitialized in the main array

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var pcg = std.rand.Pcg.init(10);
    const rng = pcg.random();

    var initialFront: std.ArrayList(vec.Vector3) = std.ArrayList(vec.Vector3).init(allocator);
    var startPoint: vec.Vector3 = .{ .x = 0.0, .y = 0.0, .z = 0.0 };
    var seedPoint: vec.Vector3 = findSurface(startPoint, sdf);
    try initialTriangulation(seedPoint, &initialFront);
    try fronts.append(initialFront);

    while (fronts.items.len > 0) {
        const currentFront: std.ArrayList(vec.Vector3) = fronts.pop();

        while (currentFront.items.len > 3) {
            actualizeAngles(currentFront);
            const pt: vec.Vector3 = pointWithMinAngle(currentFront);
            const ptI: vec.Vector3 = selfIntersection(pt, currentFront);
        }

        for (currentFront.items) |vert| { //Move the last few verts into the main array
            try verts.append(vert);
        }
        defer currentFront.deinit();
    }

    for (0..10000) |i| {
        _ = i;

        startPoint = .{ .x = rng.float(f32) * 2.0 - 1.0, .y = rng.float(f32) * 2.0 - 1.0, .z = rng.float(f32) * 2.0 - 1.0 };
        seedPoint = findSurface(startPoint, sdf);
        if (seedPoint.z > 0.0) {
            //continue;
        }

        const NTB: vec.Mat3 = sdfUtils.calcNTB(seedPoint, sdf);

        try verts.append(seedPoint);
        try verts.append(findSurface(seedPoint.add(NTB.r1.multScalar(0.2)), sdf));
        try verts.append(findSurface(seedPoint.add(NTB.r2.multScalar(0.2)), sdf));

        std.debug.print("{d:.3}, {d:.3}, {d:.3}: {d:.3}\n", .{ seedPoint.x, seedPoint.y, seedPoint.z, sdf(seedPoint) });
    }

    try writeSTL(stdout, verts.items);

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
