An SDF slicer written in zig 0.12.0.

Run with `zig build run > out.gcode`

## Random notes:
- May have some things that are specific to the FlashForge Creator Pro (Pre-2016 model, but I don't think that matters)
- Very finicky
- Very much still in the "make it work" phase of "make it work, make it reliable, make it fast"

## Troubleshooting:
- If you get a weird "low quality" look on the top and/or bottom layer, try slightly offsetting the z position of your part (by less than a layer).
- If you get "All 4 points are inside!" or "All 4 points are outside!", try messing with `epsilon` in the `findDirection` function, and/or mess with the z position as above.
