import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import cyl, box, export
from math import cos, sin, pi

TRUNK, FROND, RIB = '9A8262', '37935A', '2E7A4E'
# 棕榈：直干 2.6 + 六片挺翘羽叶（环放射）。
cyl('trunk', 0.11, 2.6, (0, 0, 1.3), TRUNK, top=0.08, vertices=7)
cyl('trunk_crown', 0.14, 0.12, (0, 0, 2.62), TRUNK, vertices=7)
for i in range(6):
    a = i * pi / 3.0 + 0.4
    box(f'frond_{i}', (1.7, 0.07, 0.3),
        (cos(a) * 0.85, sin(a) * 0.85, 2.58),
        FROND if i % 2 == 0 else RIB, rotation=(0, -0.42, -a))
export('loc_sy_nat_palm')
