# 统计现状地形几何规模（复现 world_model.gd:reset() + build_world.gd 的面剔除）
# 用途：给出立方体改造前/后的三角数与顶点数基线，供 R-D 判断。不依赖 Godot。
import json, math

PALETTE = json.load(open('project/data/palette.json', encoding='utf-8'))
CUBE = {i['id'] for i in PALETTE['items'] if i.get('mesh') == 'cube'}
HEIGHT = {i['id']: i.get('height', 1) for i in PALETTE['items']}
RELIEF = {i['id']: i.get('relief', {}) for i in PALETTE['items']}

DIRS = [(0, 1, 0), (0, -1, 0), (1, 0, 0), (-1, 0, 0), (0, 0, 1), (0, 0, -1)]


def hash_noise(x, z, seed=240910):
    """近似 FastNoiseLite 的 [-1,1] 输出（真实曲线不同，只用于岸线粗糙度敏感性分析）"""
    h = (x * 374761393 + z * 668265263 + seed * 1274126177) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 32767.5 - 1.0


def build(noise_mode):
    cells = {}
    for x in range(-21, 22):
        for z in range(-20, 22):
            a = math.hypot((x + 4.0) / 11.0, (z + 1.0) / 9.0)
            b = math.hypot((x - 12.0) / 5.0, (z - 7.0) / 5.6)
            c = math.hypot((x + 12.0) / 4.0, (z + 14.0) / 3.3)
            distance = min(a, b, c)
            n = 0.0 if noise_mode == 'flat' else hash_noise(x, z)
            if distance > 0.95 + n * 0.18:
                continue
            height = 0
            if a < 0.62:
                height = 1
            if a < 0.29:
                height = 2
            for y in range(-3, height + 1):
                kind = 'stone'
                if y == height:
                    kind = 'grass' if distance < 0.85 else 'wood'
                cells[(x, y, z)] = kind
    return cells


def count(cells):
    """按 kind 分组统计暴露面：{kind: [top, side, bottom]}"""
    stat = {}
    for (x, y, z), kind in cells.items():
        if kind not in CUBE:
            continue
        acc = stat.setdefault(kind, [0, 0, 0])
        for dx, dy, dz in DIRS:
            nb = cells.get((x + dx, y + dy, z + dz))
            if nb is None or nb not in CUBE:
                acc[0 if dy == 1 else (1 if dy == -1 else 2)] += 1
    return stat


# 新方案三角数：顶面 2*N^2（N 取自该 kind 的 top_div）/ 侧面 3列×2行 = 4 / 底面 2
def tris_new(stat, quality=None):
    total = 0
    for kind, (top, bottom, side) in stat.items():
        div = RELIEF.get(kind, {}).get('top_div', 2)
        if quality is not None:
            div = min(div, quality)
        if quality == 0:
            div = 1
        total += top * (2 * div * div) + side * 4 + bottom * 2
    return total


for mode in ('flat', 'hash'):
    cells = build(mode)
    stat = count(cells)
    faces = sum(sum(v) for v in stat.values())
    old_t = faces * 2
    print(f'--- noise={mode} ---')
    print(f'  cells 总数        {len(cells)}')
    for kind, (top, bottom, side) in sorted(stat.items()):
        print(f'    {kind:6s} 顶{top:5d} 侧{side:5d} 底{bottom:5d}')
    print(f'  暴露面合计 {faces}')
    print(f'  现状三角 {old_t}  顶点 {old_t*3}')
    for q in (0, 1, 2, 3):
        nt = tris_new(stat, q)
        print(f'  档位 {q}: 三角 {nt:6d}  顶点 {nt*3:6d}  倍率 {nt/old_t:.1f}x')
    print()
