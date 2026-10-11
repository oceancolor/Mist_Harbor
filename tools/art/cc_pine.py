import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import cyl, blob, export

TRUNK, G1, G2, G3 = '6F5A44', '2F5D3E', '38684A', '416F50'
# 海岸松：斜干两段 + 三层深绿团（新英格兰海岸的矮曲松）。总高 ~2.4。
cyl('trunk_low', 0.09, 1.2, (0.0, 0.0, 0.6), TRUNK, top=0.07, vertices=6, rotation=(0, 0.12, 0))
cyl('trunk_high', 0.07, 1.0, (0.12, 0.04, 1.5), TRUNK, top=0.05, vertices=6, rotation=(0, -0.1, 0))
blob('crown_low', 0.42, (0.05, 0.05, 1.72), G1, (1.25, 1.25, 0.8), subdivisions=3)
blob('crown_mid', 0.3, (0.18, 0.1, 2.1), G2, subdivisions=2)
blob('crown_top', 0.2, (-0.02, -0.04, 2.36), G3, subdivisions=2)
export('loc_cc_nat_pine')
