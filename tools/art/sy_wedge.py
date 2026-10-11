import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, export

A, B = 'A89889', '8F8275'
# 楔石：两块斜倚的花岗岩板（巨石阵的搭接件）。
box('slab_low', (0.8, 0.7, 0.3), (0, 0, 0.2), A, rotation=(0.08, 0.1, 0))
box('slab_lean', (0.42, 0.44, 0.5), (0.05, 0.08, 0.52), B,
    rotation=(0.3, -0.12, 0.12))
export('loc_sy_nat_wedge')
