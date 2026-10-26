# Float-heavy inner loop (mandelbrot escape counts).
def mandel(w, h, it):
    s = 0
    for py in range(h):
        y0 = py * 2.0 / h - 1.0
        for px in range(w):
            x0 = px * 3.0 / w - 2.0
            x = 0.0; y = 0.0; n = 0
            while n < it and x * x + y * y < 4.0:
                x, y = x * x - y * y + x0, 2.0 * x * y + y0
                n += 1
            s += n
    return s
print(mandel(16, 12, 24))
