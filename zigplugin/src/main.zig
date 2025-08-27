const std = @import("std");

fn getenvInt(key: []const u8, default_value: i32) i32 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const val = std.process.getEnvVarOwned(a, key) catch return default_value;
    defer a.free(val);
    return std.fmt.parseInt(i32, val, 10) catch default_value;
}

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub export fn fib(n: u32) u64 {
    if (n == 0) return 0;
    if (n == 1) return 1;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const next = a + b;
        a = b;
        b = next;
    }
    return b;
}

pub export fn run() void {
    const w = getenvInt("MANDEL_W", 80);
    const h = getenvInt("MANDEL_H", 24);
    var max_iter_i = getenvInt("MANDEL_ITERS", 80);
    if (max_iter_i < 1) max_iter_i = 1;
    const max_iter: u32 = @intCast(max_iter_i);

    var stdout = std.io.getStdOut().writer();
    _ = stdout.print("WASM plugin: Mandelbrot demo ({}x{}, iters={})\n", .{ w, h, max_iter }) catch return;

    const palette = " .:-=+*#%@"; // 10 shades
    const max_idx: usize = palette.len - 1;

    const scale_x = 3.5 / @as(f64, @floatFromInt(w));
    const scale_y = 2.0 / @as(f64, @floatFromInt(h));

    var y: i32 = 0;
    while (y < h) : (y += 1) {
        const cy = -1.0 + @as(f64, @floatFromInt(y)) * scale_y;
        var line = std.ArrayList(u8).init(std.heap.page_allocator);
        defer line.deinit();
        line.ensureTotalCapacity(@intCast(w)) catch return;

        var x: i32 = 0;
        while (x < w) : (x += 1) {
            const cx = -2.5 + @as(f64, @floatFromInt(x)) * scale_x;
            var zx: f64 = 0.0;
            var zy: f64 = 0.0;
            var iter: u32 = 0;
            while (zx * zx + zy * zy <= 4.0 and iter < max_iter) : (iter += 1) {
                const xt = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = xt;
            }
            const idx: usize = if (iter >= max_iter)
                max_idx
            else
                @intCast((iter * @as(u32, @intCast(max_idx))) / max_iter);
            line.append(palette[idx]) catch return;
        }
        _ = stdout.print("{s}\n", .{line.items}) catch return;
    }

    if (std.process.getEnvVarOwned(std.heap.page_allocator, "PLUG_MSG")) |msg| {
        defer std.heap.page_allocator.free(msg);
        _ = stdout.print("Note: {s}\n", .{msg}) catch {};
    } else |_| {}
}

// No entry point: compile with -fno-entry to avoid a start function.
