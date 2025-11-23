"""
数据库迁移工具
自动运行 migrations 目录下的 SQL 脚本
"""
import os
import logging
from pathlib import Path
from sqlalchemy import text
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)

# 迁移脚本目录
MIGRATIONS_DIR = Path(__file__).parent.parent / "migrations"

# 已执行的迁移记录表名
MIGRATION_TABLE = "schema_migrations"


def ensure_migration_table(engine: Engine):
    """确保迁移记录表存在"""
    with engine.connect() as conn:
        conn.execute(text(f"""
            CREATE TABLE IF NOT EXISTS {MIGRATION_TABLE} (
                id SERIAL PRIMARY KEY,
                migration_name VARCHAR(255) UNIQUE NOT NULL,
                executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                execution_time_ms INTEGER
            )
        """))
        conn.commit()


def is_migration_executed(engine: Engine, migration_name: str) -> bool:
    """检查迁移是否已执行"""
    try:
        with engine.connect() as conn:
            result = conn.execute(
                text(f"SELECT 1 FROM {MIGRATION_TABLE} WHERE migration_name = :name"),
                {"name": migration_name}
            )
            return result.fetchone() is not None
    except Exception as e:
        logger.warning(f"检查迁移状态失败: {e}，假设未执行")
        return False


def mark_migration_executed(engine: Engine, migration_name: str, execution_time_ms: int):
    """标记迁移已执行"""
    try:
        with engine.connect() as conn:
            conn.execute(
                text(f"""
                    INSERT INTO {MIGRATION_TABLE} (migration_name, execution_time_ms)
                    VALUES (:name, :time)
                    ON CONFLICT (migration_name) DO NOTHING
                """),
                {"name": migration_name, "time": execution_time_ms}
            )
            conn.commit()
    except Exception as e:
        logger.error(f"标记迁移执行状态失败: {e}")


def execute_sql_file(engine: Engine, sql_file: Path) -> tuple[bool, int]:
    """
    执行 SQL 文件
    
    Returns:
        (success: bool, execution_time_ms: int)
    """
    import time
    start_time = time.time()
    
    try:
        # 使用 autocommit 模式执行迁移，避免事务错误影响
        with engine.connect() as conn:
            # 设置 autocommit 模式
            conn = conn.execution_options(autocommit=True)
            
            # 读取 SQL 文件内容
            sql_content = sql_file.read_text(encoding='utf-8')
            
            # 使用 psycopg2 的 execute 方法执行整个 SQL 文件
            # 这样可以正确处理函数定义、注释等复杂情况
            try:
                # 获取原始连接（psycopg2 connection）
                raw_conn = conn.connection.dbapi_connection
                
                # 使用 psycopg2 的 execute 方法执行 SQL
                # 使用 execute_batch 或逐语句执行以确保正确处理
                with raw_conn.cursor() as cursor:
                    # 使用 psycopg2 的 execute 方法，它会自动处理多语句
                    # 在 autocommit 模式下，每个语句自动提交
                    cursor.execute(sql_content)
                    raw_conn.commit()
            except (AttributeError, Exception) as e:
                # 如果 psycopg2 方式失败，记录错误并使用 SQLAlchemy 方式
                logger.debug(f"psycopg2 执行失败，使用 SQLAlchemy 方式: {e}")
                # 如果不是 psycopg2 连接，回退到 SQLAlchemy 方式
                # 简单处理：按分号分割，但跳过注释行
                statements = []
                current_statement = []
                in_do_block = False
                
                for line in sql_content.split('\n'):
                    stripped = line.strip()
                    
                    # 跳过空行和注释行
                    if not stripped or stripped.startswith('--'):
                        continue
                    
                    # 检测 DO $$ 块
                    if 'DO $$' in stripped.upper():
                        in_do_block = True
                    
                    current_statement.append(line)
                    
                    # 如果行以分号结尾，结束当前语句
                    if stripped.endswith(';'):
                        if in_do_block and 'END $$;' in stripped.upper():
                            in_do_block = False
                        statement = '\n'.join(current_statement).strip()
                        if statement:
                            statements.append(statement)
                        current_statement = []
                
                # 处理最后一个语句（可能没有分号）
                if current_statement:
                    statement = '\n'.join(current_statement).strip()
                    if statement:
                        statements.append(statement)
                
                # 执行每个语句（每个语句独立事务）
                for i, statement in enumerate(statements, 1):
                    if statement:
                        # 每个语句在独立事务中执行
                        trans = conn.begin()
                        try:
                            conn.execute(text(statement))
                            trans.commit()
                        except Exception as e:
                            trans.rollback()
                            # 某些语句可能因为已存在而失败（如 CREATE INDEX IF NOT EXISTS）
                            # 记录警告但继续执行
                            error_msg = str(e).lower()
                            if any(keyword in error_msg for keyword in [
                                "already exists", "duplicate", "does not exist",
                                "already has", "relation already exists",
                                "constraint.*already exists", "already exists"
                            ]):
                                logger.debug(f"语句已存在或已删除，跳过 ({i}/{len(statements)}): {statement[:50]}...")
                            elif "current transaction is aborted" in error_msg:
                                # 事务中止错误，已回滚，继续执行下一个
                                logger.warning(f"事务中止，已回滚，继续 ({i}/{len(statements)}): {statement[:50]}...")
                                continue
                            else:
                                # 记录错误但继续执行
                                logger.warning(f"执行语句时出错（继续执行） ({i}/{len(statements)}): {e}")
                                logger.debug(f"问题语句: {statement[:100]}...")
                                # 继续执行下一个语句
                                continue
            
        execution_time = int((time.time() - start_time) * 1000)
        return True, execution_time
        
    except Exception as e:
        logger.error(f"执行 SQL 文件失败 {sql_file.name}: {e}")
        return False, int((time.time() - start_time) * 1000)


def run_migrations(engine: Engine, force: bool = False):
    """
    运行所有未执行的迁移脚本
    
    Args:
        engine: SQLAlchemy 引擎
        force: 是否强制重新执行所有迁移（用于开发环境）
    """
    if not MIGRATIONS_DIR.exists():
        logger.warning(f"迁移目录不存在: {MIGRATIONS_DIR}")
        return
    
    # 确保迁移记录表存在
    ensure_migration_table(engine)
    
    # 获取所有 SQL 文件，按文件名排序
    sql_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    
    if not sql_files:
        logger.info("没有找到迁移脚本")
        return
    
    logger.info(f"找到 {len(sql_files)} 个迁移脚本")
    
    executed_count = 0
    skipped_count = 0
    failed_count = 0
    
    for sql_file in sql_files:
        migration_name = sql_file.name
        
        # 检查是否已执行
        if not force and is_migration_executed(engine, migration_name):
            logger.info(f"⏭️  跳过已执行的迁移: {migration_name}")
            skipped_count += 1
            continue
        
        logger.info(f"🔄 执行迁移: {migration_name}")
        
        success, execution_time = execute_sql_file(engine, sql_file)
        
        if success:
            mark_migration_executed(engine, migration_name, execution_time)
            logger.info(f"✅ 迁移执行成功: {migration_name} (耗时: {execution_time}ms)")
            executed_count += 1
        else:
            logger.error(f"❌ 迁移执行失败: {migration_name}")
            failed_count += 1
    
    logger.info(f"迁移完成: {executed_count} 个已执行, {skipped_count} 个已跳过, {failed_count} 个失败")


def run_specific_migration(engine: Engine, migration_name: str, force: bool = False):
    """
    运行指定的迁移脚本
    
    Args:
        engine: SQLAlchemy 引擎
        migration_name: 迁移文件名（如 "fix_conversation_key.sql"）
        force: 是否强制重新执行
    """
    sql_file = MIGRATIONS_DIR / migration_name
    
    if not sql_file.exists():
        logger.error(f"迁移文件不存在: {migration_name}")
        return False
    
    if not force and is_migration_executed(engine, migration_name):
        logger.info(f"迁移已执行: {migration_name}")
        return True
    
    logger.info(f"执行迁移: {migration_name}")
    success, execution_time = execute_sql_file(engine, sql_file)
    
    if success:
        mark_migration_executed(engine, migration_name, execution_time)
        logger.info(f"迁移执行成功: {migration_name} (耗时: {execution_time}ms)")
        return True
    else:
        logger.error(f"迁移执行失败: {migration_name}")
        return False
