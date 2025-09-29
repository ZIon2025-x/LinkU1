"""
代码清理工具
识别和修复后端代码中的冗余和重复
"""

import os
import re
from typing import Dict, List, Set, Tuple
from pathlib import Path

class CodeCleanupAnalyzer:
    """代码清理分析器"""
    
    def __init__(self, app_dir: str = "backend/app"):
        self.app_dir = Path(app_dir)
        self.duplicate_functions: Dict[str, List[str]] = {}
        self.unused_imports: Dict[str, List[str]] = {}
        self.redundant_code: List[Tuple[str, str, str]] = []
    
    def analyze_duplicate_functions(self) -> Dict[str, List[str]]:
        """分析重复的函数定义"""
        function_definitions = {}
        
        for py_file in self.app_dir.rglob("*.py"):
            if py_file.name == "__init__.py":
                continue
                
            with open(py_file, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # 查找函数定义
            func_pattern = r'def\s+(\w+)\s*\('
            functions = re.findall(func_pattern, content)
            
            for func_name in functions:
                if func_name not in function_definitions:
                    function_definitions[func_name] = []
                function_definitions[func_name].append(str(py_file))
        
        # 找出重复的函数
        for func_name, files in function_definitions.items():
            if len(files) > 1:
                self.duplicate_functions[func_name] = files
        
        return self.duplicate_functions
    
    def analyze_unused_imports(self) -> Dict[str, List[str]]:
        """分析未使用的导入"""
        for py_file in self.app_dir.rglob("*.py"):
            if py_file.name == "__init__.py":
                continue
                
            with open(py_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 查找导入语句
            import_pattern = r'from\s+(\S+)\s+import\s+([^#\n]+)'
            imports = re.findall(import_pattern, content)
            
            unused = []
            for module, items in imports:
                # 清理导入的项目
                imported_items = [item.strip() for item in items.split(',')]
                
                for item in imported_items:
                    # 检查是否在代码中使用
                    if item not in content.replace(f'from {module} import', ''):
                        unused.append(f"{module}.{item}")
            
            if unused:
                self.unused_imports[str(py_file)] = unused
        
        return self.unused_imports
    
    def analyze_redundant_code(self) -> List[Tuple[str, str, str]]:
        """分析冗余代码块"""
        code_blocks = {}
        
        for py_file in self.app_dir.rglob("*.py"):
            if py_file.name == "__init__.py":
                continue
                
            with open(py_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # 查找相似的代码块（简单的基于行数的分析）
            lines = content.split('\n')
            
            # 查找重复的代码模式
            for i, line in enumerate(lines):
                if line.strip().startswith('def ') or line.strip().startswith('class '):
                    # 提取函数/类名
                    name_match = re.search(r'(def|class)\s+(\w+)', line)
                    if name_match:
                        name = name_match.group(2)
                        
                        # 查找相似的函数定义
                        similar_pattern = rf'def\s+{name}\s*\('
                        if content.count(similar_pattern) > 1:
                            self.redundant_code.append((
                                str(py_file),
                                name,
                                f"重复的函数定义: {name}"
                            ))
        
        return self.redundant_code
    
    def generate_cleanup_report(self) -> str:
        """生成清理报告"""
        report = []
        report.append("# Backend Code Cleanup Report")
        report.append("")
        
        # 重复函数分析
        report.append("## Duplicate Functions Analysis")
        if self.duplicate_functions:
            for func_name, files in self.duplicate_functions.items():
                report.append(f"### Function: `{func_name}`")
                report.append(f"**Found in:** {len(files)} files")
                for file_path in files:
                    report.append(f"- `{file_path}`")
                report.append("")
        else:
            report.append("No duplicate function definitions found")
        
        # 未使用导入分析
        report.append("## Unused Imports Analysis")
        if self.unused_imports:
            for file_path, unused in self.unused_imports.items():
                report.append(f"### File: `{file_path}`")
                for import_item in unused:
                    report.append(f"- `{import_item}`")
                report.append("")
        else:
            report.append("No unused imports found")
        
        # 冗余代码分析
        report.append("## Redundant Code Analysis")
        if self.redundant_code:
            for file_path, name, description in self.redundant_code:
                report.append(f"### `{file_path}`")
                report.append(f"- **Issue:** {description}")
                report.append(f"- **Location:** {name}")
                report.append("")
        else:
            report.append("No obvious redundant code found")
        
        return "\n".join(report)
    
    def suggest_cleanup_actions(self) -> List[str]:
        """建议清理操作"""
        actions = []
        
        # 基于分析结果建议操作
        if self.duplicate_functions:
            actions.append("1. 合并重复的函数定义到统一模块")
            actions.append("2. 使用统一的导入路径")
        
        if self.unused_imports:
            actions.append("3. 移除未使用的导入语句")
        
        if self.redundant_code:
            actions.append("4. 重构重复的代码块")
        
        # 通用建议
        actions.extend([
            "5. 统一错误处理机制",
            "6. 合并相似的认证函数",
            "7. 创建统一的工具函数模块",
            "8. 优化导入结构"
        ])
        
        return actions


def main():
    """主函数"""
    analyzer = CodeCleanupAnalyzer()
    
    print("Analyzing duplicate functions...")
    analyzer.analyze_duplicate_functions()
    
    print("Analyzing unused imports...")
    analyzer.analyze_unused_imports()
    
    print("Analyzing redundant code...")
    analyzer.analyze_redundant_code()
    
    print("\n" + "="*50)
    print(analyzer.generate_cleanup_report())
    
    print("\n" + "="*50)
    print("## Suggested cleanup actions")
    for action in analyzer.suggest_cleanup_actions():
        print(f"- {action}")


if __name__ == "__main__":
    main()
