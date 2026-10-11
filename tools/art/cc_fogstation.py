import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, cyl, export

BODY, CAP, STACK, LAMP = 'B0B4B0', '8D9490', '6F7470', 'DCE6EA'
# 雾号站：混凝土机房 + 檐口 + 灰色雾号筒 + 顶部信号灯。
box('house', (1.1, 1.2, 1.1), (0, 0, 0.6), BODY)
box('cap', (1.2, 1.3, 0.16), (0, 0, 1.24), CAP)
box('door', (0.3, 0.06, 0.5), (0, -0.61, 0.29), '4A4E52')
cyl('stack', 0.14, 0.5, (0.2, 0.0, 1.55), STACK, vertices=9)
cyl('stack_bell', 0.2, 0.16, (0.2, 0.0, 1.86), STACK, top=0.14, vertices=9)
cyl('lamp', 0.1, 0.18, (-0.32, 0.0, 1.4), LAMP, vertices=8)
export('loc_cc_bld_fogstation')
