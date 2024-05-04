//An SDF mesher by SSD
//Most of the cube marching code, including the tables, are from https://polycoding.net/marching-cubes/part-1/
//All of the SDF functions are adapted from https://iquilezles.org/articles/distfunctions/ under the MIT license

const std = @import("std");

const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn length(self: Vector3) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(min: Vector3, max: Vector3, k: Vector3) Vector3 {
        return .{ .x = std.math.lerp(min.x, max.x, k.x), .y = std.math.lerp(min.y, max.y, k.y), .z = std.math.lerp(min.z, max.z, k.z) };
    }

    pub fn divideScalar(self: *const Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }
};

const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn length(self: Vector2) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn lerp(min: Vector2, maximum: Vector2, k: Vector2) Vector2 {
        return .{ .x = std.math.lerp(min.x, maximum.x, k.x), .y = std.math.lerp(min.y, maximum.y, k.y) };
    }

    pub fn divideScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x / scalar, .y = self.y / scalar };
    }

    pub fn multScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn max(a: Vector2, b: Vector2) Vector2 {
        return .{.x = @max(a.x, b.x), .y = @max(a.y, b.y)};
    }

    pub fn addScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x + scalar, .y = self.y + scalar };
    }

    pub fn getAngle(self: *const Vector2) f32 {
        return std.math.atan2(self.y, self.x);
    }

    pub fn rotate(self: *const Vector2, angle: f32) Vector2 {
        const startAngle: f32 = self.getAngle();
        const len: f32 = self.length();
        return .{.x = std.math.cos(startAngle+angle) * len, .y = std.math.sin(startAngle+angle) * len};
    }

    pub fn dot(a: Vector2, b: Vector2) f32 {
        return a.x*b.x + a.y*b.y;
    }

    pub fn add(a: Vector2, b: Vector2) Vector2 {
        return .{.x = a.x + b.x, .y = a.y + b.y};
    }

    pub fn subtract(a: Vector2, b: Vector2) Vector2 {
        return .{.x = a.x - b.x, .y = a.y - b.y};
    }
};

// zig fmt: off

const edgeConnections: [12][2]u8 = [12][2]u8 {
		[2]u8{0,1}, [2]u8{1,2}, [2]u8{2,3}, [2]u8{3,0},
		[2]u8{4,5}, [2]u8{5,6}, [2]u8{6,7}, [2]u8{7,4},
		[2]u8{0,4}, [2]u8{1,5}, [2]u8{2,6}, [2]u8{3,7}
};

const triTable: [256][16]i8 = [256][16]i8{
    [16]i8{ -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 8, 3, 9, 8, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 3, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 2, 10, 0, 2, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 8, 3, 2, 10, 8, 10, 9, 8, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 11, 2, 8, 11, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 9, 0, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 11, 2, 1, 9, 11, 9, 8, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 10, 1, 11, 10, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 10, 1, 0, 8, 10, 8, 11, 10, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 9, 0, 3, 11, 9, 11, 10, 9, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 3, 0, 7, 3, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 9, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 1, 9, 4, 7, 1, 7, 3, 1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 10, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 4, 7, 3, 0, 4, 1, 2, 10, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 2, 10, 9, 0, 2, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 10, 9, 2, 9, 7, 2, 7, 3, 7, 9, 4, -1, -1, -1, -1 }, 
    [16]i8{ 8, 4, 7, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 4, 7, 11, 2, 4, 2, 0, 4, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 0, 1, 8, 4, 7, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 7, 11, 9, 4, 11, 9, 11, 2, 9, 2, 1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 10, 1, 3, 11, 10, 7, 8, 4, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 11, 10, 1, 4, 11, 1, 0, 4, 7, 11, 4, -1, -1, -1, -1 }, 
    [16]i8{ 4, 7, 8, 9, 0, 11, 9, 11, 10, 11, 0, 3, -1, -1, -1, -1 }, 
    [16]i8{ 4, 7, 11, 4, 11, 9, 9, 11, 10, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 4, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 5, 4, 1, 5, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 5, 4, 8, 3, 5, 3, 1, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 10, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 0, 8, 1, 2, 10, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 2, 10, 5, 4, 2, 4, 0, 2, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 10, 5, 3, 2, 5, 3, 5, 4, 3, 4, 8, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 4, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 11, 2, 0, 8, 11, 4, 9, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 5, 4, 0, 1, 5, 2, 3, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 1, 5, 2, 5, 8, 2, 8, 11, 4, 8, 5, -1, -1, -1, -1 }, 
    [16]i8{ 10, 3, 11, 10, 1, 3, 9, 5, 4, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 9, 5, 0, 8, 1, 8, 10, 1, 8, 11, 10, -1, -1, -1, -1 }, 
    [16]i8{ 5, 4, 0, 5, 0, 11, 5, 11, 10, 11, 0, 3, -1, -1, -1, -1 }, 
    [16]i8{ 5, 4, 8, 5, 8, 10, 10, 8, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 7, 8, 5, 7, 9, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 3, 0, 9, 5, 3, 5, 7, 3, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 7, 8, 0, 1, 7, 1, 5, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 7, 8, 9, 5, 7, 10, 1, 2, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 1, 2, 9, 5, 0, 5, 3, 0, 5, 7, 3, -1, -1, -1, -1 }, 
    [16]i8{ 8, 0, 2, 8, 2, 5, 8, 5, 7, 10, 5, 2, -1, -1, -1, -1 }, 
    [16]i8{ 2, 10, 5, 2, 5, 3, 3, 5, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 7, 9, 5, 7, 8, 9, 3, 11, 2, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 7, 9, 7, 2, 9, 2, 0, 2, 7, 11, -1, -1, -1, -1 }, 
    [16]i8{ 2, 3, 11, 0, 1, 8, 1, 7, 8, 1, 5, 7, -1, -1, -1, -1 }, 
    [16]i8{ 11, 2, 1, 11, 1, 7, 7, 1, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 8, 8, 5, 7, 10, 1, 3, 10, 3, 11, -1, -1, -1, -1 }, 
    [16]i8{ 5, 7, 0, 5, 0, 9, 7, 11, 0, 1, 0, 10, 11, 10, 0, -1 }, 
    [16]i8{ 11, 10, 0, 11, 0, 3, 10, 5, 0, 8, 0, 7, 5, 7, 0, -1 }, 
    [16]i8{ 11, 10, 5, 7, 11, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 3, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 0, 1, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 8, 3, 1, 9, 8, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 6, 5, 2, 6, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 6, 5, 1, 2, 6, 3, 0, 8, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 6, 5, 9, 0, 6, 0, 2, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 9, 8, 5, 8, 2, 5, 2, 6, 3, 2, 8, -1, -1, -1, -1 }, 
    [16]i8{ 2, 3, 11, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 0, 8, 11, 2, 0, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 9, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 10, 6, 1, 9, 2, 9, 11, 2, 9, 8, 11, -1, -1, -1, -1 }, 
    [16]i8{ 6, 3, 11, 6, 5, 3, 5, 1, 3, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 11, 0, 11, 5, 0, 5, 1, 5, 11, 6, -1, -1, -1, -1 }, 
    [16]i8{ 3, 11, 6, 0, 3, 6, 0, 6, 5, 0, 5, 9, -1, -1, -1, -1 }, 
    [16]i8{ 6, 5, 9, 6, 9, 11, 11, 9, 8, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 10, 6, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 3, 0, 4, 7, 3, 6, 5, 10, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 9, 0, 5, 10, 6, 8, 4, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 6, 5, 1, 9, 7, 1, 7, 3, 7, 9, 4, -1, -1, -1, -1 }, 
    [16]i8{ 6, 1, 2, 6, 5, 1, 4, 7, 8, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 5, 5, 2, 6, 3, 0, 4, 3, 4, 7, -1, -1, -1, -1 }, 
    [16]i8{ 8, 4, 7, 9, 0, 5, 0, 6, 5, 0, 2, 6, -1, -1, -1, -1 }, 
    [16]i8{ 7, 3, 9, 7, 9, 4, 3, 2, 9, 5, 9, 6, 2, 6, 9, -1 }, 
    [16]i8{ 3, 11, 2, 7, 8, 4, 10, 6, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 10, 6, 4, 7, 2, 4, 2, 0, 2, 7, 11, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 9, 4, 7, 8, 2, 3, 11, 5, 10, 6, -1, -1, -1, -1 }, 
    [16]i8{ 9, 2, 1, 9, 11, 2, 9, 4, 11, 7, 11, 4, 5, 10, 6, -1 }, 
    [16]i8{ 8, 4, 7, 3, 11, 5, 3, 5, 1, 5, 11, 6, -1, -1, -1, -1 }, 
    [16]i8{ 5, 1, 11, 5, 11, 6, 1, 0, 11, 7, 11, 4, 0, 4, 11, -1 }, 
    [16]i8{ 0, 5, 9, 0, 6, 5, 0, 3, 6, 11, 6, 3, 8, 4, 7, -1 }, 
    [16]i8{ 6, 5, 9, 6, 9, 11, 4, 7, 9, 7, 11, 9, -1, -1, -1, -1 }, 
    [16]i8{ 10, 4, 9, 6, 4, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 10, 6, 4, 9, 10, 0, 8, 3, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 0, 1, 10, 6, 0, 6, 4, 0, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 3, 1, 8, 1, 6, 8, 6, 4, 6, 1, 10, -1, -1, -1, -1 }, 
    [16]i8{ 1, 4, 9, 1, 2, 4, 2, 6, 4, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 0, 8, 1, 2, 9, 2, 4, 9, 2, 6, 4, -1, -1, -1, -1 }, 
    [16]i8{ 0, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 3, 2, 8, 2, 4, 4, 2, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 4, 9, 10, 6, 4, 11, 2, 3, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 2, 2, 8, 11, 4, 9, 10, 4, 10, 6, -1, -1, -1, -1 }, 
    [16]i8{ 3, 11, 2, 0, 1, 6, 0, 6, 4, 6, 1, 10, -1, -1, -1, -1 }, 
    [16]i8{ 6, 4, 1, 6, 1, 10, 4, 8, 1, 2, 1, 11, 8, 11, 1, -1 }, 
    [16]i8{ 9, 6, 4, 9, 3, 6, 9, 1, 3, 11, 6, 3, -1, -1, -1, -1 }, 
    [16]i8{ 8, 11, 1, 8, 1, 0, 11, 6, 1, 9, 1, 4, 6, 4, 1, -1 }, 
    [16]i8{ 3, 11, 6, 3, 6, 0, 0, 6, 4, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 6, 4, 8, 11, 6, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 7, 10, 6, 7, 8, 10, 8, 9, 10, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 7, 3, 0, 10, 7, 0, 9, 10, 6, 7, 10, -1, -1, -1, -1 }, 
    [16]i8{ 10, 6, 7, 1, 10, 7, 1, 7, 8, 1, 8, 0, -1, -1, -1, -1 }, 
    [16]i8{ 10, 6, 7, 10, 7, 1, 1, 7, 3, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 6, 1, 6, 8, 1, 8, 9, 8, 6, 7, -1, -1, -1, -1 }, 
    [16]i8{ 2, 6, 9, 2, 9, 1, 6, 7, 9, 0, 9, 3, 7, 3, 9, -1 }, 
    [16]i8{ 7, 8, 0, 7, 0, 6, 6, 0, 2, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 7, 3, 2, 6, 7, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 3, 11, 10, 6, 8, 10, 8, 9, 8, 6, 7, -1, -1, -1, -1 }, 
    [16]i8{ 2, 0, 7, 2, 7, 11, 0, 9, 7, 6, 7, 10, 9, 10, 7, -1 }, 
    [16]i8{ 1, 8, 0, 1, 7, 8, 1, 10, 7, 6, 7, 10, 2, 3, 11, -1 }, 
    [16]i8{ 11, 2, 1, 11, 1, 7, 10, 6, 1, 6, 7, 1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 9, 6, 8, 6, 7, 9, 1, 6, 11, 6, 3, 1, 3, 6, -1 }, 
    [16]i8{ 0, 9, 1, 11, 6, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 7, 8, 0, 7, 0, 6, 3, 11, 0, 11, 6, 0, -1, -1, -1, -1 }, 
    [16]i8{ 7, 11, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 0, 8, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 9, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 1, 9, 8, 3, 1, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 1, 2, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 10, 3, 0, 8, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 9, 0, 2, 10, 9, 6, 11, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 6, 11, 7, 2, 10, 3, 10, 8, 3, 10, 9, 8, -1, -1, -1, -1 }, 
    [16]i8{ 7, 2, 3, 6, 2, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 7, 0, 8, 7, 6, 0, 6, 2, 0, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 7, 6, 2, 3, 7, 0, 1, 9, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 6, 2, 1, 8, 6, 1, 9, 8, 8, 7, 6, -1, -1, -1, -1 }, 
    [16]i8{ 10, 7, 6, 10, 1, 7, 1, 3, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 7, 6, 1, 7, 10, 1, 8, 7, 1, 0, 8, -1, -1, -1, -1 }, 
    [16]i8{ 0, 3, 7, 0, 7, 10, 0, 10, 9, 6, 10, 7, -1, -1, -1, -1 }, 
    [16]i8{ 7, 6, 10, 7, 10, 8, 8, 10, 9, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 6, 8, 4, 11, 8, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 6, 11, 3, 0, 6, 0, 4, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 6, 11, 8, 4, 6, 9, 0, 1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 4, 6, 9, 6, 3, 9, 3, 1, 11, 3, 6, -1, -1, -1, -1 }, 
    [16]i8{ 6, 8, 4, 6, 11, 8, 2, 10, 1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 10, 3, 0, 11, 0, 6, 11, 0, 4, 6, -1, -1, -1, -1 }, 
    [16]i8{ 4, 11, 8, 4, 6, 11, 0, 2, 9, 2, 10, 9, -1, -1, -1, -1 }, 
    [16]i8{ 10, 9, 3, 10, 3, 2, 9, 4, 3, 11, 3, 6, 4, 6, 3, -1 }, 
    [16]i8{ 8, 2, 3, 8, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 4, 2, 4, 6, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 9, 0, 2, 3, 4, 2, 4, 6, 4, 3, 8, -1, -1, -1, -1 }, 
    [16]i8{ 1, 9, 4, 1, 4, 2, 2, 4, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 1, 3, 8, 6, 1, 8, 4, 6, 6, 10, 1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 1, 0, 10, 0, 6, 6, 0, 4, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 6, 3, 4, 3, 8, 6, 10, 3, 0, 3, 9, 10, 9, 3, -1 }, 
    [16]i8{ 10, 9, 4, 6, 10, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 9, 5, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 3, 4, 9, 5, 11, 7, 6, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 0, 1, 5, 4, 0, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 7, 6, 8, 3, 4, 3, 5, 4, 3, 1, 5, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 4, 10, 1, 2, 7, 6, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 6, 11, 7, 1, 2, 10, 0, 8, 3, 4, 9, 5, -1, -1, -1, -1 }, 
    [16]i8{ 7, 6, 11, 5, 4, 10, 4, 2, 10, 4, 0, 2, -1, -1, -1, -1 }, 
    [16]i8{ 3, 4, 8, 3, 5, 4, 3, 2, 5, 10, 5, 2, 11, 7, 6, -1 }, 
    [16]i8{ 7, 2, 3, 7, 6, 2, 5, 4, 9, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 4, 0, 8, 6, 0, 6, 2, 6, 8, 7, -1, -1, -1, -1 }, 
    [16]i8{ 3, 6, 2, 3, 7, 6, 1, 5, 0, 5, 4, 0, -1, -1, -1, -1 }, 
    [16]i8{ 6, 2, 8, 6, 8, 7, 2, 1, 8, 4, 8, 5, 1, 5, 8, -1 }, 
    [16]i8{ 9, 5, 4, 10, 1, 6, 1, 7, 6, 1, 3, 7, -1, -1, -1, -1 }, 
    [16]i8{ 1, 6, 10, 1, 7, 6, 1, 0, 7, 8, 7, 0, 9, 5, 4, -1 }, 
    [16]i8{ 4, 0, 10, 4, 10, 5, 0, 3, 10, 6, 10, 7, 3, 7, 10, -1 }, 
    [16]i8{ 7, 6, 10, 7, 10, 8, 5, 4, 10, 4, 8, 10, -1, -1, -1, -1 }, 
    [16]i8{ 6, 9, 5, 6, 11, 9, 11, 8, 9, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 6, 11, 0, 6, 3, 0, 5, 6, 0, 9, 5, -1, -1, -1, -1 }, 
    [16]i8{ 0, 11, 8, 0, 5, 11, 0, 1, 5, 5, 6, 11, -1, -1, -1, -1 }, 
    [16]i8{ 6, 11, 3, 6, 3, 5, 5, 3, 1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 10, 9, 5, 11, 9, 11, 8, 11, 5, 6, -1, -1, -1, -1 }, 
    [16]i8{ 0, 11, 3, 0, 6, 11, 0, 9, 6, 5, 6, 9, 1, 2, 10, -1 }, 
    [16]i8{ 11, 8, 5, 11, 5, 6, 8, 0, 5, 10, 5, 2, 0, 2, 5, -1 }, 
    [16]i8{ 6, 11, 3, 6, 3, 5, 2, 10, 3, 10, 5, 3, -1, -1, -1, -1 }, 
    [16]i8{ 5, 8, 9, 5, 2, 8, 5, 6, 2, 3, 8, 2, -1, -1, -1, -1 }, 
    [16]i8{ 9, 5, 6, 9, 6, 0, 0, 6, 2, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 5, 8, 1, 8, 0, 5, 6, 8, 3, 8, 2, 6, 2, 8, -1 }, 
    [16]i8{ 1, 5, 6, 2, 1, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 3, 6, 1, 6, 10, 3, 8, 6, 5, 6, 9, 8, 9, 6, -1 }, 
    [16]i8{ 10, 1, 0, 10, 0, 6, 9, 5, 0, 5, 6, 0, -1, -1, -1, -1 }, 
    [16]i8{ 0, 3, 8, 5, 6, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 5, 6, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 5, 10, 7, 5, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 5, 10, 11, 7, 5, 8, 3, 0, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 11, 7, 5, 10, 11, 1, 9, 0, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 10, 7, 5, 10, 11, 7, 9, 8, 1, 8, 3, 1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 1, 2, 11, 7, 1, 7, 5, 1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 3, 1, 2, 7, 1, 7, 5, 7, 2, 11, -1, -1, -1, -1 }, 
    [16]i8{ 9, 7, 5, 9, 2, 7, 9, 0, 2, 2, 11, 7, -1, -1, -1, -1 }, 
    [16]i8{ 7, 5, 2, 7, 2, 11, 5, 9, 2, 3, 2, 8, 9, 8, 2, -1 }, 
    [16]i8{ 2, 5, 10, 2, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 2, 0, 8, 5, 2, 8, 7, 5, 10, 2, 5, -1, -1, -1, -1 }, 
    [16]i8{ 9, 0, 1, 5, 10, 3, 5, 3, 7, 3, 10, 2, -1, -1, -1, -1 }, 
    [16]i8{ 9, 8, 2, 9, 2, 1, 8, 7, 2, 10, 2, 5, 7, 5, 2, -1 }, 
    [16]i8{ 1, 3, 5, 3, 7, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 7, 0, 7, 1, 1, 7, 5, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 0, 3, 9, 3, 5, 5, 3, 7, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 8, 7, 5, 9, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 8, 4, 5, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 5, 0, 4, 5, 11, 0, 5, 10, 11, 11, 3, 0, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 9, 8, 4, 10, 8, 10, 11, 10, 4, 5, -1, -1, -1, -1 }, 
    [16]i8{ 10, 11, 4, 10, 4, 5, 11, 3, 4, 9, 4, 1, 3, 1, 4, -1 }, 
    [16]i8{ 2, 5, 1, 2, 8, 5, 2, 11, 8, 4, 5, 8, -1, -1, -1, -1 }, 
    [16]i8{ 0, 4, 11, 0, 11, 3, 4, 5, 11, 2, 11, 1, 5, 1, 11, -1 }, 
    [16]i8{ 0, 2, 5, 0, 5, 9, 2, 11, 5, 4, 5, 8, 11, 8, 5, -1 }, 
    [16]i8{ 9, 4, 5, 2, 11, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 5, 10, 3, 5, 2, 3, 4, 5, 3, 8, 4, -1, -1, -1, -1 }, 
    [16]i8{ 5, 10, 2, 5, 2, 4, 4, 2, 0, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 10, 2, 3, 5, 10, 3, 8, 5, 4, 5, 8, 0, 1, 9, -1 }, 
    [16]i8{ 5, 10, 2, 5, 2, 4, 1, 9, 2, 9, 4, 2, -1, -1, -1, -1 }, 
    [16]i8{ 8, 4, 5, 8, 5, 3, 3, 5, 1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 4, 5, 1, 0, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 8, 4, 5, 8, 5, 3, 9, 0, 5, 0, 3, 5, -1, -1, -1, -1 }, 
    [16]i8{ 9, 4, 5, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 11, 7, 4, 9, 11, 9, 10, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 8, 3, 4, 9, 7, 9, 11, 7, 9, 10, 11, -1, -1, -1, -1 }, 
    [16]i8{ 1, 10, 11, 1, 11, 4, 1, 4, 0, 7, 4, 11, -1, -1, -1, -1 }, 
    [16]i8{ 3, 1, 4, 3, 4, 8, 1, 10, 4, 7, 4, 11, 10, 11, 4, -1 }, 
    [16]i8{ 4, 11, 7, 9, 11, 4, 9, 2, 11, 9, 1, 2, -1, -1, -1, -1 }, 
    [16]i8{ 9, 7, 4, 9, 11, 7, 9, 1, 11, 2, 11, 1, 0, 8, 3, -1 }, 
    [16]i8{ 11, 7, 4, 11, 4, 2, 2, 4, 0, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 11, 7, 4, 11, 4, 2, 8, 3, 4, 3, 2, 4, -1, -1, -1, -1 }, 
    [16]i8{ 2, 9, 10, 2, 7, 9, 2, 3, 7, 7, 4, 9, -1, -1, -1, -1 }, 
    [16]i8{ 9, 10, 7, 9, 7, 4, 10, 2, 7, 8, 7, 0, 2, 0, 7, -1 }, 
    [16]i8{ 3, 7, 10, 3, 10, 2, 7, 4, 10, 1, 10, 0, 4, 0, 10, -1 }, 
    [16]i8{ 1, 10, 2, 8, 7, 4, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 9, 1, 4, 1, 7, 7, 1, 3, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 9, 1, 4, 1, 7, 0, 8, 1, 8, 7, 1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 0, 3, 7, 4, 3, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 4, 8, 7, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 10, 8, 10, 11, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 0, 9, 3, 9, 11, 11, 9, 10, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 1, 10, 0, 10, 8, 8, 10, 11, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 1, 10, 11, 3, 10, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 2, 11, 1, 11, 9, 9, 11, 8, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 0, 9, 3, 9, 11, 1, 2, 9, 2, 11, 9, -1, -1, -1, -1 }, 
    [16]i8{ 0, 2, 11, 8, 0, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 3, 2, 11, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 3, 8, 2, 8, 10, 10, 8, 9, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 9, 10, 2, 0, 9, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 2, 3, 8, 2, 8, 10, 0, 1, 8, 1, 10, 8, -1, -1, -1, -1 }, 
    [16]i8{ 1, 10, 2, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 1, 3, 8, 9, 1, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 9, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ 0, 3, 8, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 }, 
    [16]i8{ -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1 } 
};

// zig fmt: on

fn writeVertex(writer: anytype, vertex: Vector3) !void {
    _ = try writer.write(&std.mem.toBytes(vertex.x));
    _ = try writer.write(&std.mem.toBytes(vertex.y));
    _ = try writer.write(&std.mem.toBytes(vertex.z));
}

fn writeSTL(writer: anytype, vertices: []const Vector3) !void {
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

fn stepsToWorldSpace(x: usize, y: usize, z: usize, resolution: usize, bounds_min: Vector3, bounds_max: Vector3) Vector3 {
    var point: Vector3 = .{ .x = @floatFromInt(x), .y = @floatFromInt(y), .z = @floatFromInt(z) };
    point = point.divideScalar(@floatFromInt(resolution));
    point = Vector3.lerp(bounds_min, bounds_max, point);
    return point;
}

fn interp(edgeVertex1: Vector3, valueAtVertex1: f32, edgeVertex2: Vector3, valueAtVertex2: f32, threshold: f32) Vector3 {
    return .{
        .x = (edgeVertex1.x + (threshold - valueAtVertex1) * (edgeVertex2.x - edgeVertex1.x)  / (valueAtVertex2 - valueAtVertex1)),
        .y = (edgeVertex1.y + (threshold - valueAtVertex1) * (edgeVertex2.y - edgeVertex1.y)  / (valueAtVertex2 - valueAtVertex1)),
        .z = (edgeVertex1.z + (threshold - valueAtVertex1) * (edgeVertex2.z - edgeVertex1.z)  / (valueAtVertex2 - valueAtVertex1)),
    };
}

fn sphereSdf(pos: Vector3, spherePos: Vector3, radius: f32) f32 {
    const newVector: Vector3 = .{.x = pos.x - spherePos.x, .y = pos.y - spherePos.y, .z = pos.z - spherePos.z};
    return newVector.length() - radius;
}

fn circleSdf(pos: Vector2) f32 {
    return pos.length() - 1.0;
}

fn circleSdf3D(pos: Vector3) f32 {
    const newVector: Vector2 = .{.x = pos.x, .y = pos.z};
    const dist: f32 = circleSdf(newVector);
    return std.math.sqrt(dist*dist + pos.y*pos.y);
}

fn boxSdf(pos: Vector2) f32 {
    const b: Vector2 = .{.x = 1.0, .y = 1.0};
    const d: Vector2 = .{.x = @abs(pos.x) - b.x, .y = @abs(pos.y) - b.y};
    return Vector2.length(Vector2.max(d, .{.x = 0.0, .y = 0.0})) + (@min(@max(d.x, d.y), 0.0));
}

fn starSdf(pos: Vector2, r: f32, n: usize, m: f32) f32 {
    // next 4 lines can be precomputed for a given shape
    const an: f32 = 3.141593/@as(f32, @floatFromInt(n));
    const en: f32 = 3.141593/m;  // m is between 2 and n
    const acs: Vector2 = .{.x = std.math.cos(an), .y = std.math.sin(an)};
    const ecs: Vector2 = .{.x = std.math.cos(en), .y = std.math.sin(en)}; // ecs=vec2(0,1) for regular polygon

    // reduce to first sector
    var bn: f32 = std.math.atan(pos.y / pos.x);//std.math.mod(f32, std.math.atan(pos.y / pos.x), 2.0*an) catch {unreachable;} - an;
    bn = std.math.mod(f32, bn, 2.0*an) catch {unreachable;};
    bn = bn - an;

    var p: Vector2 = pos;
    const len: f32 = p.length();
    p = .{.x = std.math.cos(bn), .y = @abs(std.math.sin(bn))};
    p = p.multScalar(len);

    p = p.subtract(acs.multScalar(r));
    const thing0: f32 = -p.dot(ecs);
    const thing1: f32 = r*acs.y/ecs.y;
    const thing2: f32 = std.math.clamp(thing0, 0.0, thing1);
    const thing3: Vector2 = ecs.multScalar(thing2);
    //p = p.add(ecs.multScalar(std.math.clamp( -p.dot(ecs), 0.0, r*acs.y/ecs.y)));
    p = p.add(thing3);
    return p.length()*std.math.sign(p.x);
}

fn starSdfWrapper(pos: Vector2) f32 {
    return starSdf(pos, 0.5, 8, 3.0);
}

fn smin(a: f32, b: f32, k: f32) f32 {
    const newK = k * (1.0 / (1.0 - std.math.sqrt(0.5)));
    const h: f32 = @max(newK - @abs(a-b), 0.0) / newK;
    return @min(a, b) - newK*0.5*(1.0+h-std.math.sqrt(1.0-h*(h-2.0)));
}

fn revolve(pos: Vector3, comptime primitive: fn (pos: Vector2) f32, o: f32) f32 {
    const q: Vector2 = .{ .x = Vector2.length(Vector2{.x = pos.x, .y = pos.z}) - o, .y = pos.y };
    return primitive(q);
}

fn extrude(pos: Vector3, comptime primitive: fn (pos: Vector2) f32, h: f32) f32 {
    const d: f32 = primitive(.{.x = pos.x, .y = pos.y});
    const w: Vector2 = .{.x = d, .y = @abs(pos.z) - h};
    return @min(@max(w.x, w.y), 0.0) + Vector2.length(Vector2.max(w, .{.x = 0.0, .y = 0.0}));
}

fn extrudeTwist(pos: Vector3, comptime primitive: fn (pos: Vector2) f32, h: f32, twist: f32) f32 {
    var pos2D: Vector2 = .{.x = pos.x, .y = pos.y};
    pos2D = pos2D.rotate((pos.z / h) * std.math.degreesToRadians(twist / 2.0));
    const d: f32 = primitive(pos2D);

    const w: Vector2 = .{.x = d, .y = @abs(pos.z) - h};
    return @min(@max(w.x, w.y), 0.0) + Vector2.length(Vector2.max(w, .{.x = 0.0, .y = 0.0}));
}

fn sdf(pos: Vector3) f32 {
    const s1: f32 = extrudeTwist(pos, starSdfWrapper, 1.0, -720.0);
    const s2: f32 = extrudeTwist(pos, starSdfWrapper, 1.0, 720.0);
    return @max(s1, s2);
}

pub fn main() !void {
    const resolution: usize = 32;
    const bounds_min: Vector3 = .{ .x = -0.75, .y = -0.75, .z = -1.1 };
    const bounds_max: Vector3 = .{ .x = 0.75, .y = 0.75, .z = 1.1 };
    const threshold: f32 = 0.0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator: std.mem.Allocator = gpa.allocator();

    var verts: std.ArrayList(Vector3) = std.ArrayList(Vector3).init(allocator);
    defer verts.deinit();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    for (0..resolution - 1) |z| {
        for (0..resolution - 1) |y| {
            for (0..resolution - 1) |x| {
                const points: [8]Vector3 = [8]Vector3{
                    stepsToWorldSpace(x + 0, y + 0, z + 1, resolution, bounds_min, bounds_max), //v0
                    stepsToWorldSpace(x + 1, y + 0, z + 1, resolution, bounds_min, bounds_max), //v1
                    stepsToWorldSpace(x + 1, y + 0, z + 0, resolution, bounds_min, bounds_max), //v2
                    stepsToWorldSpace(x + 0, y + 0, z + 0, resolution, bounds_min, bounds_max), //v3
                    stepsToWorldSpace(x + 0, y + 1, z + 1, resolution, bounds_min, bounds_max), //v4
                    stepsToWorldSpace(x + 1, y + 1, z + 1, resolution, bounds_min, bounds_max), //v5
                    stepsToWorldSpace(x + 1, y + 1, z + 0, resolution, bounds_min, bounds_max), //v6
                    stepsToWorldSpace(x + 0, y + 1, z + 0, resolution, bounds_min, bounds_max), //v7
                };
                var cubeIndex: u8 = 0;
                for (0..8) |i| {
                    if (sdf(points[i]) < threshold) {
                        cubeIndex |= @as(u8, 1) << @as(u3, @intCast(i));
                    }
                }

                const edges: []const i8 = &triTable[cubeIndex];
                var i: usize = 0;
                while (edges[i] != -1) : (i += 3) {
                    const e00: u8 = edgeConnections[std.math.clamp(@as(usize, @intCast(edges[i])), 0, 11)][0];
                    const e01: u8 = edgeConnections[std.math.clamp(@as(usize, @intCast(edges[i])), 0, 11)][1];

                    const e10: u8 = edgeConnections[std.math.clamp(@as(usize, @intCast(edges[i+1])), 0, 11)][0];
                    const e11: u8 = edgeConnections[std.math.clamp(@as(usize, @intCast(edges[i+1])), 0, 11)][1];

                    const e20: u8 = edgeConnections[std.math.clamp(@as(usize, @intCast(edges[i+2])), 0, 11)][0];
                    const e21: u8 = edgeConnections[std.math.clamp(@as(usize, @intCast(edges[i+2])), 0, 11)][1];

                    try verts.append(interp(points[e00], sdf(points[e00]), points[e01], sdf(points[e01]), threshold));
                    try verts.append(interp(points[e10], sdf(points[e10]), points[e11], sdf(points[e11]), threshold));
                    try verts.append(interp(points[e20], sdf(points[e20]), points[e21], sdf(points[e21]), threshold));
                }
            }
        }
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
