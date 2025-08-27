use std::env;

// Simple integer addition to demonstrate typed host calls
#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

// Naive Fibonacci for demonstration (u32 input, u64 output)
#[no_mangle]
pub extern "C" fn fib(n: u32) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a: u64 = 0;
            let mut b: u64 = 1;
            for _ in 2..=n {
                let next = a + b;
                a = b;
                b = next;
            }
            b
        }
    }
}

// Render a small Mandelbrot set in ASCII to stdout.
// Width/height can be configured via env vars: MANDEL_W, MANDEL_H, and max iterations via MANDEL_ITERS.
#[no_mangle]
pub extern "C" fn run() {
    let width: usize = env::var("MANDEL_W").ok().and_then(|v| v.parse().ok()).unwrap_or(80);
    let height: usize = env::var("MANDEL_H").ok().and_then(|v| v.parse().ok()).unwrap_or(24);
    let max_iter: u32 = env::var("MANDEL_ITERS").ok().and_then(|v| v.parse().ok()).unwrap_or(80);

    println!("WASM plugin: Mandelbrot demo ({}x{}, iters={})", width, height, max_iter);

    // Compute viewport preserving aspect ratio
    let scale_x = 3.5 / width as f64; // from -2.5 to 1.0
    let scale_y = 2.0 / height as f64; // from -1.0 to 1.0

    let palette = b" .:-=+*#%@"; // 10 shades

    for y in 0..height {
        let mut line = String::with_capacity(width);
        let cy = -1.0 + y as f64 * scale_y;
        for x in 0..width {
            let cx = -2.5 + x as f64 * scale_x;
            let mut zx = 0.0f64;
            let mut zy = 0.0f64;
            let mut iter = 0u32;
            while zx * zx + zy * zy <= 4.0 && iter < max_iter {
                let xt = zx * zx - zy * zy + cx;
                zy = 2.0 * zx * zy + cy;
                zx = xt;
                iter += 1;
            }
            let idx = if iter >= max_iter { palette.len() - 1 } else { (iter as usize * (palette.len() - 1)) / (max_iter as usize) };
            line.push(palette[idx] as char);
        }
        println!("{}", line);
    }

    // Optional friendly message from env var
    if let Ok(msg) = env::var("PLUG_MSG") {
        println!("Note: {}", msg);
    }
}
