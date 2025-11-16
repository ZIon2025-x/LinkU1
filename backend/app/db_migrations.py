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


def split_sql_statements(sql_content: str) -> List[str]:
    """
    智能分割 SQL 语句，正确处理：
    - 函数定义 (CREATE FUNCTION ... $$ ... $$)
    - DO 块 (DO $$ BEGIN ... END $$;)
    - 美元引号字符串 ($$ ... $$ 或 $tag$ ... $tag$)
    - 单引号字符串中的分号
    - 注释
    """
    statements = []
    current_statement = []
    in_dollar_quote = False
    dollar_quote_tag = None
    in_single_quote = False
    in_double_quote = False
    in_line_comment = False
    in_block_comment = False
    i = 0
    
    while i < len(sql_content):
        char = sql_content[i]
        next_char = sql_content[i + 1] if i + 1 < len(sql_content) else None
        
        # 处理块注释
        if not in_dollar_quote and not in_single_quote and not in_double_quote:
            if char == '/' and next_char == '*':
                in_block_comment = True
                current_statement.append(char)
                if next_char:
                    current_statement.append(next_char)
                    i += 1
                i += 1
                continue
            elif in_block_comment and char == '*' and next_char == '/':
                in_block_comment = False
                current_statement.append(char)
                if next_char:
                    current_statement.append(next_char)
                    i += 1
                i += 1
                continue
            elif in_block_comment:
                current_statement.append(char)
                i += 1
                continue
        
        # 处理行注释
        if not in_dollar_quote and not in_single_quote and not in_double_quote and not in_block_comment:
            if char == '-' and next_char == '-':
                in_line_comment = True
                current_statement.append(char)
                if next_char:
                    current_statement.append(next_char)
                    i += 1
                i += 1
                continue
            elif in_line_comment and char == '\n':
                in_line_comment = False
                current_statement.append(char)
                i += 1
                continue
            elif in_line_comment:
                current_statement.append(char)
                i += 1
                continue
        
        # 处理单引号字符串
        if not in_dollar_quote and not in_double_quote and not in_block_comment and not in_line_comment:
            if char == "'" and (i == 0 or sql_content[i-1] != '\\'):
                in_single_quote = not in_single_quote
                current_statement.append(char)
                i += 1
                continue
        
        # 处理双引号字符串
        if not in_dollar_quote and not in_single_quote and not in_block_comment and not in_line_comment:
            if char == '"' and (i == 0 or sql_content[i-1] != '\\'):
                in_double_quote = not in_double_quote
                current_statement.append(char)
                i += 1
                continue
        
        # 处理美元引号
        if not in_single_quote and not in_double_quote and not in_block_comment and not in_line_comment:
            if char == '$':
                # 查找美元引号标签（可能是 $$ 或 $tag$）
                tag_start = i
                tag_end = i + 1
                # 查找第一个 $ 后的标签内容
                while tag_end < len(sql_content) and sql_content[tag_end] != '$':
                    tag_end += 1
                if tag_end < len(sql_content):
                    tag_end += 1  # 包含结束的 $
                    dollar_quote_tag = sql_content[tag_start:tag_end]
                    
                    if not in_dollar_quote:
                        # 进入美元引号
                        in_dollar_quote = True
                        current_statement.append(dollar_quote_tag)
                        i = tag_end
                        continue
                    else:
                        # 检查是否是匹配的结束标签
                        if sql_content[tag_start:tag_end] == dollar_quote_tag:
                            # 退出美元引号
                            in_dollar_quote = False
                            current_statement.append(dollar_quote_tag)
                            dollar_quote_tag = None
                            i = tag_end
                            continue
        
        # 添加字符到当前语句
        current_statement.append(char)
        
        # 如果不在引号、注释或美元引号内，检查是否是语句结束
        if not in_dollar_quote and not in_single_quote and not in_double_quote and not in_block_comment and not in_line_comment:
            if char == ';':
                statement_text = ''.join(current_statement).strip()
                if statement_text and not statement_text.startswith('--') and not statement_text.startswith('/*'):
                    statements.append(statement_text)
                current_statement = []
        
        i += 1
    
    # 处理最后一个语句（如果没有以分号结尾）
    if current_statement:
        statement_text = ''.join(current_statement).strip()
        if statement_text and not statement_text.startswith('--') and not statement_text.startswith('/*'):
            statements.append(statement_text)
    
    return statements


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
        
        # 智能分割 SQL 语句，正确处理函数定义和 DO 块
        statements = split_sql_statements(sql_content)
        
        # 调试：记录分割后的语句数量
        logger.debug(f"迁移文件 {sql_file_path.name} 分割后得到 {len(statements)} 个语句")
        if len(statements) == 0:
            logger.warning(f"警告：迁移文件 {sql_file_path.name} 没有识别到任何 SQL 语句")
            logger.debug(f"文件内容预览: {sql_content[:500]}")
        
        # 执行每个语句（每个语句在独立的事务中执行）
        for statement in statements:
            statement = statement.strip()
            if not statement or statement.startswith('--'):
                continue
            
            # 记录要执行的语句（用于调试）
            logger.debug(f"准备执行 SQL 语句: {statement[:100]}...")
            
            # 每个语句使用独立的事务
            try:
                with engine.connect() as conn:
                    trans = conn.begin()
                    try:
                        # 使用 text() 包装 SQL 语句
                        conn.execute(text(statement))
                        trans.commit()
                        executed += 1
                        logger.debug(f"SQL 语句执行成功: {statement[:50]}...")
                    except Exception as e:
                        # 回滚当前事务
                        try:
                            trans.rollback()
                        except:
                            pass  # 如果回滚也失败，忽略
                        
                        error_msg = str(e).lower()
                        # 检查是否是"已存在"的错误（幂等性）
                        # 包括列已存在、表已存在、索引已存在等情况
                        if any(keyword in error_msg for keyword in ['already exists', 'duplicate', 'duplicate key']):
                            skipped += 1
                            logger.debug(f"跳过已存在的对象: {statement[:50]}...")
                        # 检查是否是"列已存在"的错误（更具体的匹配）
                        elif ('column' in error_msg and 'already exists' in error_msg) or 'duplicate column' in error_msg:
                            skipped += 1
                            logger.debug(f"列已存在，跳过: {statement[:50]}...")
                        # 检查是否是语法错误（可能是 IF NOT EXISTS 不支持）
                        elif 'syntax error' in error_msg or 'unexpected' in error_msg:
                            errors += 1
                            logger.warning(f"SQL 语法错误（可能是 PostgreSQL 版本不支持某些语法）: {e}")
                            logger.warning(f"失败的语句: {statement[:200]}...")
                        # 检查是否是事务失败的错误（可能是之前的语句失败导致的）
                        elif 'infailed' in error_msg or 'transaction is aborted' in error_msg:
                            # 这种情况不应该发生，因为每个语句都在独立事务中
                            # 但如果发生了，记录警告并继续
                            skipped += 1
                            logger.debug(f"跳过事务失败的语句（可能是已存在）: {statement[:50]}...")
                        else:
                            errors += 1
                            logger.warning(f"执行 SQL 语句失败: {e}")
                            logger.warning(f"失败的语句: {statement[:200]}...")
            except Exception as e:
                # 连接级别的错误
                errors += 1
                logger.warning(f"执行 SQL 语句时发生连接错误: {e}")
                logger.warning(f"失败的语句: {statement[:200]}...")
        
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
        "create_task_expert_tables.sql",  # 任务达人功能迁移
        "create_task_expert_profile_update_requests_table.sql",  # 任务达人信息修改审核表迁移
        "update_featured_task_experts_id_to_user_id.sql",  # 修改 featured_task_experts 表的 id 为 user_id
        "sync_featured_task_experts_id_user_id.sql",  # 确保 featured_task_experts 表的 id 和 user_id 同步
        "add_service_application_deadline_fields.sql",  # 为服务申请添加截至日期和灵活选项字段
        "allow_task_deadline_null.sql",  # 允许 tasks 表的 deadline 字段为 NULL（支持灵活模式任务）
        "add_task_is_flexible_field.sql",  # 在 tasks 表中添加 is_flexible 字段
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

