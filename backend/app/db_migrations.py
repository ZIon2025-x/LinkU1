"""
数据库迁移模块
在应用启动时自动执行数据库迁移和索引验证
"""
import logging
import re
from pathlib import Path
from sqlalchemy import text
from app.database import sync_engine

logger = logging.getLogger(__name__)


def run_task_indexes_migration():
    """执行任务表索引迁移"""
    try:
        logger.info("开始执行任务表索引迁移...")
        
        # 读取迁移脚本
        migration_file = Path(__file__).parent.parent / "migrations" / "add_task_indexes.sql"
        
        if not migration_file.exists():
            logger.warning(f"迁移文件不存在: {migration_file}")
            return False
        
        with open(migration_file, 'r', encoding='utf-8') as f:
            sql_script = f.read()
        
        # 分割 SQL 语句（按分号分割，但保留注释）
        statements = []
        current_statement = []
        
        for line in sql_script.split('\n'):
            line = line.strip()
            # 跳过空行和注释
            if not line or line.startswith('--'):
                continue
            
            current_statement.append(line)
            
            # 如果行以分号结尾，说明是一个完整的语句
            if line.endswith(';'):
                statement = ' '.join(current_statement)
                if statement.strip():
                    statements.append(statement)
                current_statement = []
        
        # 执行所有 SQL 语句
        with sync_engine.connect() as conn:
            for i, statement in enumerate(statements, 1):
                try:
                    # 跳过 SELECT 查询（验证语句）
                    if statement.strip().upper().startswith('SELECT'):
                        logger.debug(f"跳过验证查询: {statement[:50]}...")
                        continue
                    
                    logger.debug(f"执行迁移语句 {i}/{len(statements)}: {statement[:50]}...")
                    conn.execute(text(statement))
                    conn.commit()
                except Exception as e:
                    # 如果是索引已存在的错误，可以忽略
                    if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                        logger.info(f"索引已存在，跳过: {statement[:50]}...")
                    else:
                        logger.warning(f"执行迁移语句失败: {e}")
                        logger.debug(f"失败的语句: {statement}")
        
        logger.info("✅ 任务表索引迁移完成")
        return True
        
    except Exception as e:
        logger.error(f"❌ 执行任务表索引迁移失败: {e}")
        import traceback
        traceback.print_exc()
        return False


def verify_task_indexes():
    """验证任务表索引"""
    try:
        logger.info("开始验证任务表索引...")
        
        # 导入验证函数（从 scripts 目录）
        import sys
        from pathlib import Path
        scripts_path = Path(__file__).parent.parent / "scripts"
        if str(scripts_path) not in sys.path:
            sys.path.insert(0, str(scripts_path))
        
        from verify_indexes import verify_indexes
        
        # 调用验证函数（它会输出到日志）
        verify_indexes()
        
        logger.info("✅ 任务表索引验证完成")
        return True
        
    except Exception as e:
        logger.warning(f"⚠️  索引验证失败（不影响启动）: {e}")
        import traceback
        traceback.print_exc()
        return False


def run_coupon_points_migration():
    """执行优惠券和积分系统数据库迁移"""
    try:
        logger.info("🚀 开始执行优惠券和积分系统数据库迁移...")
        
        # 读取迁移脚本
        migration_file = Path(__file__).parent.parent / "migrations" / "create_coupon_points_tables.sql"
        
        if not migration_file.exists():
            logger.warning(f"⚠️  迁移文件不存在: {migration_file}")
            return False
        
        with open(migration_file, 'r', encoding='utf-8') as f:
            sql_script = f.read()
        
        # 分割 SQL 语句（处理多行语句、DO 块和函数定义）
        statements = []
        current_statement = []
        in_dollar_quote = False
        dollar_quote_tag = None
        
        for line in sql_script.split('\n'):
            original_line = line
            line_stripped = line.strip()
            
            # 跳过空行和注释
            if not line_stripped or line_stripped.startswith('--'):
                continue
            
            # 检测美元引号开始（$$ 或 $tag$）
            if not in_dollar_quote:
                # 查找 $$ 或 $tag$ 的开始
                dollar_match = None
                if '$$' in line_stripped:
                    # 简单情况：$$
                    dollar_match = '$$'
                elif '$' in line_stripped:
                    # 查找 $tag$ 格式
                    match = re.search(r'\$([^$]*)\$', line_stripped)
                    if match:
                        dollar_match = f'${match.group(1)}$'
                
                if dollar_match:
                    in_dollar_quote = True
                    dollar_quote_tag = dollar_match
            
            # 检测美元引号结束
            if in_dollar_quote and dollar_quote_tag in line_stripped:
                # 检查是否是结束标记（在同一行中出现了两次，或者后面跟着分号）
                tag_count = line_stripped.count(dollar_quote_tag)
                if tag_count >= 2 or (tag_count == 1 and line_stripped.endswith(';')):
                    in_dollar_quote = False
                    dollar_quote_tag = None
            
            current_statement.append(original_line)
            
            # 如果行以分号结尾且不在美元引号块中，说明是一个完整的语句
            if line_stripped.endswith(';') and not in_dollar_quote:
                statement = '\n'.join(current_statement)
                if statement.strip():
                    statements.append(statement)
                current_statement = []
        
        # 执行所有 SQL 语句
        executed_count = 0
        skipped_count = 0
        error_count = 0
        
        with sync_engine.connect() as conn:
            for i, statement in enumerate(statements, 1):
                try:
                    # 跳过 SELECT 查询（验证语句）
                    statement_upper = statement.strip().upper()
                    if statement_upper.startswith('SELECT'):
                        logger.debug(f"跳过验证查询 {i}/{len(statements)}: {statement[:50]}...")
                        skipped_count += 1
                        continue
                    
                    logger.debug(f"执行迁移语句 {i}/{len(statements)}: {statement[:80]}...")
                    conn.execute(text(statement))
                    conn.commit()
                    executed_count += 1
                except Exception as e:
                    error_msg = str(e).lower()
                    # 如果是已存在的错误，可以忽略（幂等性）
                    if any(keyword in error_msg for keyword in [
                        "already exists", "duplicate", "relation", 
                        "constraint", "index", "trigger", "view"
                    ]):
                        logger.info(f"ℹ️  对象已存在，跳过: {statement[:50]}...")
                        skipped_count += 1
                    else:
                        logger.warning(f"⚠️  执行迁移语句失败: {e}")
                        logger.debug(f"失败的语句: {statement[:200]}")
                        error_count += 1
                        # 对于非关键错误，继续执行
        
        logger.info(f"✅ 优惠券和积分系统迁移完成！")
        logger.info(f"   执行: {executed_count}, 跳过: {skipped_count}, 错误: {error_count}")
        return True
        
    except Exception as e:
        logger.error(f"❌ 执行优惠券和积分系统迁移失败: {e}")
        import traceback
        traceback.print_exc()
        return False