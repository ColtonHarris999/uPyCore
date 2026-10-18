from array import array

a = array("i")
a.append(1)
a.append(-2)
a.extend([3, 4])
a[1] = 5
print(len(a), a[0], a[1], a[2], a[3])
b = array("i", [10, 20, 30])
print(b[0], b[-1])
b[2:] = array("i")
print(len(b), b[0], b[1])
h = array("H", (1, 2, 65535))
print(h[0], h[1], h[2])
u = array("I")
u.append(8)
print(len(u), u[0])
print(1 if a else 0, 1 if array("i") else 0)
