import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, export
from math import sin, cos

STALK, HEAD = 'B8A46A', 'C8B482'
# 苇草（塞舌尔/CC 共用）：九根细长斜秆 + 顶穗。
for i in range(9):
    x = -0.34 + (i % 3) * 0.3 + ((i // 3) % 2) * 0.08
    y = -0.3 + (i // 3) * 0.26
    h = 0.68 + ((i * 7) % 5) * 0.12
    a = i * 1.7
    tilt = 0.1 + (i % 4) * 0.05
    box(f'stalk_{i}', (0.04, 0.04, h), (x, y, h * 0.48), STALK,
        rotation=(sin(a) * tilt, 0, a))
    box(f'head_{i}', (0.06, 0.06, 0.16),
        (x, y, h * 0.95), HEAD, rotation=(sin(a) * tilt, 0, a))
export('loc_shared_nat_reeds')
