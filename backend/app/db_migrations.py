"""
数据库迁移执行模块
在应用启动时自动执行数据库迁移脚本
"""

import logging
import os
from pathlib import Path
from typing import List, Tuple

from sqlalchemy import text
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)


def execute_sql_file(engine: Engine, sql_file_path: Path) -> Tuple[int, int, int]:
    """
    执行 SQL 文件
    
    返回: (执行成功数, 跳过数, 错误数)
    """
    executed = 0
    skipped = 0
    errors = 0
    
    if not sql_file_path.exists():
        logger.warning(f"迁移文件不存在: {sql_file_path}")
        return executed, skipped, errors
    
    try:
        with open(sql_file_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # 分割 SQL 语句（按分号分割，但保留在字符串中的分号）
        # 使用更简单的方法：按分号分割，然后过滤空语句和注释
        statements = []
        
        # 先移除单行注释
        lines = sql_content.split('\n')
        cleaned_lines = []
        for line in lines:
            # 移除行内注释（但保留字符串中的内容）
            if '--' in line:
                # 简单处理：如果不在引号内，移除注释部分
                comment_pos = line.find('--')
                if comment_pos >= 0:
                    # 检查引号
                    before_comment = line[:comment_pos]
                    quote_count = before_comment.count("'") + before_comment.count('"')
                    if quote_count % 2 == 0:  # 偶数个引号，说明不在字符串内
                        line = line[:comment_pos].rstrip()
            cleaned_lines.append(line)
        
        cleaned_content = '\n'.join(cleaned_lines)
        
        # 按分号分割
        raw_statements = cleaned_content.split(';')
        
        for stmt in raw_statements:
            stmt = stmt.strip()
            # 跳过空语句和注释块
            if stmt and not stmt.startswith('/*') and not stmt.startswith('--'):
                statements.append(stmt)
        
        # 执行每个语句
        with engine.connect() as conn:
            for statement in statements:
                statement = statement.strip()
                if not statement or statement.startswith('--'):
                    continue
                
                try:
                    # 使用 text() 包装 SQL 语句
                    conn.execute(text(statement))
                    conn.commit()
                    executed += 1
                except Exception as e:
                    error_msg = str(e).lower()
                    # 检查是否是"已存在"的错误（幂等性）
                    if any(keyword in error_msg for keyword in ['already exists', 'duplicate', 'exists']):
                        skipped += 1
                        logger.debug(f"跳过已存在的对象: {statement[:50]}...")
                    else:
                        errors += 1
                        logger.warning(f"执行 SQL 语句失败: {e}")
                        logger.debug(f"失败的语句: {statement[:200]}...")
        
        logger.info(f"迁移文件执行完成: {sql_file_path.name}")
        logger.info(f"  执行: {executed}, 跳过: {skipped}, 错误: {errors}")
        
    except Exception as e:
        logger.error(f"读取或执行迁移文件失败 {sql_file_path}: {e}")
        errors += 1
    
    return executed, skipped, errors


def run_migrations(engine: Engine) -> bool:
    """
    执行所有数据库迁移脚本
    
    返回: 是否成功
    """
    # 检查是否启用自动迁移
    auto_migrate = os.getenv("AUTO_MIGRATE", "true").lower() == "true"
    if not auto_migrate:
        logger.info("自动迁移已禁用 (AUTO_MIGRATE=false)")
        return True
    
    logger.info("🚀 开始执行自动数据库迁移...")
    
    # 获取迁移脚本目录
    backend_dir = Path(__file__).parent.parent
    migrations_dir = backend_dir / "migrations"
    
    if not migrations_dir.exists():
        logger.warning(f"迁移目录不存在: {migrations_dir}")
        return True
    
    # 定义迁移脚本执行顺序
    migration_files = [
        "create_coupon_points_tables.sql",
        "add_task_indexes.sql",
        "create_task_expert_tables.sql",  # 新增：任务达人功能迁移
    ]
    
    total_executed = 0
    total_skipped = 0
    total_errors = 0
    
    for migration_file in migration_files:
        sql_file = migrations_dir / migration_file
        
        if not sql_file.exists():
            logger.warning(f"迁移文件不存在，跳过: {migration_file}")
            continue
        
        logger.info(f"🚀 开始执行 {migration_file}...")
        
        executed, skipped, errors = execute_sql_file(engine, sql_file)
        
        total_executed += executed
        total_skipped += skipped
        total_errors += errors
        
        if errors > 0:
            logger.warning(f"⚠️  {migration_file} 执行完成，但有 {errors} 个错误")
        else:
            logger.info(f"✅ {migration_file} 迁移完成")
    
    logger.info(f"✅ 自动数据库迁移完成！")
    logger.info(f"   总计 - 执行: {total_executed}, 跳过: {total_skipped}, 错误: {total_errors}")
    
    # 如果有错误，记录警告但不阻止启动
    if total_errors > 0:
        logger.warning(f"⚠️  迁移过程中有 {total_errors} 个错误，请检查日志")
    
    return True


def run_migration_sync(engine: Engine) -> bool:
    """
    同步执行迁移（用于同步数据库连接）
    """
    try:
        return run_migrations(engine)
    except Exception as e:
        logger.error(f"执行数据库迁移失败: {e}")
        import traceback
        traceback.print_exc()
        # 迁移失败不阻止应用启动
        return True

