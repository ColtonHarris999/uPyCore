def work():
    mapping = {"left-right": 7}
    total = 0
    for i in range(80):
        left = "-".join(["left", "right"])
        right = "".join(["left-", "right"])
        data = b"left" + bytes([45]) + b"right"
        total += left == right
        total += mapping[right]
        total += "right" in left
        total += len(left[2:8] + right[3:7])
        for char in left:
            total += ord(char)
        for byte in data:
            total += byte
    return total


print(work())
