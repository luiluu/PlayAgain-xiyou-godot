class_name XDataFile
extends RefCounted
## 没发行的数据表读不到时记住（cc 2026-11-13）：发行包按 07_开发环境/发行内容审计.py 的名单排除了天启篇等没发行的数据，
## 读表的地方先问 missing(路径)。同一路径只查一次，之后直接当缺，不再每次去开文件；发行构建不报错（缺是故意的），
## 调试构建报一次（开发时缺表是真问题）。文件在的时候跟原来一样往下读。


static var _missing := {}


static func missing(path: String) -> bool:
	if _missing.has(path):
		return true
	if FileAccess.file_exists(path):
		return false
	_missing[path] = true
	if not ReleaseEntry.is_release():
		push_error("读不到数据表 " + path)
	return true
