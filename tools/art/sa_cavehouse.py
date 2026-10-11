import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from _kit import box, blob, export

ROCK, DARK, WARM = 'D4C4A8', '5B5148', 'EAC989'
# 洞穴屋：凝灰岩体块（两块咬合）+ 凹入的 dark 门洞 + 暖光内透。
box('rock_main', (1.9, 1.9, 1.85), (0, 0, 0.925), ROCK)
box('rock_shoulder', (1.5, 1.7, 0.5), (0.15, 0.1, 2.05), ROCK)
box('door_recess', (0.8, 0.12, 1.05), (0.1, -0.92, 0.58), DARK)
box('door_frame', (0.95, 0.08, 1.15), (0.1, -0.94, 0.62), DARK)
box('hearth', (0.45, 0.16, 0.45), (0.1, -0.86, 0.52), WARM, rough=0.4)
box('chimney', (0.4, 0.4, 0.35), (0.4, 0.35, 2.4), ROCK)
export('loc_sa_bld_cavehouse')
