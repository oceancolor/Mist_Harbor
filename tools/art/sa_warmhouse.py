import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, export

OCHRE, W, B = 'D8A05A', 'F8F8F4', '2A6CB4'
# 彩色小屋：暖赭墙 + 白平顶 + 蓝门 + 白色挑檐雨棚。
box('body', (1.9, 1.9, 1.6), (0, 0, 0.8), OCHRE)
box('roof', (2.0, 2.0, 0.14), (0, 0, 1.67), W)
box('door', (0.36, 0.08, 0.72), (0, -0.96, 0.42), B)
box('awning', (0.5, 0.22, 0.05), (0, -1.06, 0.86), W)
box('win', (0.32, 0.08, 0.32), (0.55, -0.96, 0.95), W)
box('trim', (1.96, 1.96, 0.07), (0, 0, 0.035), W)
export('loc_sa_bld_warmhouse')
