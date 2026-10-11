import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import torus, blob, cyl, export

VINE, GRAPE, LEAF, WOOD = '7A8A5A', '6B4E78', '5F8F5A', '8A6F50'
# 葡萄藤篮：编织圆篮（圆环体）+ 翻出的藤蔓 + 紫葡萄串。
torus('basket', 0.4, 0.2, (0, 0, 0.24), VINE)
cyl('basket_base', 0.38, 0.06, (0, 0, 0.05), WOOD, vertices=9)
for i, (dx, dy, a) in enumerate([(0.34, 0.1, 0.0), (-0.3, 0.22, 1.1), (0.05, -0.36, 2.2)]):
    cyl(f'vine_{i}', 0.03, 0.4, (dx, dy, 0.5), VINE, vertices=5, rotation=(0.35, a, 0))
    blob(f'grapes_{i}', 0.09, (dx * 1.15, dy * 1.15, 0.4), GRAPE, subdivisions=2)
blob('leaf', 0.1, (0.18, 0.3, 0.66), LEAF, (1.2, 1.0, 0.5), subdivisions=2)
export('loc_sa_nat_vine')
