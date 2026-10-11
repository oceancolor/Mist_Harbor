import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, cyl, export

W, W2, B, WOOD = 'F8F8F4', 'EDEDE6', '2A6CB4', 'C8B49A'
# 白墙屋 B（拱廊门廊版）：主屋 + 前廊三拱 + 台阶。
box('body', (1.9, 1.9, 2.0), (-0.1, 0.1, 1.0), W)
box('parapet', (1.96, 1.96, 0.12), (-0.1, 0.1, 2.06), W2)
box('porch_floor', (1.5, 0.5, 0.14), (-0.1, -0.9, 0.1), W2)
box('porch_step', (1.2, 0.36, 0.1), (-0.1, -1.15, 0.05), W2)
for dx in (-0.62, -0.1, 0.42):
    box(f'arch_{dx}', (0.2, 0.1, 0.85), (dx, -0.72, 0.62), W)
box('arch_beam', (1.5, 0.12, 0.16), (-0.1, -0.72, 1.1), W)
box('door', (0.44, 0.08, 0.78), (-0.1, -0.88, 0.52), B)
box('win', (0.38, 0.08, 0.38), (0.42, -0.9, 1.3), B)
export('loc_sa_bld_whitehouse_b')
