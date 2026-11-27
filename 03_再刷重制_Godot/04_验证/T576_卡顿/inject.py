import re, sys
# inject.py file func1 func2 ...
path = sys.argv[1]
s = open(path).read()
for name in sys.argv[2:]:
    m = re.search(r'^(static )?func ' + re.escape(name) + r'\((.*?)\)(\s*->\s*([\w\[\]]+))?:\n', s, re.M)
    if not m:
        print("MISS", name); continue
    static, args, _, ret = m.group(1) or '', m.group(2), m.group(3), m.group(4)
    argnames = []
    for a in [x.strip() for x in args.split(',') if x.strip()]:
        argnames.append(a.split(':')[0].split('=')[0].strip())
    call = f"{name}__raw({', '.join(argnames)})"
    head = s[m.start():m.end()]
    if ret == 'void':
        body = f"\tXActor._prof_enter(\"{name}\")\n\t{call}\n\tXActor._prof_exit(\"{name}\")\n"
    else:
        body = f"\tXActor._prof_enter(\"{name}\")\n\tvar __r = {call}\n\tXActor._prof_exit(\"{name}\")\n\treturn __r\n"
    raw_head = head.replace('func ' + name + '(', 'func ' + name + '__raw(', 1)
    s = s[:m.start()] + head + body + "\n" + raw_head + s[m.end():]
    print("OK", name)
open(path, 'w').write(s)
