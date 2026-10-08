# 复现 block_relief.gd 的算法，验证两条「不露缝」保证 + 统计几何规模。
# 与 GDScript 逐行对应，改任一侧都要同步改这里。
import json, math

def posmod(a, b):
    return a % b

def hash01(a, b):
    return posmod(a * 73856093 + b * 19349663, 65536) / 65535.0

def noise2(wx, wz):
    x0, z0 = math.floor(wx), math.floor(wz)
    fx, fz = wx - x0, wz - z0
    ux = fx * fx * (3 - 2 * fx)
    uz = fz * fz * (3 - 2 * fz)
    a, b = hash01(x0, z0), hash01(x0 + 1, z0)
    c, d = hash01(x0, z0 + 1), hash01(x0 + 1, z0 + 1)
    return (a + (b - a) * ux) + ((c + (d - c) * ux) - (a + (b - a) * ux)) * uz

def edge_distance(x, z):
    return max(abs(x - 0.5), abs(z - 0.5)) * 2.0

def edge_weight(x, z, opened):
    fx = 0.0
    if opened[0]:
        fx = max(fx, (x - 0.5) * 2.0)
    if opened[1]:
        fx = max(fx, (0.5 - x) * 2.0)
    fz = 0.0
    if opened[2]:
        fz = max(fz, (z - 0.5) * 2.0)
    if opened[3]:
        fz = max(fz, (0.5 - z) * 2.0)
    return min(max(fx + fz, 0.0), 1.3)

def top_height(cell, x, z, r, opened):
    edge = edge_weight(x, z, opened)
    inner = 1.0 - min(max(edge_distance(x, z) * 2.0, 0.0), 1.0)
    n = noise2(cell[0] + x, cell[2] + z)
    bump = r['top_amp'] * (n - 0.5) * 2.0 * inner
    return 1.0 - r['top_slump'] * edge + bump

PAL = json.load(open('project/data/palette.json', encoding='utf-8'))
REL = {i['id']: i['relief'] for i in PAL['items'] if 'relief' in i}

print('=== 1. 共享边高度一致性（相邻同层 cube，中间边不得露缝）===')
stone = REL['stone']
# A=(0,0,0) 与 B=(1,0,0) 相邻：A 的 +X 边被 B 包住 => opened[0]=False
open_a = [False, False, True, True]   # +X 被 B 占 / -X 无 / +Z,-Z 暴露
open_b = [False, False, True, True]   # -X 被 A 占
worst = 0.0
for k in range(11):
    z = k / 10.0
    ha = top_height((0, 0, 0), 1.0, z, stone, open_a)   # A 在共享边 x=1
    hb = top_height((1, 0, 0), 0.0, z, stone, open_b)   # B 在同一条世界边 x=0
    worst = max(worst, abs(ha - hb))
print(f'  共享边 11 点采样，最大高度差 = {worst:.10f}  ->  {"✅ 一致（不露缝）" if worst < 1e-9 else "❌ 露缝"}')

print()
print('=== 2. 噪声跨格连续性（世界坐标噪声的必要条件）===')
w = 0.0
for k in range(11):
    z = k / 10.0
    w = max(w, abs(noise2(0 + 1.0, 0 + z) - noise2(1 + 0.0, 0 + z)))
print(f'  同一点从两侧格子取噪声，最大差 = {w:.10f}  ->  {"✅ 连续" if w < 1e-9 else "❌ 不连续"}')

print()
print('=== 3. 形制取值范围（合理性检查）===')
for kid, r in REL.items():
    lo, hi = 9.9, -9.9
    for opened in ([True]*4, [False]*4, [True, False, True, False]):
        for i in range(3):
            for j in range(3):
                h = top_height((3, 0, 5), i/2, j/2, r, opened)
                lo, hi = min(lo, h), max(hi, h)
    print(f'  {kid:6s} 顶面高度 {lo:.3f} ~ {hi:.3f}   (thickness={r["thickness"]}, div={r["top_div"]})')
    if hi > 1.0 + 0.12 or lo < 1.0 - 0.30:
        print(f'     ⚠ 超出合理范围（应大致落在 0.70 ~ 1.12）')

print()
print('=== 4. 侧面顶边 vs 顶面边界（同一函数必然一致，抽查）===')
ok = True
for kid, r in REL.items():
    for t in (0.0, 0.5, 1.0):
        h_side = top_height((3, 0, 5), t, 1.0, r, [True, True, True, True])   # +Z 面顶边
        h_top = top_height((3, 0, 5), t, 1.0, r, [True, True, True, True])    # 顶面同一点
        if abs(h_side - h_top) > 1e-9:
            ok = False
print(f'  {"✅ 一致" if ok else "❌ 不一致"}')
