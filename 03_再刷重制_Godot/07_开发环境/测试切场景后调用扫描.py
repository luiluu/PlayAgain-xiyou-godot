#!/usr/bin/env python3
"""切场景后调用扫描.py 的离线回归（platform-crash1）：用临时目录里的小 .gd 夹具，不跑 Godot。"""
import importlib.util
from pathlib import Path
import sys
import tempfile
import textwrap
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('scan', HERE / '切场景后调用扫描.py')
scan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scan)


def run(files: dict):
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        for name, text in files.items():
            p = root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(textwrap.dedent(text).lstrip('\n').replace('    ', '\t'), encoding='utf-8')
        return scan.scan(root)


class ScanTests(unittest.TestCase):
    def test_direct_after_change_scene(self):
        h = run({'a.gd': '''
            func _unhandled_input(e):
                get_tree().change_scene_to_file("res://m.tscn")
                get_viewport().set_input_as_handled()
        '''})
        self.assertEqual([(x['line'], x['kind']) for x in h], [(3, '直接')])

    def test_deferred_and_queue_free_are_safe(self):
        h = run({'a.gd': '''
            func f():
                get_tree().change_scene_to_file.call_deferred("res://m.tscn")
                get_viewport().set_input_as_handled()
            func g():
                queue_free()
                get_tree().create_timer(1)
        '''})
        self.assertEqual(h, [])

    def test_title_callable_via_dictionary(self):
        # 11-06 那一条：命令表里存 Callable，_activate 里 .call()，_unhandled_input 之后取视口
        h = run({'entry.gd': '''
            func _title():
                _add(_new_game)
            func _add(fn):
                _cmds.append({"fn": fn})
            func _activate(i):
                _cmds[i].fn.call()
            func _unhandled_input(e):
                if e.is_action_pressed("ui_accept"):
                    _activate(0)
                    get_viewport().set_input_as_handled()
            func _new_game():
                get_tree().change_scene_to_file("res://m.tscn")
        '''})
        self.assertEqual([(x['file'], x['line'], x['func']) for x in h], [('entry.gd', 10, '_unhandled_input')])

    def test_signal_connected_lambda(self):
        h = run({'entry.gd': '''
            func _choose():
                page.loaded.connect(func(): get_tree().change_scene_to_file("res://m.tscn"))
        ''', 'save.gd': '''
            signal loaded
            func ok():
                loaded.emit()
            func _unhandled_input(e):
                ok()
                get_viewport().set_input_as_handled()
        '''})
        self.assertEqual([(x['file'], x['line'], x['kind']) for x in h], [('save.gd', 6, '经调用')])

    def test_lambda_body_not_sync(self):
        # lambda 只是连上，不会当场执行：_choose 本身不离树
        h = run({'a.gd': '''
            func _choose():
                b.pressed.connect(func(): get_tree().change_scene_to_file("res://m.tscn"))
                get_viewport().set_input_as_handled()
        '''})
        self.assertEqual(h, [])

    def test_return_and_else_branch_not_reached(self):
        h = run({'a.gd': '''
            func f(x):
                if x:
                    get_tree().change_scene_to_file("res://m.tscn")
                    return
                get_viewport().set_input_as_handled()
            func g(x):
                if x:
                    get_tree().change_scene_to_file("res://m.tscn")
                else:
                    get_viewport().set_input_as_handled()
        '''})
        self.assertEqual(h, [])

    def test_guard_and_exempt(self):
        h = run({'a.gd': '''
            func f():
                get_tree().change_scene_to_file("res://m.tscn")
                if is_inside_tree():
                    get_viewport().set_input_as_handled()
                get_tree()  # 离树后安全：测试用
        '''})
        self.assertEqual(h, [])

    def test_other_object_and_gameapp_skipped(self):
        h = run({'a.gd': '''
            func f():
                GameApp.enter_mode("xiyou")
                other.get_tree()
        ''', 'core/game_app.gd': '''
            func enter_mode(m):
                get_tree().change_scene_to_file(m)
                get_tree().paused = false
        '''})
        self.assertEqual(h, [])


if __name__ == '__main__':
    unittest.main(verbosity=1 if len(sys.argv) == 1 else 2)
