//An SDF slicer by SSD
//All of the SDF functions are adapted from https://iquilezles.org/articles/distfunctions/ under the MIT license

const std = @import("std");
const vec = @import("vector.zig");
const sdfPrimitives = @import("sdf.zig");

fn stepsToWorldSpace(x: usize, y: usize, z: usize, resolution: usize, bounds_min: vec.Vector3, bounds_max: vec.Vector3) vec.Vector3 {
    var point: vec.Vector3 = .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .z = @floatFromInt(z) };
    point = point.divideScalar(@floatFromInt(resolution));
    point = vec.Vector3.lerp(bounds_min, bounds_max, point);
    return point;
}

fn starSdfWrapper(pos: vec.Vector2) f32 {
    return sdfPrimitives.starSdf(pos, 5.0, 8, 3.0);
}

fn boxSdfWrapper(pos: vec.Vector2) f32 {
    return sdfPrimitives.boxSdf(pos, .{.x = 10.0, .y = 10.0});
}

fn sdf(pos: vec.Vector3) f32 {
    const s1: f32 = sdfPrimitives.extrudeTwist(pos, starSdfWrapper, 10.0, -720.0);
    //const s1: f32 = sdfPrimitives.extrude(pos, boxSdfWrapper, 10.0);
    //return s1;
    const s2: f32 = sdfPrimitives.extrudeTwist(pos, starSdfWrapper, 10.0, 720.0);
    return @max(s1, s2);
    //return sdfPrimitives.vertCappedCylinderSdf(pos, 18.0, 9.0);
    //return sdfPrimitives.sphereSdf(pos, vec.Vector3.zero(), 9.0);
}

//TODO: finish writing this function
fn findSurface2D(initialPoint: vec.Vector3) vec.Vector3 {
    const epsilon: f32 = 0.01;
    const pointDist: f32 = sdf(initialPoint);
    const rightDist: f32 = sdf(.{.x = initialPoint.x + epsilon, .y = initialPoint.y, .z = initialPoint.z});
    const downDist: f32 = sdf(.{.x = initialPoint.x, .y = initialPoint.y + epsilon, .z = initialPoint.z});
    _ = pointDist;
    _ = rightDist;
    _ = downDist;
    return initialPoint;
}

//Note: Assumes that one of the points is inside and the other isn't
fn findSurfaceOnLine(p1: vec.Vector3, p2: vec.Vector3, maxIterations: usize) vec.Vector3 {
    const epsilon: f32 = 0.01;

    var insidePoint: vec.Vector3 = p1;
    var outsidePoint: vec.Vector3 = p2;
    var swapped: bool = false;

    if (sdf(p2) < 0.0) {
        outsidePoint = p1;
        insidePoint = p2;
        swapped = true;
    }

    var k: f32 = 0.5;
    var stepSize: f32 = 0.25;
    for (0..maxIterations) |_| {
        const val: f32 = sdf(vec.Vector3.lerp(insidePoint, outsidePoint, .{.x = k, .y = k, .z = k}));
        if (@abs(val) < epsilon) {
            break;
        }
        if (val < 0.0) {
            k += stepSize;
        } else {
            k -= stepSize;
        }
        stepSize *= 0.5;
    }

    return vec.Vector3.lerp(insidePoint, outsidePoint, .{.x = k, .y = k, .z = k});
}

//Note: As a 2D function, "up" and "down" refer to "y+" and "y-" respectively
fn findDirection(point: vec.Vector3) vec.Vector3 {
    const epsilon: f32 = 0.1;

    const upPos:    vec.Vector3 = .{.x = point.x, .y = point.y + epsilon*2.0, .z = point.z};
    const rightPos: vec.Vector3 = .{.x = point.x + epsilon*2.0, .y = point.y, .z = point.z};
    const downPos:  vec.Vector3 = .{.x = point.x, .y = point.y - epsilon*2.0, .z = point.z};
    const leftPos:  vec.Vector3 = .{.x = point.x - epsilon*2.0, .y = point.y, .z = point.z};

    if (sdf(upPos) < 0.0) {
        if (sdf(leftPos) >= 0.0) {
            return findSurfaceOnLine(upPos, leftPos, 100);
        }

        if (sdf(downPos) >= 0.0) {
            return findSurfaceOnLine(leftPos, downPos, 100);
        }

        if (sdf(rightPos) >= 0.0) {
            return findSurfaceOnLine(downPos, rightPos, 100);
        }

        std.debug.print("All 4 points are inside! {d:.2} {d:.2} {d:.2} {d:.2}\n", .{point.x, point.y, point.z, sdf(point)});
        return vec.Vector3.zero();
    } else {
        if (sdf(rightPos) < 0.0) {
            return findSurfaceOnLine(upPos, rightPos, 100);
        }

        if (sdf(downPos) < 0.0) {
            return findSurfaceOnLine(rightPos, downPos, 100);
        }

        if (sdf(leftPos) < 0.0) {
            return findSurfaceOnLine(downPos, leftPos, 100);
        }

        std.debug.print("All 4 points are outside!\n", .{});
        return point;
    }
}

//Calculates the inner angle between p1<->p2<->p3
fn calcAngle(p1: vec.Vector3, p2: vec.Vector3, p3: vec.Vector3) f32 {
    const u: vec.Vector3 = p1.subtract(p2);
    const v: vec.Vector3 = p3.subtract(p2);
    const dot: f32 = vec.Vector3.dot(u, v);
    const cosAngle: f32 = dot / (u.length() * v.length());

    return std.math.acos(cosAngle);
}

//Writes the optimized toolpath in-place into `toolpath` and returns the new size (which is always <= toolpath.len)
fn optimizeToolpath(toolpath: []vec.Vector3) usize {
    var outIndex: usize = 0;

    if (toolpath.len < 3) {
        for (toolpath) |p| {
            toolpath[outIndex] = p;
            outIndex += 1;
        }
    }

    var prevPrevPoint: vec.Vector3 = toolpath[0];
    var prevPoint: vec.Vector3 = toolpath[1];
    var point: vec.Vector3 = toolpath[2];
    for (2..toolpath.len) |i| {
        point = toolpath[i];
        if (calcAngle(prevPrevPoint, prevPoint, point) < 3.0) {
            toolpath[outIndex] = prevPrevPoint; //Output the point
            outIndex += 1;

            prevPrevPoint = prevPoint;
        }
        prevPoint = point;
    }
    if (!vec.Vector3.approxEq(prevPrevPoint, prevPoint, 0.001)) {
        toolpath[outIndex] = prevPrevPoint; //Output the point
        outIndex += 1;
    }
    toolpath[outIndex] = prevPoint;
    outIndex += 1;
    toolpath[outIndex] = point; //Output the point
    outIndex += 1;

    return outIndex; //Return size
}

fn toolpathToGcode(toolpath: []vec.Vector3, writer: anytype) !void {
    const extrusionFactor: f32 = 0.5;
    var prevPoint: vec.Vector3 = toolpath[0];
    for (toolpath) |point| {
        const extrudeAmount: f32 = point.subtract(prevPoint).length() * extrusionFactor;
        try writer.print("G1 X{d:.2} Y{d:.2} Z{d:.2} F1200 E{d:.2}\n", .{point.x, point.y, point.z, extrudeAmount});
        prevPoint = point;
    }
}

pub fn main() !void {
    const lowResolution: f32 = 0.1; //The resolution used for things like finding out approximately where an edge is
    const layerHeight: f32 = 0.2; //Layer height in mm
    const bounds_min: vec.Vector3 = .{ .x = -10.0, .y = -10.0, .z = -10.0 };
    const bounds_max: vec.Vector3 = .{ .x = 10.0, .y = 10.0, .z = 10.0 };
    const threshold: f32 = 0.0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();

    var toolpath: std.ArrayList(vec.Vector3) = std.ArrayList(vec.Vector3).init(allocator);
    defer toolpath.deinit();

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    {
        var startGcodeFile: std.fs.File = try std.fs.cwd().openFile("start.gcode", .{});
        defer startGcodeFile.close();
        const startGcode: []u8 = try startGcodeFile.readToEndAlloc(allocator, 1_000_000);
        defer allocator.free(startGcode);
        try stdout.print("{s}\n", .{startGcode});
    }

    try stdout.print(";Generated with SDF_CAD by SSD\n", .{});

    try bw.flush();

    var firstLayer: usize = std.math.maxInt(usize);
    var layerNum: usize = 0;
    var z: f32 = bounds_min.z;
    while (z < bounds_max.z) : (z += layerHeight) {
        defer layerNum += 1;
        std.debug.print("Layer {}\n", .{layerNum});

        var startPoint: vec.Vector3 = vec.Vector3.zero();
        var point: vec.Vector3 = vec.Vector3.zero();
        var foundSurface: bool = false;

        var y: f32 = bounds_min.y;
        yLoop: while (y < bounds_max.y) : (y += lowResolution) {
            var x: f32 = bounds_min.x;
            while (x < bounds_max.x) : (x += lowResolution) {
                if (sdf(.{.x = x, .y = y, .z = z}) < threshold) {
                    //var startPoint: vec.Vector3 = findSurface2D(.{.x = x, .y = y, .z = z});
                    startPoint = findSurfaceOnLine(.{.x = x - lowResolution, .y = y, .z = z}, .{.x = x, .y = y, .z = z}, 10);
                    point = findDirection(startPoint);
                    foundSurface = true;
                    if (firstLayer == std.math.maxInt(usize)) {
                        firstLayer = layerNum;
                    }
                    break :yLoop;
                }
            }
        }

        if (!foundSurface) {
            continue;
        }

        try stdout.print(";LAYER:{}\nG1 X{d:.2} Y{d:.2} Z{d:.2} F1200 E0\n", .{layerNum-firstLayer, startPoint.x, startPoint.y, point.z - bounds_min.z});
        var i: usize = 0;
        while ((startPoint.subtract(point).length() > 0.2 or i < 5) and i < 10000) : (i += 1) {
            point = findDirection(point);
            try toolpath.append(point);
        }

        const newSize: usize = optimizeToolpath(toolpath.items);
        toolpath.shrinkRetainingCapacity(newSize);

        try toolpathToGcode(toolpath.items, stdout);

        toolpath.shrinkRetainingCapacity(0);
    }

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
