"""小模拟器：只认 122（常量／随机／变量加减）、111 变量比常量／开关、411、412、0、117（递归进公共事件）、119/118（标签）。
别的指令当没事。用来数「门前第几个随机数是哪个变量」。
sim(loc, seq, variables, switches) → (draws[(位置,变量,lo,hi,下标所在loc:i)], 执行到的 loc:i 集合)
认不出的条件（111 其它类型）当成真（走进去），会标 unknown。"""
import json, math, importlib.util
from pathlib import Path
T = Path(__file__).resolve().parent.parent
sp = importlib.util.spec_from_file_location('c', T / '事件写法覆盖.py'); cov = importlib.util.module_from_spec(sp); sp.loader.exec_module(cov)
LISTS = dict(cov.locations())
OPS = {0: lambda a, b: a == b, 1: lambda a, b: a >= b, 2: lambda a, b: a <= b, 3: lambda a, b: a > b, 4: lambda a, b: a < b, 5: lambda a, b: a != b}


def sim(loc, seq, variables=None, switches=None, items=None, max_steps=20000):
    V = {int(k): v for k, v in (variables or {}).items()}
    S = {int(k): v for k, v in (switches or {}).items()}
    I = {int(k): v for k, v in (items or {}).items()}
    draws, ex, unknown = [], set(), []
    st = {'n': 0, 'steps': 0}

    def rnd():
        r = seq[st['n']] if st['n'] < len(seq) else 0.5
        st['n'] += 1
        return r

    def run(loc, depth):
        lst = LISTS.get(loc)
        if lst is None or depth > 4:
            return
        i = 0
        labels = {str(c['parameters'][0]): j for j, c in enumerate(lst) if int(c['code']) == 118}
        while i < len(lst):
            st['steps'] += 1
            if st['steps'] > max_steps:
                return
            c = lst[i]; code = int(c['code']); q = c['parameters']; ind = int(c.get('indent', 0))
            ex.add('%s:%d' % (loc, i))
            if code == 122:
                a, b, op, ot = int(q[0]), int(q[1]), int(q[2]), int(q[3])
                for vid in range(a, b + 1):
                    if ot == 0:
                        val = int(q[4])
                    elif ot == 1:
                        val = V.get(int(q[4]), 0)
                    elif ot == 2:
                        lo, hi = int(q[4]), int(q[5])
                        draws.append((st['n'], vid, lo, hi, '%s:%d' % (loc, i)))
                        val = lo + math.floor(rnd() * (hi - lo + 1))
                    elif ot == 3 and int(q[4]) == 0:
                        val = I.get(int(q[5]), 0)
                    else:   # 游戏数据（物品以外）、脚本：模拟不了，当 0（别让预设值穿过去）
                        val = 0
                    cur = V.get(vid, 0)
                    V[vid] = [val, cur + val, cur - val, cur * val, (math.trunc(cur / val) if val else cur), (cur % val if val else cur)][op]
            elif code == 111:
                t = int(q[0]); ok = True
                if t == 0:
                    ok = bool(S.get(int(q[1]), False)) == (int(q[2]) == 0)
                elif t == 1:
                    rhs = int(q[3]) if int(q[2]) == 0 else V.get(int(q[3]), 0)
                    ok = OPS[int(q[4])](V.get(int(q[1]), 0), rhs)
                elif t == 8:
                    ok = I.get(int(q[1]), 0) > 0
                else:
                    unknown.append('%s:%d' % (loc, i))
                if not ok:   # 跳到同层 411（否则）或 412
                    j = i + 1
                    while j < len(lst) and not (int(lst[j].get('indent', 0)) == ind and int(lst[j]['code']) in (411, 412)):
                        j += 1
                    i = j + 1 if j < len(lst) and int(lst[j]['code']) == 411 else j
                    continue
            elif code == 411:   # 走完 if 分支到这：跳过 else 体
                j = i + 1
                while j < len(lst) and not (int(lst[j].get('indent', 0)) == ind and int(lst[j]['code']) == 412):
                    j += 1
                i = j
                continue
            elif code == 121:
                for s in range(int(q[0]), int(q[1]) + 1):
                    S[s] = int(q[2]) == 0
            elif code == 117:
                run('ce%d' % int(q[0]), depth + 1)
            elif code == 119:
                if str(q[0]) in labels:
                    i = labels[str(q[0])]
                    continue
            elif code == 115:
                return
            i += 1

    run(loc, 0)
    return draws, ex, unknown


def solve(loc, var, val, base_seq=None, variables=None, switches=None, items=None, gate=None):
    """让 var 在（第一次）被随机赋值时取 val：返回 random_seq。gate＝'loc:i' 时只认在它之前的那次。"""
    seq = list(base_seq or [])
    for _ in range(6):
        draws, ex, _ = sim(loc, seq, variables, switches, items)
        hit = [d for d in draws if d[1] == var]
        if not hit:
            return None
        pos, _, lo, hi, _ = hit[0]
        if not (lo <= val <= hi):
            return None
        r = round((val - lo + 0.5) / (hi - lo + 1), 6)
        seq += [0.5] * (pos + 1 - len(seq))
        if seq[pos] == r:
            return seq
        seq[pos] = r
    return seq
