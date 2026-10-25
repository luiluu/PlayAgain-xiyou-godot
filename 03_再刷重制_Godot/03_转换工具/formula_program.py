"""Bounded JS formula compiler. No eval, arbitrary member access, or host functions."""
import hashlib
import re

VERSION = 1
PROPERTIES = set('hp mp tp mhp mmp atk def mat mdf agi luk level hit eva cri cev mev mrf cnt hrg mrg trg tgr grd rec pha mcr tcr pdr mdr fdr exr shield'.split())
METHODS = {'elementRate': (1, 'element'), 'skillMasteryLevel': (1, 'mastery'),
           'isStateAffected': (1, 'has_state'), 'maxTp': (0, 'max_tp'),
           'hpRate': (0, 'hp_rate'), 'mpRate': (0, 'mp_rate'), 'actorId': (0, 'actor_id'),
           'param': (1, 'param'), 'xparam': (1, 'xparam'), 'sparam': (1, 'sparam'),
           'states': (0, 'states')}
MATH = {'max': (1, 32), 'min': (1, 32), 'floor': (1, 1), 'ceil': (1, 1),
        'round': (1, 1), 'abs': (1, 1), 'pow': (2, 2), 'sqrt': (1, 1), 'random': (0, 0)}
ALIASES = {'a': 'a', 'user': 'a', 'subject': 'a', 'b': 'b', 'target': 'b'}
RESERVED = set('if else true false null var let const return function while for switch new delete this typeof void instanceof in yield await break continue try catch finally throw do case default class extends super enum import export with debugger'.split())
TOKEN = re.compile(r'(?P<space>[ \t\v\f\r\n\u00a0\ufeff\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+|//[^\n\r\u2028\u2029]*|/\*[\s\S]*?\*/)|(?P<number>(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?)|(?P<name>[A-Za-z_$][A-Za-z0-9_$]*)|(?P<op>=>|===|!==|\+\+|--|\*\*|<=|>=|==|!=|&&|\|\||[+*/%<>!=?:.,;(){}\[\]-])')
PREC = {'||': 1, '&&': 2, '==': 3, '!=': 3, '===': 3, '!==': 3,
        '<': 4, '>': 4, '<=': 4, '>=': 4, '+': 5, '-': 5, '*': 6, '/': 6, '%': 6, '**': 7}


class Unsupported(ValueError):
    def __init__(self, reason, pos=0):
        self.reason, self.pos = reason, pos
        super().__init__(reason)


class Parser:
    def __init__(self, source):
        self.source, self.tokens, self.i, self.depth = source, [], 0, 0
        pos = 0
        if len(source) > 16384:
            raise Unsupported('source_limit')
        while pos < len(source):
            m = TOKEN.match(source, pos)
            if not m:
                raise Unsupported('unexpected_character', pos)
            if m.lastgroup != 'space':
                self.tokens.append((m.group(), pos, m.end(), m.lastgroup))
            pos = m.end()
        self.tokens.append(('<eof>', pos, pos, 'eof'))
        if len(self.tokens) > 4096:
            raise Unsupported('token_limit')

    @property
    def t(self):
        return self.tokens[self.i][0]

    @property
    def pos(self):
        return self.tokens[self.i][1]

    def take(self, token=None):
        row = self.tokens[self.i]
        if token is not None and row[0] != token:
            raise Unsupported('expected:' + token, row[1])
        self.i += 1
        return row

    def accept(self, token):
        if self.t == token:
            self.take()
            return True
        return False

    def node(self, op, pos, **fields):
        return {'op': op, 'pos': pos, **fields}

    def expression(self, minimum=0):
        self.depth += 1
        if self.depth > 64:
            raise Unsupported('depth_limit', self.pos)
        token, pos, _, kind = self.take()
        if token in ('+', '-', '!'):
            left = self.node('unary', pos, operator=token, arg=self.expression(8))
        elif token == '(':
            left = self.node('group', pos, value=self.expression())
            self.take(')')
        elif kind == 'number':
            if re.match(r'0[0-9]', token):
                raise Unsupported('legacy_integer_literal', pos)
            value = float(token)
            if not value < float('inf'):
                raise Unsupported('non_finite_literal', pos)
            left = self.node('literal', pos, value=value)
        elif token in ('true', 'false', 'null'):
            left = self.node('literal', pos, value={'true': True, 'false': False, 'null': None}[token])
        elif kind == 'name':
            left = self.node('name', pos, name=token)
        else:
            raise Unsupported('expected_expression', pos)
        while True:
            if self.accept('.'):
                prop, p, _, k = self.take()
                if k != 'name':
                    raise Unsupported('expected_property', p)
                left = self.node('member', left['pos'], owner=left, name=prop)
            elif self.accept('['):
                index = self.expression()
                self.take(']')
                left = self.node('index', left['pos'], owner=left, index=index)
            elif self.accept('('):
                args = []
                if self.t != ')':
                    while True:
                        args.append(self.expression())
                        if not self.accept(','):
                            break
                self.take(')')
                left = self.node('call', left['pos'], callee=left, args=args)
            elif self.t in PREC and PREC[self.t] >= minimum:
                operator = self.take()[0]
                if operator == '**' and left['op'] == 'unary':
                    raise Unsupported('unparenthesized_unary_exponent', left['pos'])
                right = self.expression(PREC[operator] + (0 if operator == '**' else 1))
                left = self.node('binary', left['pos'], operator=operator, left=left, right=right)
            elif minimum == 0 and self.accept('?'):
                yes = self.expression()
                self.take(':')
                left = self.node('select', left['pos'], condition=left, yes=yes, no=self.expression())
            else:
                break
        self.depth -= 1
        return left

    def end_statement(self):
        if self.accept(';') or self.t in ('}', '<eof>'):
            return
        previous = self.tokens[self.i - 1][2]
        if not re.search(r'[\r\n\u2028\u2029]', self.source[previous:self.pos]):
            raise Unsupported('expected_statement_end', self.pos)

    def statement(self, depth=0):
        if depth > 32:
            raise Unsupported('statement_depth_limit', self.pos)
        pos = self.pos
        if self.i == 0:
            query = self.equipment_prefix()
            if query is not None:
                return query
        if self.accept(';'):
            return self.node('empty', pos)
        if self.accept('{'):
            steps = []
            while self.t != '}':
                if self.t == '<eof>':
                    raise Unsupported('unclosed_block', pos)
                steps.append(self.statement(depth + 1))
            self.take('}')
            return self.node('block', pos, steps=steps)
        if self.accept('if'):
            self.take('(')
            condition = self.expression()
            self.take(')')
            yes = self.statement(depth + 1)
            no = self.statement(depth + 1) if self.accept('else') else self.node('empty', pos)
            return self.node('if', pos, condition=condition, yes=yes, no=no)
        if self.t in ('var', 'let', 'const'):
            kind = self.take()[0]
            name, p, _, k = self.take()
            if k != 'name':
                raise Unsupported('expected_local_name', p)
            initialized = self.accept('=')
            value = self.expression() if initialized else self.node('undefined', p)
            self.end_statement()
            return self.node('declare', pos, name=name, kind=kind, value=value, initialized=initialized)
        expr = self.expression()
        if self.accept('='):
            if expr['op'] != 'name':
                raise Unsupported('nonlocal_assignment', pos)
            value = self.expression()
            self.end_statement()
            return self.node('assign', pos, name=expr['name'], value=value)
        self.end_statement()
        return self.node('expr', pos, value=expr)

    def equipment_prefix(self):
        """Complete bounded token grammar; filter/arrow functions never execute."""
        shape = ('var BASE = NUMBER ; let CURRENT = null ; var EQUIPS = USER . equips ( ) . filter ( ( ELEM ) => ! ! ELEM && DataManager . isArmor ( ELEM ) && ELEM . baseItemId === BASE ) ; '
                 'if ( EQUIPS . length > 0 ) CURRENT = EQUIPS [ 0 ] ; var OBJECT = ! ! CURRENT ? USER . getEquipItemObject ( CURRENT ) : null ; var LEVEL = ! ! OBJECT ? OBJECT . level ( ) : 0 ;').split()
        captured, start = {}, self.i
        try:
            for token in shape:
                actual = self.take()
                if token in ('BASE', 'CURRENT', 'EQUIPS', 'USER', 'ELEM', 'OBJECT', 'LEVEL', 'NUMBER'):
                    if token in captured:
                        if captured[token][0] != actual[0]:
                            raise Unsupported('equipment_query_name_mismatch', actual[1])
                    else:
                        if token == 'NUMBER':
                            if actual[3] != 'number' or not actual[0].isdigit() or actual[0].startswith('0') or not 0 < int(actual[0]) <= 2147483647:
                                raise Unsupported('equipment_query_base_requires_positive_integer', actual[1])
                        elif actual[3] != 'name' or actual[0] in RESERVED or (token == 'USER' and actual[0] not in ALIASES):
                            raise Unsupported('equipment_query_identifier', actual[1])
                        captured[token] = actual
                elif actual[0] != token:
                    raise Unsupported('equipment_query_shape', actual[1])
            names = [captured[k][0] for k in ('BASE', 'CURRENT', 'EQUIPS', 'OBJECT', 'LEVEL')]
            if len(set(names)) != len(names) or any(n in ALIASES or n in ('DataManager', 'Math', 'item', 'v', 's') for n in names) or captured['ELEM'][0] in names + ['DataManager']:
                raise Unsupported('equipment_query_shadowing', self.pos)
            hidden = {captured[k][0] for k in ('CURRENT', 'EQUIPS', 'OBJECT')}
            if any(t[0] in hidden for t in self.tokens[self.i:]):
                raise Unsupported('equipment_query_object_escape', self.pos)
            base, level = captured['BASE'], captured['LEVEL']
            return self.node('block', base[1], steps=[
                self.node('declare', base[1], kind='var', name=base[0], initialized=True,
                          value=self.node('literal', captured['NUMBER'][1], value=float(captured['NUMBER'][0]))),
                self.node('declare', level[1], kind='var', name=level[0], initialized=True,
                          value=self.node('equipment_query', level[1], receiver=ALIASES[captured['USER'][0]],
                                          base=self.node('name', base[1], name=base[0])))])
        except (Unsupported, IndexError):
            self.i = start
            return None

    def parse(self):
        steps = []
        while self.t != '<eof>':
            steps.append(self.statement())
        return steps


def walk(node):
    if isinstance(node, list):
        for child in node:
            yield from walk(child)
    elif isinstance(node, dict):
        yield node
        for value in node.values():
            if isinstance(value, (dict, list)):
                yield from walk(value)


class Compiler:
    def __init__(self, item_id, custom):
        self.item_id, self.custom = item_id, custom
        self.locals, self.caps = {}, set()

    def lower(self, n):
        op, pos = n['op'], n['pos']
        def out(kind, **fields):
            return {'op': kind, 'pos': pos, **fields}
        if op in ('literal', 'undefined', 'empty'):
            return n
        if op == 'equipment_query':
            self.caps.add('read.equipment_instance_level')
            return out('read', receiver=n['receiver'], name='equipment_level', args=[self.lower(n['base'])])
        if op == 'group':
            return self.lower(n['value'])
        if op == 'name':
            if n['name'] not in self.locals:
                raise Unsupported('unknown_identifier:' + n['name'], pos)
            return out('local', name=n['name'])
        if op == 'member':
            owner, prop = n['owner'], n['name']
            name = owner.get('name') if owner['op'] == 'name' else None
            if name == 'item' and prop == 'id':
                return out('literal', value=self.item_id)
            if name in ALIASES and prop in PROPERTIES:
                self.caps.add('read.battler')
                return out('property', receiver=ALIASES[name], name=prop)
            if prop == 'length' and owner['op'] == 'call' and owner['callee'].get('name') == 'states':
                callee = owner['callee']
                receiver = callee.get('owner', {}).get('name')
                if receiver in ALIASES and not owner['args']:
                    self.caps.add('read.battler')
                    return out('read', receiver=ALIASES[receiver], name='states_count', args=[])
            raise Unsupported('unsupported_property:' + prop, pos)
        if op == 'index':
            owner = n['owner']
            if owner['op'] != 'name' or owner['name'] not in ('v', 's'):
                raise Unsupported('unsupported_index', pos)
            self.caps.add('read.variables' if owner['name'] == 'v' else 'read.switches')
            return out('lookup', pool=owner['name'], index=self.lower(n['index']))
        if op == 'call':
            callee, args = n['callee'], n['args']
            if callee['op'] != 'member' or callee['owner']['op'] != 'name':
                raise Unsupported('unsupported_call', pos)
            owner, method = callee['owner']['name'], callee['name']
            if owner == 'Math' and method in MATH:
                lo, hi = MATH[method]
                if not lo <= len(args) <= hi:
                    raise Unsupported('invalid_arity:' + method, pos)
                if method == 'random':
                    self.caps.add('random.rule')
                return out('math', name=method, args=[self.lower(x) for x in args])
            if owner in ALIASES and method in METHODS:
                if method == 'states':
                    raise Unsupported('array_value_pending:states', pos)
                arity, canonical = METHODS[method]
                if len(args) != arity:
                    raise Unsupported('invalid_arity:' + method, pos)
                if method in ('param', 'xparam', 'sparam'):
                    arg = self.lower(args[0])
                    value = arg.get('value')
                    limit = 8 if method == 'param' else 10
                    if arg['op'] != 'literal' or type(value) not in (float, int) or not float(value).is_integer() or not 0 <= value < limit:
                        raise Unsupported('parameter_requires_constant_index', pos)
                self.caps.add('read.battler')
                return out('read', receiver=ALIASES[owner], name=canonical, args=[self.lower(x) for x in args])
            if owner in ALIASES and method in ('gainHp', 'gainMp', 'gainTp'):
                if len(args) != 1:
                    raise Unsupported('invalid_arity:' + method, pos)
                resource = method[4:].lower()
                self.caps.add('write.' + resource)
                return out('gain', receiver=ALIASES[owner], resource=resource, amount=self.lower(args[0]))
            if owner in ALIASES and method == 'addShield':
                # ShieldSystem Game_Battler.addShield(value)：返回 undefined
                if len(args) != 1:
                    raise Unsupported('invalid_arity:' + method, pos)
                self.caps.add('write.shield')
                return out('shield', receiver=ALIASES[owner], amount=self.lower(args[0]))
            raise Unsupported('unsupported_call:' + owner + '.' + method, pos)
        if op in ('declare', 'assign'):
            if n['name'] not in self.locals:
                raise Unsupported('undeclared_assignment:' + n['name'], pos)
            return out('empty') if op == 'declare' and not n['initialized'] else out('set', name=n['name'], value=self.lower(n['value']))
        fields = {'unary': ['operator', 'arg'], 'binary': ['operator', 'left', 'right'],
                  'select': ['condition', 'yes', 'no'], 'if': ['condition', 'yes', 'no'],
                  'block': ['steps'], 'expr': ['value']}
        if op not in fields:
            raise Unsupported('unsupported_node:' + op, pos)
        result = out(op)
        for key in fields[op]:
            value = n[key]
            result[key] = [self.lower(x) for x in value] if isinstance(value, list) else self.lower(value) if isinstance(value, dict) else value
        return result

    def compile(self, source):
        tree = Parser(source).parse()
        if not tree and not self.custom:
            tree = [{'op': 'expr', 'pos': 0, 'value': {'op': 'undefined', 'pos': 0}}]
        nodes = list(walk(tree))
        if len(nodes) > 2048:
            raise Unsupported('node_limit')
        declarations = [x for x in nodes if x['op'] == 'declare']
        if self.custom:
            self.locals['value'] = 'var'
        for n in declarations:
            name, kind = n['name'], n['kind']
            if name in ALIASES or name in ('v', 's', 'Math', 'item', 'sign', 'arguments') or name in RESERVED:
                raise Unsupported('reserved_local:' + name, n['pos'])
            # Lexical declarations need block/TDZ semantics: reject until that capability exists.
            if kind != 'var':
                raise Unsupported('lexical_declaration_pending:' + kind, n['pos'])
            if name in self.locals and self.locals[name] != 'var':
                raise Unsupported('duplicate_local:' + name, n['pos'])
            self.locals[name] = kind
        if not self.custom and (not tree or not yields_result(tree[-1])):
            raise Unsupported('missing_expression_result')
        steps = [self.lower(x) for x in tree]
        return {'status': 'effectful' if any(x.startswith('write.') for x in self.caps) else 'pure', 'capabilities': sorted(self.caps), 'locals': list(self.locals),
                'steps': steps, 'result': 'value' if self.custom else 'completion'}


def yields_result(n):
    """脚本完成值：末条语句是表达式，或 if／块的每条路径都以表达式收尾（JS 的 if 语句完成值是所选分支的完成值）。"""
    if n['op'] == 'expr':
        return True
    if n['op'] == 'block':
        return bool(n['steps']) and yields_result(n['steps'][-1])
    if n['op'] == 'if':
        return yields_result(n['yes']) and yields_result(n['no'])
    return False


# 角色专属模块的公式入口：整条公式只是一次模块调用，Godot 由对应模块求值（XFormulaExecution.run_item 按 module 分派）。
# 键是去掉空白后的原文；写法稍有不同就仍按普通公式编译（拒收），不猜。
MODULE_FORMULAS = {'CodexCat.formula(user,item,b)': 'cat'}
# 173 饿狼 CodexGarou.base(a,b,id)：拳法 10250～10263（XGarou.formula）
MODULE_FORMULAS.update({f'CodexGarou.base(a,b,{i})': 'garou' for i in range(10250, 10264)})
# 168 米拉 CodexMira.damage(a,b,id)：10140～10151（10147 原文写的是 10146，XMira.formula 按原文的 id 算）
MODULE_FORMULAS.update({f'CodexMira.damage(a,b,{i})': 'mira' for i in range(10140, 10152)})
# 167 渡鸦 5 个伤害技能：整条公式含 CodexRaven.legionStrikeRate／skillCoefficient（XRaven.formula 照原文逐技能写）
MODULE_FORMULAS.update({re.sub(r'\s+', '', f): 'raven' for f in [
    '(a.mat * 78 + a.mmp * 39) * (CodexRaven.legionStrikeRate(a) * CodexRaven.skillCoefficient(a, 10122))',
    '(a.mat * 78 + a.mmp * 39) * (CodexRaven.legionStrikeRate(a) * CodexRaven.skillCoefficient(a, 10123))',
    '(a.mat * 798 + a.mmp * 399) * (CodexRaven.legionStrikeRate(a) * CodexRaven.skillCoefficient(a, 10124))',
    'a.mat * (3999 + 3999 * (1 - b.hpRate())) * (CodexRaven.legionStrikeRate(a) * CodexRaven.skillCoefficient(a, 10125))',
    '(a.mat * 33333 + a.mmp * 3333) * (CodexRaven.legionStrikeRate(a) * CodexRaven.skillCoefficient(a, 10126))']})


def compile_formula(source, item_id=0, custom=False, table='Skills'):
    source = source or ''
    result = {'version': VERSION, 'source': {'table': table, 'id': item_id, 'custom': custom,
               'sha256': hashlib.sha256(source.encode()).hexdigest()}}
    module = None if custom else MODULE_FORMULAS.get(re.sub(r'\s+', '', source))
    if module:
        result.update(status='module', module=module, capabilities=[], locals=[], steps=[], result=None)
        return result
    try:
        result.update(Compiler(item_id, custom).compile(source))
    except (Unsupported, RecursionError) as error:
        pos = error.pos if isinstance(error, Unsupported) else 0
        lines = re.split(r'\r\n|[\r\n\u2028\u2029]', source[:pos])
        result.update(status='unsupported', capabilities=[], locals=[], steps=[], result=None,
                      diagnostic={'reason': error.reason if isinstance(error, Unsupported) else 'depth_limit',
                                  'offset': pos, 'line': len(lines), 'column': len(lines[-1]) + 1})
    return result
