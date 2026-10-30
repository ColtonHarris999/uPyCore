from array import array

for code in ('i', 'I', 'H'):
    for start, stop in ((3, 1), (3, 3), (-1, -3), (-100, -100), (100, 100)):
        a = array(code, [1, 2, 3, 4])
        a[start:stop] = array(code, [9])
        print(code, list(a))
    a = array(code, [1, 2, 3, 4])
    a[3:1] = a
    print(code, list(a))
