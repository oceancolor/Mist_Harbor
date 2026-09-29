import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import blob, export

G, GL, GD = 'B8A092', 'D8C4B4', '8A7A70'
# 花岗岩巨石（中）：双岩咬合，比大石矮一档。~1.4 x 1.3 x 1.1。
blob('main', 0.52, (0.0, 0.05, 0.44), G, (1.05, 0.95, 0.82))
blob('side', 0.34, (0.44, -0.3, 0.3), GL, (0.95, 0.9, 0.75))
blob('cap', 0.2, (-0.18, 0.22, 0.92), GD, (1.0, 0.9, 0.6), subdivisions=2)
export('loc_sy_nat_boulder_mid')
