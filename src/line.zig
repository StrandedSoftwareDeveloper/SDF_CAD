//Adapted from http://kt8216.unixcab.org/murphy/index.html
const std = @import("std");
const utils = @import("utils.zig");

fn uTOi(v: usize) isize {
    return @intCast(v);
}

fn iTOu(v: isize) usize {
    return @intCast(v);
}

fn pixel(b: utils.Bitmap, x: isize, y: isize, color: u8) void {
    b.data[@intCast(y*@as(isize, @intCast(b.width))+x)].value = color;
}

//***********************************************************************
//*                                                                     *
//*                            X BASED LINES                            *
//*                                                                     *
//***********************************************************************

fn x_perpendicular(B: utils.Bitmap, color: u8,
                       x0: isize, y0: isize, dx: isize, dy: isize, xstep: isize, ystep: isize,
                       einit: isize, w_left: isize, w_right: isize, winit: isize) void {
    var x: isize = x0;
    var y: isize = y0;
    const threshold: isize = dx - 2*dy;
    const E_diag: isize = -2*dx;
    const E_square: isize = 2*dy;

    var tk: isize = dx+dy-winit;
    var err: isize = einit;
    var p: isize = 0;
    var q: isize = 0;

    while (tk <= w_left) {
        pixel(B, x, y, color);
        if (err >= threshold) {
            x = x + xstep;
            err = err + E_diag;
            tk = tk + 2*dy;
        }
        err = err + E_square;
        y = y + ystep;
        tk = tk + 2*dx;
        q += 1;
    }

    y = y0;
    x = x0;
    err = -einit;
    tk = dx+dy+winit;

    while (tk <= w_right) {
        if (p > 0) {
            pixel(B, x, y, color);
        }

        if (err > threshold) {
            x = x - xstep;
            err = err + E_diag;
            tk = tk + 2*dy;
        }

        err = err + E_square;
        y = y - ystep;
        tk = tk + 2*dx;
        p += 1;
    }

    if (q == 0 and p < 2) {
        pixel(B, x, y, color); // we need this for very thin lines
    }
}


fn x_varthick_line(B: utils.Bitmap, color: u8,
                       x0: isize, y0: isize, dx: isize, dy: isize, xstep: isize, ystep: isize,
                       left: f64, right: f64, pxstep: isize, pystep: isize) void {
    var p_error: isize = 0;
    var err: isize = 0;
    var x: isize = x0;
    var y: isize = y0;
    const threshold: isize = dx - 2*dy;
    const E_diag: isize = -2*dx;
    const E_square: isize = 2*dy;
    const length: isize = dx+1;
    var w_left: isize = 0;
    var w_right: isize = 0;
    const D: f64 = @sqrt(@as(f64, @floatFromInt(dx*dx+dy*dy)));

    for (0..iTOu(length)) |p| {
        _ = p;
        w_left = @intFromFloat(left*2.0*D);
        w_right = @intFromFloat(right*2.0*D);
        x_perpendicular(B, color, x, y, dx, dy, pxstep, pystep, p_error, w_left, w_right, err);
        if (err >= threshold) {
            y = y + ystep;
            err = err + E_diag;
            if (p_error >= threshold) {
                x_perpendicular(B, color, x, y, dx, dy, pxstep, pystep,
                                (p_error+E_diag+E_square),
                                w_left, w_right, err);
                p_error = p_error + E_diag;
            }
            p_error = p_error + E_square;
        }
        err = err + E_square;
        x = x + xstep;
    }
}

//***********************************************************************
//*                                                                     *
//*                            Y BASED LINES                            *
//*                                                                     *
//***********************************************************************

fn y_perpendicular(B: utils.Bitmap, color: u8,
                            x0: isize, y0: isize, dx: isize, dy: isize, xstep: isize, ystep: isize,
                            einit: isize, w_left: isize, w_right: isize, winit: isize) void {
    var x: isize = x0;
    var y: isize = y0;
    const threshold: isize = dy - 2*dx;
    const E_diag: isize = -2*dy;
    const E_square: isize = 2*dx;

    var tk: isize = dx+dy+winit;
    var err: isize = -einit;
    var p: isize = 0;
    var q: isize = 0;

    while (tk <= w_left) {
        pixel(B, x, y, color);
        if (err > threshold) {
            y = y + ystep;
            err = err + E_diag;
            tk = tk + 2*dx;
        }
        err = err + E_square;
        x = x + xstep;
        tk = tk + 2*dy;
        q += 1;
    }


    y = y0;
    x = x0;
    err = einit;
    tk = dx+dy-winit;

    while (tk <= w_right) {
        if (p > 0) {
            pixel(B, x, y, color);
        }
        if (err >= threshold) {
            y = y - ystep;
            err = err + E_diag;
            tk= tk + 2*dx;
        }
        err = err + E_square;
        x= x - xstep;
        tk= tk + 2*dy;
        p += 1;
    }

    if (q == 0 and p < 2) {
        pixel(B, x, y, color); // we need this for very thin lines
    }
}


fn y_varthick_line(B: utils.Bitmap, color: u8,
                       x0: isize, y0: isize, dx: isize, dy: isize, xstep: isize, ystep: isize,
                       left: f64, right: f64, pxstep: isize, pystep: isize) void {
    var p_error: isize = 0;
    var err: isize = 0;
    var x: isize = x0;
    var y: isize = y0;
    const threshold: isize = dy - 2*dx;
    const E_diag: isize = -2*dy;
    const E_square: isize = 2*dx;
    const length: isize = dy+1;

    var w_left: isize = 0;
    var w_right: isize = 0;
    const D: f64 = @sqrt(@as(f64, @floatFromInt(dx*dx+dy*dy)));

    for(0..iTOu(length)) |p| {
        _ = p;
        w_left = @intFromFloat(left*2.0*D);
        w_right = @intFromFloat(right*2.0*D);
        y_perpendicular(B,color,x,y, dx, dy, pxstep, pystep, p_error, w_left, w_right, err);
        if (err >= threshold) {
            x = x + xstep;
            err = err + E_diag;
            if (p_error >= threshold) {
                y_perpendicular(B,color,x,y, dx, dy, pxstep, pystep, p_error+E_diag+E_square, w_left, w_right, err);
                p_error = p_error + E_diag;
            }
            p_error = p_error + E_square;
        }
        err = err + E_square;
        y = y + ystep;
    }
}


//***********************************************************************
//*                                                                     *
//*                                ENTRY                                *
//*                                                                     *
//***********************************************************************

pub fn drawThickLine(B: utils.Bitmap, color: u8,
                          x0: isize, y0: isize, x1: isize, y1: isize,
                          left: f64, right: f64) void {
    var dx: isize = x1-x0;
    var dy: isize = y1-y0;
    var xstep: isize = 1;
    var ystep: isize = 1;
    var pxstep: isize = 0;
    var pystep: isize = 0;
    var xch: isize = 0; // whether left and right get switched.

    if (dx<0) { dx= -dx; xstep= -1; }
    if (dy<0) { dy= -dy; ystep= -1; }

    if (dx==0) xstep= 0;
    if (dy==0) ystep= 0;

    switch (xstep + ystep*4) {
        (-1 + -1*4) => {pystep = -1; pxstep = 1; xch = 1;},   // -5
        (-1 +  0*4) => {pystep = -1; pxstep = 0; xch = 1;},   // -1
        (-1 +  1*4) => {pystep =  1; pxstep = 1;},   // 3
        ( 0 + -1*4) => {pystep =  0; pxstep = -1;},  // -4
        ( 0 +  0*4) => {pystep =  0; pxstep = 0;},   // 0
        ( 0 +  1*4) => {pystep =  0; pxstep = 1;},   // 4
        ( 1 + -1*4) => {pystep = -1; pxstep = -1;},  // -3
        ( 1 +  0*4) => {pystep = -1; pxstep = 0;},  // 1
        ( 1 +  1*4) => {pystep =  1; pxstep = -1; xch = 1;},  // 5
        else => {},
    }

    var l: f64 = left;
    var r: f64 = right;
    if (xch == 1) {
        const K: f64 = left;
        l = right;
        r = K;
    }

    if (dx > dy) {
        x_varthick_line(B, color, x0, y0, dx, dy, xstep, ystep,
                        l, r, pxstep, pystep);
    } else {
        y_varthick_line(B, color, x0, y0, dx, dy, xstep, ystep,
                        l, r, pxstep, pystep);
    }
}

