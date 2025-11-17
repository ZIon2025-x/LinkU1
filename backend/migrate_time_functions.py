#!/usr/bin/env python3
"""
自动化时间函数迁移脚本
用于批量替换代码中的时间函数调用

⚠️ 使用前请：
1. 确保已创建 git commit
2. 在测试分支运行
3. 仔细检查替换结果
"""

import os
import re
from pathlib import Path
from typing import List, Tuple

# 需要迁移的文件目录（脚本在backend目录下运行）
import sys
from pathlib import Path

# 获取脚本所在目录
SCRIPT_DIR = Path(__file__).parent
BACKEND_DIR = SCRIPT_DIR / "app"

# 排除的目录和文件
EXCLUDE_DIRS = {"__pycache__", "migrations", ".git"}
EXCLUDE_FILES = {"time_utils.py", "time_utils_v2.py", "migrate_time_functions.py"}

# 迁移规则
MIGRATION_RULES = [
    # datetime.utcnow() -> get_utc_time()
    (
        r"datetime\.utcnow\(\)",
        "get_utc_time()",
        "from app.utils.time_utils import get_utc_time"
    ),
    # datetime.datetime.utcnow() -> get_utc_time()
    (
        r"datetime\.datetime\.utcnow\(\)",
        "get_utc_time()",
        "from app.utils.time_utils import get_utc_time"
    ),
    # pytz.timezone("Europe/London") -> ZoneInfo("Europe/London")
    (
        r'pytz\.timezone\(["\']Europe/London["\']\)',
        'ZoneInfo("Europe/London")',
        "from zoneinfo import ZoneInfo"
    ),
    # pytz.timezone('Europe/London') -> ZoneInfo('Europe/London')
    (
        r"pytz\.timezone\(['\"]Europe/London['\"]\)",
        "ZoneInfo('Europe/London')",
        "from zoneinfo import ZoneInfo"
    ),
    # import pytz -> 删除（如果只用于时区）
    # 注意：这个需要手动检查，因为pytz可能还有其他用途
]

# 需要添加的导入
REQUIRED_IMPORTS = {
    "get_utc_time": "from app.utils.time_utils import get_utc_time",
    "ZoneInfo": "from zoneinfo import ZoneInfo",
    "LONDON": "from app.utils.time_utils import LONDON",
}


def should_process_file(file_path: Path) -> bool:
    """判断是否应该处理该文件"""
    if file_path.name in EXCLUDE_FILES:
        return False
    
    for exclude_dir in EXCLUDE_DIRS:
        if exclude_dir in file_path.parts:
            return False
    
    return file_path.suffix == ".py"


def find_python_files(directory: Path) -> List[Path]:
    """查找所有需要处理的Python文件"""
    python_files = []
    
    for root, dirs, files in os.walk(directory):
        # 排除目录
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        
        for file in files:
            file_path = Path(root) / file
            if should_process_file(file_path):
                python_files.append(file_path)
    
    return python_files


def analyze_file(file_path: Path) -> dict:
    """分析文件，找出需要迁移的内容"""
    try:
        content = file_path.read_text(encoding='utf-8')
    except Exception as e:
        print(f"⚠️ 无法读取文件 {file_path}: {e}")
        return {}
    
    results = {
        "file": str(file_path),
        "datetime_utcnow": [],
        "pytz": [],
        "get_uk_time": [],
        "imports_needed": set(),
    }
    
    lines = content.split('\n')
    
    for line_num, line in enumerate(lines, 1):
        # 检查 datetime.utcnow()
        if re.search(r"datetime\.utcnow\(\)|datetime\.datetime\.utcnow\(\)", line):
            results["datetime_utcnow"].append((line_num, line.strip()))
            results["imports_needed"].add("get_utc_time")
        
        # 检查 pytz
        if re.search(r"import pytz|from pytz|pytz\.timezone", line):
            results["pytz"].append((line_num, line.strip()))
            if 'timezone' in line and 'Europe/London' in line:
                results["imports_needed"].add("ZoneInfo")
        
        # 检查 get_uk_time
        if re.search(r"get_uk_time\(\)|get_uk_time_naive\(\)", line):
            results["get_uk_time"].append((line_num, line.strip()))
            results["imports_needed"].add("get_utc_time")
    
    return results


def migrate_file(file_path: Path, dry_run: bool = True) -> dict:
    """迁移单个文件"""
    try:
        content = file_path.read_text(encoding='utf-8')
    except Exception as e:
        return {"error": str(e)}
    
    original_content = content
    imports_needed = set()
    changes_made = []
    
    # 应用迁移规则
    for pattern, replacement, import_stmt in MIGRATION_RULES:
        matches = list(re.finditer(pattern, content))
        if matches:
            content = re.sub(pattern, replacement, content)
            imports_needed.add(import_stmt.split()[1])  # 提取导入名
            changes_made.append(f"替换 {len(matches)} 处: {pattern} -> {replacement}")
    
    # 检查是否需要添加导入
    needs_get_utc_time = "get_utc_time()" in content and "from app.utils.time_utils import get_utc_time" not in content
    needs_zoneinfo = "ZoneInfo(" in content and "from zoneinfo import ZoneInfo" not in content
    
    if needs_get_utc_time:
        # 在文件开头添加导入
        import_line = "from app.utils.time_utils import get_utc_time"
        # 找到最后一个导入语句的位置
        lines = content.split('\n')
        last_import_idx = 0
        for i, line in enumerate(lines):
            if line.strip().startswith(('import ', 'from ')):
                last_import_idx = i
        
        if last_import_idx > 0:
            lines.insert(last_import_idx + 1, import_line)
            content = '\n'.join(lines)
            changes_made.append(f"添加导入: {import_line}")
    
    if needs_zoneinfo:
        import_line = "from zoneinfo import ZoneInfo"
        lines = content.split('\n')
        last_import_idx = 0
        for i, line in enumerate(lines):
            if line.strip().startswith(('import ', 'from ')):
                last_import_idx = i
        
        if last_import_idx > 0:
            lines.insert(last_import_idx + 1, import_line)
            content = '\n'.join(lines)
            changes_made.append(f"添加导入: {import_line}")
    
    # 如果是dry_run，不实际修改文件
    if not dry_run and content != original_content:
        try:
            file_path.write_text(content, encoding='utf-8')
            return {
                "success": True,
                "changes": changes_made,
                "file": str(file_path)
            }
        except Exception as e:
            return {"error": str(e)}
    
    return {
        "success": True,
        "changes": changes_made,
        "file": str(file_path),
        "dry_run": dry_run
    }


def main():
    """主函数"""
    import sys
    
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv
    auto_yes = "--yes" in sys.argv or "-y" in sys.argv
    
    print("=" * 70)
    print("时间函数自动化迁移脚本")
    print("=" * 70)
    print(f"模式: {'预览模式（不会修改文件）' if dry_run else '执行模式（将修改文件）'}")
    print(f"目录: {BACKEND_DIR}")
    print()
    
    # 查找所有Python文件
    python_files = find_python_files(BACKEND_DIR)
    print(f"找到 {len(python_files)} 个Python文件")
    print()
    
    # 分析所有文件
    print("分析文件...")
    analysis_results = []
    for file_path in python_files:
        result = analyze_file(file_path)
        if result and (result.get("datetime_utcnow") or result.get("pytz") or result.get("get_uk_time")):
            analysis_results.append(result)
    
    # 显示分析结果
    if analysis_results:
        print("\n需要迁移的文件:")
        print("-" * 70)
        total_datetime_utcnow = 0
        total_pytz = 0
        total_get_uk_time = 0
        
        for result in analysis_results:
            datetime_count = len(result.get("datetime_utcnow", []))
            pytz_count = len(result.get("pytz", []))
            uk_time_count = len(result.get("get_uk_time", []))
            
            if datetime_count or pytz_count or uk_time_count:
                print(f"\n文件: {result['file']}")
                if datetime_count:
                    print(f"  - datetime.utcnow(): {datetime_count} 处")
                    total_datetime_utcnow += datetime_count
                if pytz_count:
                    print(f"  - pytz: {pytz_count} 处")
                    total_pytz += pytz_count
                if uk_time_count:
                    print(f"  - get_uk_time: {uk_time_count} 处")
                    total_get_uk_time += uk_time_count
        
        print("\n" + "=" * 70)
        print(f"总计:")
        print(f"  - datetime.utcnow(): {total_datetime_utcnow} 处")
        print(f"  - pytz: {total_pytz} 处")
        print(f"  - get_uk_time: {total_get_uk_time} 处")
        print("=" * 70)
        
        if not dry_run and not auto_yes:
            response = input("\n确认执行迁移？(yes/no): ")
            if response.lower() != 'yes':
                print("已取消")
                return
        
        # 执行迁移
        print("\n开始迁移...")
        migrated_count = 0
        error_count = 0
        
        for result in analysis_results:
            file_path = Path(result['file'])
            migrate_result = migrate_file(file_path, dry_run=dry_run)
            
            if migrate_result.get("success"):
                if migrate_result.get("changes"):
                    migrated_count += 1
                    print(f"[OK] {file_path.name}: {len(migrate_result['changes'])} 处修改")
                    for change in migrate_result['changes']:
                        print(f"   - {change}")
            elif migrate_result.get("error"):
                error_count += 1
                print(f"[ERROR] {file_path.name}: {migrate_result['error']}")
        
        print("\n" + "=" * 70)
        print(f"迁移完成:")
        print(f"  - 成功: {migrated_count} 个文件")
        print(f"  - 失败: {error_count} 个文件")
        print("=" * 70)
        
        if dry_run:
            print("\n警告: 这是预览模式，文件未被修改")
            print("运行时不加 --dry-run 参数来实际执行迁移")
    else:
        print("没有找到需要迁移的文件")


if __name__ == "__main__":
    main()

