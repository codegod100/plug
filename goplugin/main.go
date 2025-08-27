package main

import (
    "fmt"
    "os"
    "strconv"
)

// TinyGo requires a main even if unused
func main() {}

//export run
func run() {
    // Parameters
    w := getenvInt("MANDEL_W", 80)
    h := getenvInt("MANDEL_H", 24)
    maxIter := getenvInt("MANDEL_ITERS", 80)

    fmt.Printf("WASM plugin: Mandelbrot demo (%dx%d, iters=%d)\n", w, h, maxIter)

    // Viewport and palette similar to the Rust plugin
    scaleX := 3.5 / float64(w)  // -2.5..1.0
    scaleY := 2.0 / float64(h)  // -1.0..1.0
    palette := []byte(" .:-=+*#%@")
    maxIdx := len(palette) - 1

    for y := 0; y < h; y++ {
        cy := -1.0 + float64(y)*scaleY
        line := make([]byte, w)
        for x := 0; x < w; x++ {
            cx := -2.5 + float64(x)*scaleX
            zx, zy := 0.0, 0.0
            iter := 0
            for zx*zx+zy*zy <= 4.0 && iter < maxIter {
                xt := zx*zx - zy*zy + cx
                zy = 2.0*zx*zy + cy
                zx = xt
                iter++
            }
            var idx int
            if iter >= maxIter {
                idx = maxIdx
            } else {
                idx = (iter * maxIdx) / maxIter
            }
            line[x] = palette[idx]
        }
        fmt.Println(string(line))
    }

    if msg := os.Getenv("PLUG_MSG"); msg != "" {
        fmt.Printf("Note: %s\n", msg)
    }
}

func getenvInt(key string, def int) int {
    if v := os.Getenv(key); v != "" {
        if n, err := strconv.Atoi(v); err == nil {
            return n
        }
    }
    return def
}
