const std = @import("std");

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
