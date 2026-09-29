import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, export

W, W2, B, WOOD = 'F8F8F4', 'EDEDE6', '2A6CB4', 'C8B49A'
# 白墙屋 C（两层露台版）：主屋 + 头层退台 + 白栏杆 + 拱门洞。
box('body', (1.9, 1.9, 1.3), (0, 0.1, 0.65), W)
box('upper', (1.55, 1.55, 0.85), (0, 0.1, 1.72), W)
box('parapet', (1.62, 1.62, 0.1), (0, 0.1, 2.2), W2)
# 二层露台（头层屋顶上，-Y 侧）
box('terrace', (1.5, 0.42, 0.08), (0, -0.75, 1.34), W2)
box('rail', (1.5, 0.07, 0.3), (0, -0.95, 1.53), W)
box('door', (0.44, 0.08, 0.75), (0, -0.88, 0.48), B)
box('arch_hole', (0.5, 0.1, 0.6), (0, -0.92, 1.55), B)
box('win', (0.36, 0.08, 0.36), (0.42, -0.9, 0.85), B)
export('loc_sa_bld_whitehouse_c')
