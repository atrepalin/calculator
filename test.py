from math import sin, cos, exp
from itertools import count, takewhile
import matplotlib.pyplot as plt

def frange(start, stop, step):
    return takewhile(lambda x: x < stop + step / 2, count(start, step))

def f(x):
    return cos(exp(x)) - sin(x ** 2)

x_vals = []
y_vals = []

for x in frange(-10, 10, 0.1):
    fx = f(x)
    print(f"x = {x:0.4f}, f(x) = {f(x):0.4f}")

    x_vals.append(x)
    y_vals.append(fx)

plt.plot(x_vals, y_vals, label=r"$\cos(e^x) - \sin(x^2)$")
plt.title("Plot of f(x) = cos(exp(x)) - sin(x²)")
plt.xlabel("x")
plt.ylabel("f(x)")
plt.grid(True)
plt.legend()
plt.show()
