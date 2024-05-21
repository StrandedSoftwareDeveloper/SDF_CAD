const std = @import("std");
const vec = @import("vector.zig");

pub fn sphereSdf(pos: vec.Vector3, spherePos: vec.Vector3, radius: f32) f32 {
    const newVector: vec.Vector3 = .{ .x = pos.x - spherePos.x, .y = pos.y - spherePos.y, .z = pos.z - spherePos.z };
    return newVector.length() - radius;
}

pub fn circleSdf(pos: vec.Vector2) f32 {
    return pos.length() - 1.0;
}

pub fn circleSdf3D(pos: vec.Vector3) f32 {
    const newVector: vec.Vector2 = .{ .x = pos.x, .y = pos.z };
    const dist: f32 = circleSdf(newVector);
    return std.math.sqrt(dist * dist + pos.y * pos.y);
}

pub fn boxSdf(pos: vec.Vector2) f32 {
    const b: vec.Vector2 = .{ .x = 1.0, .y = 1.0 };
    const d: vec.Vector2 = .{ .x = @abs(pos.x) - b.x, .y = @abs(pos.y) - b.y };
    return vec.Vector2.length(vec.Vector2.max(d, .{ .x = 0.0, .y = 0.0 })) + (@min(@max(d.x, d.y), 0.0));
}

pub fn starSdf(pos: vec.Vector2, r: f32, n: usize, m: f32) f32 {
    // next 4 lines can be precomputed for a given shape
    const an: f32 = 3.141593 / @as(f32, @floatFromInt(n));
    const en: f32 = 3.141593 / m; // m is between 2 and n
    const acs: vec.Vector2 = .{ .x = std.math.cos(an), .y = std.math.sin(an) };
    const ecs: vec.Vector2 = .{ .x = std.math.cos(en), .y = std.math.sin(en) }; // ecs=vec2(0,1) for regular polygon

    // reduce to first sector
    var bn: f32 = std.math.atan(pos.y / pos.x); //std.math.mod(f32, std.math.atan(pos.y / pos.x), 2.0*an) catch {unreachable;} - an;
    bn = std.math.mod(f32, bn, 2.0 * an) catch {
        unreachable;
    };
    bn = bn - an;

    var p: vec.Vector2 = pos;
    const len: f32 = p.length();
    p = .{ .x = std.math.cos(bn), .y = @abs(std.math.sin(bn)) };
    p = p.multScalar(len);

    p = p.subtract(acs.multScalar(r));
    const thing0: f32 = -p.dot(ecs);
    const thing1: f32 = r * acs.y / ecs.y;
    const thing2: f32 = std.math.clamp(thing0, 0.0, thing1);
    const thing3: vec.Vector2 = ecs.multScalar(thing2);
    //p = p.add(ecs.multScalar(std.math.clamp( -p.dot(ecs), 0.0, r*acs.y/ecs.y)));
    p = p.add(thing3);
    return p.length() * std.math.sign(p.x);
}

pub fn smin(a: f32, b: f32, k: f32) f32 {
    const newK = k * (1.0 / (1.0 - std.math.sqrt(0.5)));
    const h: f32 = @max(newK - @abs(a - b), 0.0) / newK;
    return @min(a, b) - newK * 0.5 * (1.0 + h - std.math.sqrt(1.0 - h * (h - 2.0)));
}

pub fn revolve(pos: vec.Vector3, comptime primitive: fn (pos: vec.Vector2) f32, o: f32) f32 {
    const q: vec.Vector2 = .{ .x = vec.Vector2.length(vec.Vector2{ .x = pos.x, .y = pos.z }) - o, .y = pos.y };
    return primitive(q);
}

pub fn extrude(pos: vec.Vector3, comptime primitive: fn (pos: vec.Vector2) f32, h: f32) f32 {
    const d: f32 = primitive(.{ .x = pos.x, .y = pos.y });
    const w: vec.Vector2 = .{ .x = d, .y = @abs(pos.z) - h };
    return @min(@max(w.x, w.y), 0.0) + vec.Vector2.length(vec.Vector2.max(w, .{ .x = 0.0, .y = 0.0 }));
}

pub fn extrudeTwist(pos: vec.Vector3, comptime primitive: fn (pos: vec.Vector2) f32, h: f32, twist: f32) f32 {
    var pos2D: vec.Vector2 = .{ .x = pos.x, .y = pos.y };
    pos2D = pos2D.rotate((pos.z / h) * std.math.degreesToRadians(twist / 2.0));
    const d: f32 = primitive(pos2D);

    const w: vec.Vector2 = .{ .x = d, .y = @abs(pos.z) - h };
    return @min(@max(w.x, w.y), 0.0) + vec.Vector2.length(vec.Vector2.max(w, .{ .x = 0.0, .y = 0.0 }));
}

pub fn gradient(pos: vec.Vector3, comptime sdf: fn (pos: vec.Vector3) f32) vec.Vector3 {
    const d: f32 = 0.01; //Delta
    const f0: f32 = sdf(pos);
    const fx: f32 = sdf(.{ .x = pos.x + d, .y = pos.y, .z = pos.z });
    const fy: f32 = sdf(.{ .x = pos.x, .y = pos.y + d, .z = pos.z });
    const fz: f32 = sdf(.{ .x = pos.x, .y = pos.y, .z = pos.z + d });

    return .{ .x = (f0 - fx) / d, .y = (f0 - fy) / d, .z = (f0 - fz) / d };
}

pub fn calcNormal(pos: vec.Vector3, comptime sdf: fn (pos: vec.Vector3) f32) vec.Vector3 {
    return gradient(pos, sdf).normalize();
}

//Somewhat cursed way I figured out to calculate tangent and bitangent
//Remember that the cross product of 2 vectors gives a vector that is perpendicular to both
pub fn calcTangent(normal: vec.Vector3) vec.Vector3 {
    const tempVec: vec.Vector3 = .{ .x = std.math.tan(normal.x), .y = normal.y, .z = normal.z };
    return normal.cross(tempVec).normalize();
}

pub fn calcBitangent(normal: vec.Vector3, tangent: vec.Vector3) vec.Vector3 {
    return normal.cross(tangent).normalize();
}

//Calculates the normal, tangent, and bitangent all in one go
//The output matrix is arranged as:
//[normal,
// tangent,
// bitangent]
pub fn calcNTB(pos: vec.Vector3, comptime sdf: fn (pos: vec.Vector3) f32) vec.Mat3 {
    const d: f32 = 0.01; //Delta
    const f0: f32 = sdf(pos);
    const fx: f32 = sdf(.{ .x = pos.x + d, .y = pos.y, .z = pos.z });
    const fy: f32 = sdf(.{ .x = pos.x, .y = pos.y + d, .z = pos.z });
    const fz: f32 = sdf(.{ .x = pos.x, .y = pos.y, .z = pos.z + d });

    const grad: vec.Vector3 = .{ .x = (f0 - fx) / d, .y = (f0 - fy) / d, .z = (f0 - fz) / d };

    var NTB: vec.Mat3 = std.mem.zeroes(vec.Mat3);
    NTB.r0 = grad.normalize(); //Normal

    const c0: vec.Vector3 = NTB.r0.cross(.{ .x = 1.0, .y = 0.0, .z = 0.0 });
    const c1: vec.Vector3 = NTB.r0.cross(.{ .x = 0.0, .y = 1.0, .z = 0.0 });
    if (c0.length2() > c1.length2()) {
        NTB.r1 = c0.normalize();
    } else {
        NTB.r1 = c1.normalize();
    }

    NTB.r2 = NTB.r0.cross(NTB.r1).normalize();

    return NTB;
}
