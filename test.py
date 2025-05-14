from math import sin, cos, exp
from itertools import count, takewhile

def frange(start, stop, step):
    return takewhile(lambda x: x < stop + step / 2, count(start, step))

def f(x):
    return cos(exp(x)) - sin(x ** 2)

for x in frange(-10, 10, 1):
    print(f"x = {x:0.4f}, f(x) = {f(x):0.4f}")