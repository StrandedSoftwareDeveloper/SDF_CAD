const std = @import("std");

pub const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn zero() Vector3 {
        return .{.x = 0.0, .y = 0.0, .z = 0.0};
    }

    pub fn fromScalar(v: f32) Vector3 {
        return .{.x = v, .y = v, .z = v};
    }

    pub fn length(self: Vector3) f32 {
        return std.math.sqrt(self.length2());
    }

    pub fn length2(self: Vector3) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn lerp(minimum: Vector3, maximum: Vector3, k: Vector3) Vector3 {
        return .{ .x = std.math.lerp(minimum.x, maximum.x, k.x), .y = std.math.lerp(minimum.y, maximum.y, k.y), .z = std.math.lerp(minimum.z, maximum.z, k.z) };
    }

    pub fn divideScalar(self: Vector3, scalar: f32) Vector3 {
        return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
    }

    pub fn normalize(self: Vector3) Vector3 {
        return self.divideScalar(self.length());
    }

    pub fn subtract(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn add(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn dot(a: Vector3, b: Vector3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn approxEq(a: Vector3, b: Vector3, tolerance: f32) bool {
        return std.math.approxEqRel(f32, a.x, b.x, tolerance) and std.math.approxEqRel(f32, a.y, b.y, tolerance) and std.math.approxEqRel(f32, a.z, b.z, tolerance);
    }

    pub fn abs(self: Vector3) Vector3 {
        return .{.x = @abs(self.x), .y = @abs(self.y), .z = @abs(self.z)};
    }

    pub fn inBounds(self: Vector3, boundsMin: Vector3, boundsMax: Vector3) bool {
        return (self.x > boundsMin.x and self.y > boundsMin.y and self.z > boundsMin.z) and (self.x < boundsMax.x and self.y < boundsMax.y and self.z < boundsMax.z);
    }

    pub fn max(a: Vector3, b: Vector3) Vector3 {
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y), .z = @max(a.z, b.z) };
    }

    pub fn multScalar(a: Vector3, b: f32) Vector3 {
        return .{ .x = a.x*b, .y = a.y*b, .z = a.z*b };
    }

    pub fn mod(a: Vector3, b: f32) Vector3 {
        return .{ .x = @mod(a.x, b), .y = @mod(a.y, b), .z = @mod(a.z, b) };
    }
};

pub const Vector2 = struct {
    x: f32,
    y: f32,

    pub fn zero() Vector2 {
        return .{.x = 0.0, .y = 0.0};
    }

    pub fn abs(self: Vector2) Vector2 {
        return .{.x = @abs(self.x), .y = @abs(self.y)};
    }

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
        return .{ .x = @max(a.x, b.x), .y = @max(a.y, b.y) };
    }

    pub fn addScalar(self: *const Vector2, scalar: f32) Vector2 {
        return .{ .x = self.x + scalar, .y = self.y + scalar };
    }

    pub fn getAngle(self: *const Vector2) f32 {
        return std.math.atan2(self.y, self.x);
    }

    pub fn rotate(self: Vector2, angle: f32) Vector2 {
        const startAngle: f32 = self.getAngle();
        const len: f32 = self.length();
        return .{ .x = std.math.cos(startAngle + angle) * len, .y = std.math.sin(startAngle + angle) * len };
    }

    pub fn dot(a: Vector2, b: Vector2) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub fn add(a: Vector2, b: Vector2) Vector2 {
        return .{ .x = a.x + b.x, .y = a.y + b.y };
    }

    pub fn subtract(a: Vector2, b: Vector2) Vector2 {
        return .{ .x = a.x - b.x, .y = a.y - b.y };
    }
};
