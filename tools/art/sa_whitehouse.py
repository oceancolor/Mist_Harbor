import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, cyl, blob, export

W, W2, B = 'F8F8F4', 'EDEDE6', '2A6CB4'
# 白墙屋：2x2x2 方体 + 白色压顶 + 蓝门蓝窗（-Y 面）。
box('body', (2.0, 2.0, 2.0), (0, 0, 1.0), W)
box('parapet', (2.06, 2.06, 0.12), (0, 0, 2.06), W2)
box('door', (0.46, 0.08, 0.8), (0, -0.98, 0.5), B)
box('win_lo', (0.42, 0.08, 0.42), (0.55, -0.98, 0.5), B)
box('win_hi', (0.38, 0.08, 0.38), (-0.5, -0.98, 1.25), B)
box('side_win', (0.08, 0.42, 0.38), (-0.98, 0.35, 1.15), B)
export('loc_sa_bld_whitehouse')
