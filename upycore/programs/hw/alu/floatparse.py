# Float and complex spellings the other alu tests never reach:
# scientific notation, subnormals, signed zero, underscores, inf/nan,
# and complex() text (a real part plus an imag part).

def show(x):
    print(x)


print("lit")
show(0.1)
show(0.3)
show(1.5e-1)
show(1e2)
show(1e39)
show(1e-45)
show(1e-46)
show(-0.0)
show(1.0000000000000002)
show(6.02214076e23)
show(1.1754944e-38)
show(123456789.0)
show(1_000.5)
show(.5)
show(1.)
show(00.5)
show(2.5E+1)

print("imag")
show(1j)
show(1.5j)
show(1e2j)
show(1.5e-1j)
show(1e-45j)
show(-0.0j)
show(1.25+3.5j)
show(-2.5e1+3j)
show(1.5-2j)

print("rt")
show(float("0.1"))
show(float("1.5e-1"))
show(float("1e-45"))
show(float("1e39"))
show(float("-0.0"))
show(float("  1.5e-1  "))
show(float("+1.5"))
show(float("inf"))
show(float("-inf"))
show(float("Inf"))
show(float("infinity"))
show(float("-INFINITY"))
show(float("nan"))
show(float("NaN"))
show(float("nAn"))
show(float("1_000.5"))
show(float("1e_2"))
show(float("_1.5"))
show(float("1e309"))
show(float("1e-400"))
show(complex("1j"))
show(complex("j"))
show(complex("-j"))
show(complex("J"))
show(complex("1.5e-1j"))
show(complex("1.25+3.5j"))
show(complex("-2.5e1+3j"))
show(complex("1.5-2j"))
show(complex("  1+2j  "))
show(complex("infj"))
show(complex("inf+nanj"))
show(complex("1e_2j"))
show(complex("nan"))

print("cmp")
print(0.1 == float("0.1"))
print(1.5e-1 == float("1.5e-1"))
print(1e-45 == float("1e-45"))
print(-0.0 == float("-0.0"))
print((1.25+3.5j) == complex("1.25+3.5j"))
print(1j == complex("j"))


def bad(s):
    try:
        print("bad", float(s))
    except Exception as e:
        print("bad", type(e).__name__)


def badc(s):
    try:
        print("badc", complex(s))
    except Exception as e:
        print("badc", type(e).__name__)


bad("")
bad("1.2.3")
bad("++1")
bad("nanx")
bad("1e")
bad("1e+")
bad(" ")
badc("1+2")
badc("1+2jj")
badc("(1+2j")
badc("1+")
badc("++1j")
badc("(1.25+3.5j)")
