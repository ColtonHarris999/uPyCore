t = (10, 20)
print(t.index(10, -100), t.index(20, -100, 100))
for value, start, stop in ((2, -3, 2), (10, 3, 100), (10, -100, -100)):
    try:
        print(t.index(value, start, stop))
    except ValueError:
        print('ValueError')
try:
    ().index(0, -100)
except ValueError:
    print('ValueError')
