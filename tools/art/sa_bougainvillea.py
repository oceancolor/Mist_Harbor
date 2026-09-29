import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import cyl, blob, export
from math import cos, sin, pi

STEM, PINK, PINK_D = '6F7A4A', 'D4537E', 'B8436C'
# 三角梅：细弯干 + 五团洋红苞片（两档高）。
cyl('trunk', 0.055, 0.55, (0, 0, 0.27), STEM, top=0.04, vertices=6, rotation=(0.1, 0, 0))
for i in range(5):
    a = i * pi * 2 / 5 + 0.3
    x, y = 0.06 + cos(a) * 0.2, sin(a) * 0.2
    blob(f'bloom_{i}', 0.16, (x, y, 0.56 + (i % 2) * 0.15),
         PINK if i % 2 == 0 else PINK_D, (1.0, 1.0, 0.85), subdivisions=2)
blob('bloom_crown', 0.12, (0.02, 0.05, 0.78), PINK, subdivisions=2)
export('loc_sa_nat_bougainvillea')
