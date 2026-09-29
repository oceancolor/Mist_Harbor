import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, cyl, blob, export

STONE, WOOD, GREEN, PURPLE = 'D9D2C0', '9A7B58', '6FA36A', '7A4E68'
# 地中海花园：石阶平台 + 木棚架（四柱两梁五条）+ 两盆植物。
box('terrace', (1.9, 1.9, 0.16), (0, 0, 0.08), STONE)
box('step', (1.9, 0.4, 0.1), (0, -1.1, 0.05), STONE)
for i, (dx, dy) in enumerate([(-0.72, -0.72), (0.72, -0.72), (-0.72, 0.72), (0.72, 0.72)]):
    box(f'post_{i}', (0.09, 0.09, 0.9), (dx, dy, 0.61), WOOD)
box('beam_a', (1.9, 0.09, 0.06), (0, -0.72, 1.08), WOOD)
box('beam_b', (1.9, 0.09, 0.06), (0, 0.72, 1.08), WOOD)
for i in range(5):
    box(f'slat_{i}', (0.06, 1.5, 0.05), (-0.72 + i * 0.36, 0, 1.08), WOOD)
cyl('pot_a', 0.14, 0.22, (-0.5, 0.2, 0.27), TERRA := 'B0764F', top=0.17, vertices=8)
blob('plant_a', 0.2, (-0.5, 0.2, 0.52), GREEN, (1.0, 1.0, 0.6), subdivisions=2)
cyl('pot_b', 0.12, 0.2, (0.5, 0.28, 0.26), TERRA, top=0.15, vertices=8)
blob('plant_b', 0.16, (0.5, 0.28, 0.48), PURPLE, (1.2, 1.2, 0.6), subdivisions=2)
export('loc_sa_bld_medgarden')
