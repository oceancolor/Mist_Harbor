import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import cyl, box, export

BODY, RED, DARK, LANTERN, ROOF_C = 'E8E4DC', 'C0493F', '4A4F55', 'EAF2F6', '5C4A3E'
# Nauset Light：红白条纹锥塔（三层红纹）+ 廊台 + 灯室 + 锥顶。总高 ~3.3。
cyl('base', 0.52, 0.28, (0, 0, 0.14), 'B9BCAD', vertices=10)
tiers, h = 6, (3.0 - 0.6) / 6 + 0.02
for i in range(tiers):
    r = 0.48 - i * 0.045
    y = 0.3 + (i + 0.5) * (3.0 - 0.6) / 6
    cyl(f'tier_{i}', r, h, (0, 0, y), RED if i % 2 == 1 else BODY, vertices=10)
cyl('gallery', 0.34, 0.24, (0, 0, 2.62), DARK, vertices=10)
cyl('lantern', 0.24, 0.3, (0, 0, 2.88), LANTERN, vertices=10)
cyl('cap', 0.34, 0.28, (0, 0, 3.16), ROOF_C, top=0.02, vertices=10)
box('door', (0.28, 0.06, 0.56), (0, -0.46, 0.3), DARK)
export('loc_cc_bld_nauset')
