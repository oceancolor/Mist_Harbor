import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, export
from math import cos, sin, pi

GOLD, GOLD_D = 'CDB97E', 'BCA76A'
# 沙滩草：金色丛生茎秆，向外披散（沙丘固沙植物 marram grass）。
for i in range(8):
    a = i * pi * 2 / 8 + 0.4
    tilt = 0.22 + (i % 3) * 0.06
    h = 0.5 + (i % 4) * 0.08
    box(f'blade_{i}', (0.05, 0.05, h),
        (cos(a) * 0.1, sin(a) * 0.1, h * 0.45),
        GOLD if i % 2 == 0 else GOLD_D,
        rotation=(sin(a) * tilt, -cos(a) * tilt, a))
export('loc_cc_nat_beachgrass')
