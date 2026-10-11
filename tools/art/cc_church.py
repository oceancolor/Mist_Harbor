import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, cyl, export
from math import pi

WHITE, ROOF_C, STEEPLE, DOOR = 'F2EFE6', '5A6068', 'EFEAE0', '3E4448'
# 新英格兰教堂：白板墙 + 灰坡顶 + 正面尖塔钟楼。总高 ~3.0。
box('nave', (1.9, 1.5, 1.1), (0, 0.35, 0.55), WHITE)
cyl('roof', 0.85, 0.55, (0, 0.35, 1.36), ROOF_C, top=0.05, vertices=4, rotation=(0, 0, pi / 4))
box('tower', (0.42, 0.42, 1.7), (0, -0.62, 0.85), WHITE)
cyl('tower_roof', 0.34, 0.5, (0, -0.62, 1.95), ROOF_C, top=0.02, vertices=4, rotation=(0, 0, pi / 4))
box('door', (0.3, 0.06, 0.62), (0, -0.84, 0.31), DOOR)
box('tower_win', (0.18, 0.05, 0.3), (0, -0.845, 1.2), DOOR)
export('loc_cc_bld_church')
