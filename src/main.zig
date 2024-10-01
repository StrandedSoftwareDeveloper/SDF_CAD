//An SDF slicer by SSD
//All of the SDF functions are adapted from https://iquilezles.org/articles/distfunctions/ under the MIT license

const std = @import("std");
const vec = @import("vector.zig");
const sdfPrimitives = @import("sdf.zig");
const line = @import("line.zig");
const utils = @import("utils.zig");

const BitmapMask = struct {
    const SOLID: u8 = 0b00000001;
    const FILLED_IN: u8 = 0b00000010;
    const SHOULD_SOLID_INFILL: u8 = 0b00000100;
};

fn uTOi(v: usize) isize {
    return @intCast(v);
}

fn iTOu(v: isize) usize {
    return @intCast(v);
}

fn stepsToWorldSpace(x: usize, y: usize, z: usize, resolution: usize, bounds_min: vec.Vector3, bounds_max: vec.Vector3) vec.Vector3 {
    var point: vec.Vector3 = .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .z = @floatFromInt(z) };
    point = point.divideScalar(@floatFromInt(resolution));
    point = vec.Vector3.lerp(bounds_min, bounds_max, point);
    return point;
}

fn minMaxToIndex(v: f32, min: f32, max: f32, indexMax: usize) usize {
    const range: f32 = max - min;
    const k: f32 = (v - min) / range;
    return @intFromFloat(k*@as(f32, @floatFromInt(indexMax)));
}

fn indexToMinMax(v: usize, min: f32, max: f32, indexMax: usize) f32 {
    const vFloat: f32 = @floatFromInt(v);
    const k: f32 = vFloat / @as(f32, @floatFromInt(indexMax));
    return std.math.lerp(min, max, k);
}

fn starSdfWrapper(pos: vec.Vector2) f32 {
    return sdfPrimitives.starSdf(pos, 10.0, 8, 3.0);
}

fn boxSdfWrapper(pos: vec.Vector2) f32 {
    return sdfPrimitives.boxSdf(pos, .{.x = 10.0, .y = 10.0});
}

fn hexSdfWrapper(pos: vec.Vector2) f32 {
    return sdfPrimitives.hexagonSdf(pos, 0.1);
}

fn sdf(pos: vec.Vector3) f32 {
    const s1: f32 = sdfPrimitives.extrudeTwist(pos, starSdfWrapper, 10.0, -180.0);
    //const s1: f32 = sdfPrimitives.extrude(pos, boxSdfWrapper, 10.0);
    //return s1;
    //const s2: f32 = sdfPrimitives.extrudeTwist(pos, starSdfWrapper, 10.0, 180.0);
    const s3: f32 = sdfPrimitives.hexPrismSdf(.{.x = pos.x, .y = pos.y, .z = pos.z + 0.1}, .{.x = 12.0, .y = 2.0});
    return @max(s3, -s1);
    //return sdfPrimitives.vertCappedCylinderSdf(pos, 18.0, 9.0);
    //return sdfPrimitives.sphereSdf(pos, vec.Vector3.zero(), 9.0);
    //return sdfPrimitives.torusSdf(.{.x = pos.x, .y = pos.y, .z = pos.z + 0.01}, .{.x = 5.0, .y = 2.0});
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
    const epsilon: f32 = 0.2;

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
fn optimizeToolpath(toolpath: []utils.ToolpathEntry) usize {
    var outIndex: usize = 0;

    if (toolpath.len < 3) {
        for (toolpath) |p| {
            toolpath[outIndex] = p;
            outIndex += 1;
        }
    }

    var prevPrevPoint: utils.ToolpathEntry = toolpath[0];
    var prevPoint: utils.ToolpathEntry = toolpath[1];
    var point: utils.ToolpathEntry = toolpath[2];
    for (2..toolpath.len) |i| {
        point = toolpath[i];
        if (calcAngle(prevPrevPoint.pos, prevPoint.pos, point.pos) < 3.0) {
            toolpath[outIndex] = prevPrevPoint; //Output the point
            outIndex += 1;

            prevPrevPoint = prevPoint;
        }

        prevPoint = point;
    }

    if (!vec.Vector3.approxEq(prevPrevPoint.pos, prevPoint.pos, 0.001)) {
        toolpath[outIndex] = prevPrevPoint; //Output the point
        outIndex += 1;
    }
    toolpath[outIndex] = prevPoint;
    outIndex += 1;
    if (outIndex >= toolpath.len) {
        std.debug.print("What in the heck\n", .{});
    }
    toolpath[outIndex] = point; //Output the point
    outIndex += 1;

    return outIndex; //Return size
}

fn toolpathToGcode(toolpath: []utils.ToolpathEntry, writer: anytype) !void {
    if (toolpath.len == 0) {
        return;
    }
    const extrusionFactor: f32 = 0.05;
    var prevPoint: vec.Vector3 = toolpath[0].pos;
    for (toolpath) |point| {
        if (point.travel) {
            try writer.print("G1 X{d:.2} Y{d:.2} Z{d:.2} F1200\n", .{point.pos.x, point.pos.y, point.pos.z});
        } else {
            const extrudeAmount: f32 = point.pos.subtract(prevPoint).length() * extrusionFactor;
            try writer.print("G1 X{d:.2} Y{d:.2} Z{d:.2} F1200 E{d:.2}\n", .{point.pos.x, point.pos.y, point.pos.z, extrudeAmount});
        }
        prevPoint = point.pos;
    }
}

fn addInnerWall(toolpath: *std.ArrayList(vec.Vector3), offset: vec.Vector3) !void {
    const origLen: usize = toolpath.items.len-1;
    for (0..origLen) |i| {
        const index: isize = @intCast(i);
        const point: vec.Vector3 = toolpath.items[i];
        const prevPoint: vec.Vector3 = toolpath.items[@intCast(try std.math.mod(isize, index-1, @intCast(origLen)))];
        const nextPoint: vec.Vector3 = toolpath.items[@intCast(try std.math.mod(isize, index+1, @intCast(origLen)))];
        const v03D: vec.Vector3 = prevPoint.subtract(point);
        const v13D: vec.Vector3 = nextPoint.subtract(point);
        const v02D: vec.Vector2 = .{.x = v03D.x, .y = v03D.y};
        const v12D: vec.Vector2 = .{.x = v13D.x, .y = v13D.y};
        const angle0: f32 = v02D.getAngle();
        const angle1: f32 = v12D.getAngle();
        const angle: f32 = (angle0 + angle1) * 0.5;

        const v0: vec.Vector2 = .{.x = @cos(angle) * 0.5, .y = @sin(angle) * 0.5};
        const v1: vec.Vector2 = vec.Vector2.zero().subtract(v0); //Negate v0
        var v: vec.Vector3 = .{.x = v0.x + point.x, .y = v0.y + point.y, .z = point.z};
        if (sdf(v.add(offset)) > 0.0) { //Pick the one that's inside
            v = .{.x = v1.x + point.x, .y = v1.y + point.y, .z = point.z};
        }

        if (sdf(v.add(offset)) > 0.0) {
            //std.debug.print("AAAAAAAAA {d:.2} {d:.2} {d:.2}\n", .{sdf(point.subtract(offset)), sdf(v), sdf(.{.x = v1.x + point.x, .y = v1.y + point.y, .z = point.z})});
        }
        try toolpath.append(v);
    }
}

fn dumpImage(path: []const u8, bitmap: utils.Bitmap) !void {
    const file: std.fs.File = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();
    try w.print("P3\n{}\n{}\n255\n", .{bitmap.width, bitmap.height});
    for (0..bitmap.width*bitmap.height) |i| {
        try w.print("{} {} {}\n", .{(bitmap.data[i].value & 0b00000001)*255, ((bitmap.data[i].value & 0b00000010) >> 1)*255, ((bitmap.data[i].value & 0b00000100) >> 2)*255});
    }
    try bw.flush();
}

pub fn drawLine(image: utils.Bitmap, inX0: usize, inY0: usize, inX1: usize, inY1: usize) void {
    const iWidth: isize = @intCast(image.width);
    var x0: isize = @intCast(inX0);
    var y0: isize = @intCast(inY0);
    const x1: isize = @intCast(inX1);
    const y1: isize = @intCast(inY1);
    const dx: isize =  @intCast(@abs (x1 - x0));
    const sx: isize = if (x0 < x1) 1 else -1;
    const dy: isize = -@as(isize, @intCast(@abs (y1 - y0)));
    const sy: isize = if (y0 < y1) 1 else -1;
    var err: isize = dx + dy;
    var e2: isize = 0; // error value e_xy

    while (true) {  // loop
        image.data[@intCast(y0*iWidth+x0)].value = 2;

        if (x0 == x1 and y0 == y1) {
            break;
        }
        e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; } // e_xy+e_x > 0
        if (e2 <= dx) { err += dx; y0 += sy; } // e_xy+e_y < 0
    }
}

//TODO: Fix this function and those little bits of solid infill on the inside next to the perimeter
pub fn genSolidInfill(bitmap: utils.Bitmap, toolpath: *std.ArrayList(utils.ToolpathEntry), z: f32, offset: vec.Vector3) !void {
    for (0..bitmap.height) |yIndex| {
        for (0..bitmap.width) |xIndex| {
            var cellIndex = yIndex*bitmap.width+xIndex;
            var cell: utils.BitmapEntry = bitmap.data[cellIndex];
            if (cell.value & BitmapMask.SHOULD_SOLID_INFILL != 0 and cell.value & BitmapMask.FILLED_IN == 0) { //Cell is marked for solid infill, but isn't filled in yet
                try toolpath.append(.{.pos = vec.Vector3.subtract(.{.x = cell.x, .y = cell.y, .z = z}, offset), .travel = true});
                bitmap.data[cellIndex].value |= BitmapMask.FILLED_IN;

                var cellX: usize = xIndex;
                var cellY: usize = yIndex;
                while (true) {
                    var numSteps: usize = 0;
                    while (true) {
                        cellX += 1;
                        cellY += 1;
                        cellIndex = cellY*bitmap.width+cellX;
                        cell = bitmap.data[cellIndex];
                        if (cell.value & BitmapMask.FILLED_IN != 0 or cell.value & BitmapMask.SHOULD_SOLID_INFILL == 0) {
                            break;
                        }

                        bitmap.data[cellIndex].value |= BitmapMask.FILLED_IN;
                        numSteps += 1;
                    }

                    try toolpath.append(.{.pos = vec.Vector3.subtract(.{.x = cell.x, .y = cell.y, .z = z}, offset), .travel = false});

                    if (numSteps < 1) {
                        break;
                    }
                }
            }
        }
    }
}

pub fn main() !void {
    const lowResolution: f32 = 0.1; //The resolution used for things like finding out approximately where an edge is
    const layerHeight: f32 = 0.2; //Layer height in mm
    const bounds_min: vec.Vector3 = .{ .x = -15.0, .y = -15.0, .z = -10.0 };
    const bounds_max: vec.Vector3 = .{ .x = 15.0, .y = 15.0, .z = 10.0 };
    const threshold: f32 = 0.0;
    var offset: vec.Vector3 = .{.x = 70.0, .y = 30.0, .z = 0.0};
    //std.debug.print("{d:.2}\n", .{sdf(bounds_max)});

    const cellsX: usize = @as(usize, @intFromFloat((bounds_max.x - bounds_min.x) / lowResolution));
    const cellsY: usize = @as(usize, @intFromFloat((bounds_max.y - bounds_min.y) / lowResolution));
    std.debug.print("{} {}\n", .{cellsX, cellsY});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();

    var bitmap: utils.Bitmap = std.mem.zeroes(utils.Bitmap);
    bitmap.data = try allocator.alloc(utils.BitmapEntry, cellsX*cellsY);
    bitmap.width = cellsX;
    bitmap.height = cellsY;
    defer allocator.free(bitmap.data);

    for (0..bitmap.data.len) |i| {
        bitmap.data[i] = .{.value = 0, .x = 0.0, .y = 0.0};
    }

    var toolpath: std.ArrayList(utils.ToolpathEntry) = std.ArrayList(utils.ToolpathEntry).init(allocator);
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
    var firstLayerZ: f32 = 0.0;
    var layerNum: usize = 0;
    var z: f32 = bounds_min.z;
    while (z < bounds_max.z) : (z += layerHeight) {
        defer layerNum += 1;
        std.debug.print("Layer {}\n", .{layerNum});

        var startPoint: vec.Vector3 = vec.Vector3.zero();
        var point: vec.Vector3 = vec.Vector3.zero();
        var foundSurface: bool = false;

        var index: usize = 0;
        var y: f32 = bounds_min.y;
        while (y < bounds_max.y) : (y += lowResolution) {
            var x: f32 = bounds_min.x;
            while (x < bounds_max.x) : (x += lowResolution) {
                bitmap.data[index] = .{.value = 0, .x = x, .y = y};
                if (sdf(.{.x = x, .y = y, .z = z}) < threshold) {
                    //var startPoint: vec.Vector3 = findSurface2D(.{.x = x, .y = y, .z = z});
                    foundSurface = true;
                    if (firstLayer == std.math.maxInt(usize)) {
                        firstLayer = layerNum;
                        firstLayerZ = z + 0.1;
                        offset.z = firstLayerZ;
                    }
                    bitmap.data[index].x = x;
                    bitmap.data[index].y = y;
                    bitmap.data[index].value |= BitmapMask.SOLID;
                    if (sdf(.{.x = x, .y = y, .z = z + layerHeight}) > threshold or sdf(.{.x = x, .y = y, .z = z - layerHeight}) > threshold) {
                        bitmap.data[index].value |= BitmapMask.SHOULD_SOLID_INFILL;
                    }
                }
                index += 1;
            }
        }

        if (!foundSurface) {
            continue;
        }

        //try dumpImage("out1.ppm", bitmap);
        try stdout.print(";LAYER:{}\n", .{layerNum-firstLayer});

        var temp: usize = 0;
        var lastValue: u8 = 0;
        for (0..cellsY) |yIndex| {
            for (0..cellsX) |xIndex| {
                const cell: utils.BitmapEntry = bitmap.data[yIndex*cellsX+xIndex];
                if (cell.value & (BitmapMask.SOLID | BitmapMask.FILLED_IN) == 1 and lastValue & (BitmapMask.SOLID | BitmapMask.FILLED_IN) == 0) {
                    startPoint = findSurfaceOnLine(.{.x = cell.x - lowResolution, .y = cell.y, .z = z}, .{.x = cell.x, .y = cell.y, .z = z}, 10);
                    point = findDirection(startPoint);
                    const firstPoint: vec.Vector3 = point;
                    try toolpath.append(.{.pos = point.subtract(offset), .travel = true});

                    var i: usize = 0;
                    var lastXIndex: usize = minMaxToIndex(startPoint.x, bounds_min.x, bounds_max.x, cellsX);
                    var lastYIndex: usize = minMaxToIndex(startPoint.y, bounds_min.y, bounds_max.y, cellsY);
                    while ((startPoint.subtract(point).length() > 0.3 or i < 5) and i < 10000) : (i += 1) {
                        point = findDirection(point);
                        try toolpath.append(.{.pos = point.subtract(offset), .travel = false});
                        //std.debug.print("Point: {d:.2} {d:.2} {d:.2}\n", .{point.x, point.y, point.z});
                        const xIndex2: usize = minMaxToIndex(point.x, bounds_min.x, bounds_max.x, cellsX);
                        const yIndex2: usize = minMaxToIndex(point.y, bounds_min.y, bounds_max.y, cellsY);
                        //drawLine(bitmap, lastXIndex, lastYIndex, xIndex2, yIndex2);
                        line.drawThickLine(bitmap, BitmapMask.FILLED_IN, uTOi(lastXIndex), uTOi(lastYIndex), uTOi(xIndex2), uTOi(yIndex2), 3.0, 3.0);
                        lastXIndex = xIndex2;
                        lastYIndex = yIndex2;
                    }

                    try toolpath.append(.{.pos = firstPoint.subtract(offset), .travel = false});

                    const newSize: usize = optimizeToolpath(toolpath.items);
                    toolpath.shrinkRetainingCapacity(newSize);

                    //try addInnerWall(&toolpath, offset);

                    try toolpathToGcode(toolpath.items, stdout);
                    toolpath.shrinkRetainingCapacity(0);

                    //break :yLoop;
                    temp += 1;
                }
                lastValue = cell.value;
            }
        }

        try genSolidInfill(bitmap, &toolpath, z, offset);
        try toolpathToGcode(toolpath.items, stdout);
        toolpath.shrinkRetainingCapacity(0);

        //try dumpImage("out2.ppm", bitmap);
        if (layerNum == 59) {
            try dumpImage("out2.ppm", bitmap);
            //return;
        }

        //try stdout.print(";LAYER:{}\nG1 X{d:.2} Y{d:.2} Z{d:.2} F1200 E0\n", .{layerNum-firstLayer, point.x, point.y, point.z - firstLayerZ});
    }

    {
        var endGcodeFile: std.fs.File = try std.fs.cwd().openFile("end.gcode", .{});
        defer endGcodeFile.close();
        const endGcode: []u8 = try endGcodeFile.readToEndAlloc(allocator, 1_000_000);
        defer allocator.free(endGcode);
        try stdout.print("{s}\n", .{endGcode});
    }

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
