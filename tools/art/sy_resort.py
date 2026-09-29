import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, cyl, blob, export
from math import cos, sin, pi

WALL, ROOF_C, POOL, DECK, TRUNK, LEAF = 'F6F1E4', 'C9B07E', '5FD4CE', 'D9C9A8', '9A8262', '37935A'
# 度假村：两排白色平房 + 中间无边泳池 + 棕榈。跨度 ~4.4 x 3.3。
for y in (-1.15, 1.15):
    box(f'bungalow_{y}', (3.4, 1.0, 0.9), (0.1, y, 0.45), WALL)
    box(f'roof_{y}', (3.5, 1.1, 0.16), (0.1, y, 0.95), ROOF_C)
box('pool', (1.5, 1.9, 0.22), (0.1, 0.0, 0.14), POOL)
box('deck', (0.9, 0.9, 0.14), (-1.5, 0.0, 0.7), DECK)
cyl('palm_trunk', 0.09, 1.7, (1.75, 0.6, 0.85), TRUNK, vertices=6)
blob('palm_crown', 0.5, (1.75, 0.6, 1.85), LEAF, (1.3, 1.3, 0.7), subdivisions=2)
export('loc_sy_bld_resort')
