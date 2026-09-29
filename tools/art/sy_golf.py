import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, blob, cyl, export

GREEN_C, SAND, POLE, FLAG = '6FBF63', 'EFE6C8', 'F5F2EA', 'D94F4F'
# 高尔夫果岭：修剪草坪 + 月牙沙坑 + 旗杆红旗。
box('green', (2.9, 2.9, 0.1), (0, 0, 0.06), GREEN_C)
blob('bunker', 0.4, (0.45, -0.85, 0.1), SAND, (1.25, 0.9, 0.28), subdivisions=2)
cyl('pole', 0.02, 0.9, (0.85, 0.4, 0.55), POLE, vertices=5)
box('flag', (0.26, 0.02, 0.18), (0.72, 0.4, 0.92), FLAG)
blob('hole', 0.07, (0.85, 0.4, 0.115), '3E4448', (1, 1, 0.3), subdivisions=1)
export('loc_sy_bld_golf')
