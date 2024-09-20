const std = @import("std");
const vec = @import("vector.zig");

pub const Bitmap = struct {
    data: []BitmapEntry,
    width: usize,
    height: usize,
};

pub const BitmapEntry = struct {
    value: u8,
    x: f32,
    y: f32,
};

pub const ToolpathEntry = struct {
    pos: vec.Vector3,
    travel: bool,
};
