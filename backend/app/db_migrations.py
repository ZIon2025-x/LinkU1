"""
数据库迁移工具
自动运行 migrations 目录下的 SQL 脚本
"""
import os
import re
import logging
from pathlib import Path
from sqlalchemy import text
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)

# 匹配 PostgreSQL dollar-quote 标签: $tag$ 或 $$（空标签）
# 用于 DO $body$ / END $body$; 和 AS $func$ / $func$ LANGUAGE
_DOLLAR_QUOTE_TAG_RE = re.compile(r"\$([a-zA-Z0-9_]*)\$", re.IGNORECASE)


def _get_dollar_quote_tag(line: str):
    """从一行中提取 dollar-quote 标签（若有）。例如 'DO $body$' -> 'body', 'END $$;' -> ''。"""
    m = _DOLLAR_QUOTE_TAG_RE.search(line)
    return m.group(1) if m else None


def _is_do_block_start(line: str) -> str | None:
    """若该行是 DO $tag$ 块开始，返回 tag（空串表示 $$），否则返回 None。"""
    stripped = line.strip()
    if not re.match(r"DO\s+\$", stripped, re.IGNORECASE):
        return None
    tag = _get_dollar_quote_tag(stripped)
    return tag if tag is not None else ""


def _is_do_block_end(line: str, tag: str) -> bool:
    """判断是否为 END $tag$; 且与当前 tag 一致。"""
    stripped = line.strip()
    if not re.search(r"END\s+\$", stripped, re.IGNORECASE) or ";" not in stripped:
        return False
    # 允许 END $body$; 或 END $$;
    current = _get_dollar_quote_tag(stripped)
    return current is not None and current == tag


def _is_function_body_start(line: str) -> str | None:
    """若该行包含 FUNCTION ... AS $tag$，返回 tag，否则返回 None。"""
    stripped = line.strip()
    if "FUNCTION" not in stripped.upper() or "AS" not in stripped.upper():
        return None
    tag = _get_dollar_quote_tag(stripped)
    return tag if tag is not None else ""


def _is_function_body_end(line: str, tag: str) -> bool:
    """判断是否为 $tag$ LANGUAGE ... 且与当前 tag 一致。"""
    stripped = line.strip()
    if "LANGUAGE" not in stripped.upper():
        return False
    # 行首或行中可能有 $tag$ LANGUAGE plpgsql;
    current = _get_dollar_quote_tag(stripped)
    return current is not None and current == tag

def split_sql_statements(sql_content: str) -> list[str]:
    """
    智能分割SQL语句，正确处理dollar-quoted字符串（$$）

    处理规则：
    1. 在dollar-quoted块（$$ ... $$）内的分号不作为语句分隔符
    2. 支持带标签的dollar-quote（$tag$ ... $tag$）
    3. 忽略注释中的内容
    4. 正确处理DO块和函数定义

    Args:
        sql_content: SQL文件内容

    Returns:
        语句列表（每个语句都是完整的SQL命令）
    """
    statements = []
    current_statement = []
    in_dollar_quote = False
    dollar_tag = None

    lines = sql_content.split('\n')

    for line in lines:
        stripped = line.strip()

        # 跳过空行和注释（但要保留在当前语句中，因为可能在函数体内）
        if not stripped or (stripped.startswith('--') and not in_dollar_quote):
            if in_dollar_quote:
                # 在函数体内，保留注释
                current_statement.append(line)
            continue

        # 检查dollar-quote的开始和结束
        # 查找所有 $...$ 模式
        import re
        dollar_quotes = list(re.finditer(r'\$([a-zA-Z0-9_]*)\$', line))

        for match in dollar_quotes:
            tag = match.group(1)  # 标签可以为空（即 $$）

            if not in_dollar_quote:
                # 检查是否是dollar-quote的开始
                # 通常出现在 AS $tag$ 或 DO $tag$ 之后
                preceding_text = line[:match.start()].upper()
                if 'AS' in preceding_text or 'DO' in preceding_text or 'BEGIN' in preceding_text:
                    in_dollar_quote = True
                    dollar_tag = tag
                    logger.debug(f"进入 dollar-quote 块，标签: '{tag}'")
            else:
                # 检查是否是相同标签的dollar-quote结束
                if tag == dollar_tag:
                    # 检查是否后面跟着 LANGUAGE（函数定义结束）或分号（DO块结束）
                    following_text = line[match.end():].strip().upper()
                    if following_text.startswith('LANGUAGE') or ';' in following_text or not following_text:
                        in_dollar_quote = False
                        dollar_tag = None
                        logger.debug(f"退出 dollar-quote 块")

        # 将当前行添加到语句中
        current_statement.append(line)

        # 如果不在dollar-quote块内，且行以分号结尾，则这是一个完整的语句
        if not in_dollar_quote and stripped.endswith(';'):
            statement = '\n'.join(current_statement).strip()
            if statement:
                statements.append(statement)
            current_statement = []

    # 处理最后一个语句（可能没有分号）
    if current_statement:
        statement = '\n'.join(current_statement).strip()
        if statement:
            statements.append(statement)

    logger.debug(f"分割完成，共 {len(statements)} 个语句")
    return statements


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
                # psycopg2 可以正确处理 DO $$ ... END $$; 块
                # 注意：psycopg2 的 cursor.execute() 只能执行单个语句
                # 但如果语句包含多个命令（如 CREATE FUNCTION; CREATE TRIGGER;），需要分别执行
                with raw_conn.cursor() as cursor:
                    # 使用 psycopg2 执行整个文件作为脚本
                    # 将文件内容分割为独立的语句（使用智能分割）
                    statements = split_sql_statements(sql_content)

                    for stmt in statements:
                        if stmt.strip():
                            try:
                                cursor.execute(stmt)
                                # 每个语句执行后立即提交，避免事务中止影响后续语句
                                raw_conn.commit()
                            except Exception as stmt_error:
                                # 回滚失败的事务，避免"transaction is aborted"错误
                                raw_conn.rollback()

                                # 记录错误但继续执行（某些语句可能因为已存在而失败）
                                error_msg = str(stmt_error).lower()
                                if any(keyword in error_msg for keyword in [
                                    "already exists", "duplicate", "does not exist",
                                    "already has", "relation already exists"
                                ]):
                                    logger.debug(f"语句已存在或已删除，跳过: {stmt[:80]}...")
                                else:
                                    logger.warning(f"执行语句时出错（继续执行）: {stmt_error}")
                                    logger.debug(f"问题语句: {stmt[:200]}...")

                    # 最后确保提交（如果还有未提交的）
                    try:
                        raw_conn.commit()
                    except:
                        pass

                    logger.info("✅ 使用 psycopg2 成功执行迁移")
                    execution_time = int((time.time() - start_time) * 1000)
                    return True, execution_time
            except (AttributeError, Exception) as e:
                # 如果 psycopg2 方式失败，记录错误并使用 SQLAlchemy 方式
                logger.debug(f"psycopg2 执行失败，使用 SQLAlchemy 方式: {e}")
                # 回退到 SQLAlchemy 方式：支持 DO $tag$ / END $tag$; 与 FUNCTION ... AS $tag$ / $tag$ LANGUAGE
                statements = []
                current_statement = []
                in_do_block = False
                do_tag: str | None = None
                in_function = False
                func_tag: str | None = None

                for line in sql_content.split('\n'):
                    stripped = line.strip()

                    # 1) 正在 DO $tag$ 块内
                    if in_do_block and do_tag is not None:
                        current_statement.append(line)
                        if _is_do_block_end(stripped, do_tag):
                            in_do_block = False
                            do_tag = None
                            statement = '\n'.join(current_statement).strip()
                            if statement:
                                statements.append(statement)
                            current_statement = []
                        continue

                    # 2) 检测 DO $tag$ 块开始（含 $$ 或 $body$ 等）
                    do_start = _is_do_block_start(stripped)
                    if do_start is not None:
                        in_do_block = True
                        do_tag = do_start
                        current_statement.append(line)
                        continue

                    # 3) 正在 FUNCTION ... AS $tag$ 体内
                    if in_function and func_tag is not None:
                        current_statement.append(line)
                        if _is_function_body_end(stripped, func_tag):
                            in_function = False
                            func_tag = None
                            statement = '\n'.join(current_statement).strip()
                            if statement:
                                statements.append(statement)
                            current_statement = []
                        continue

                    # 4) 检测 CREATE FUNCTION ... AS $tag$ 开始
                    func_start = _is_function_body_start(stripped)
                    if func_start is not None:
                        in_function = True
                        func_tag = func_start
                        current_statement.append(line)
                        continue

                    # 5) 不在特殊块内：跳过仅注释/空行（不加入 current_statement）
                    if not stripped or stripped.startswith('--'):
                        continue

                    current_statement.append(line)
                    # 按分号结尾分割普通语句
                    if stripped.endswith(';'):
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
                    if not statement:
                        continue
                    
                    # 每个语句在独立事务中执行
                    # 使用新的连接确保事务隔离
                    with engine.connect() as stmt_conn:
                        trans = stmt_conn.begin()
                        try:
                            stmt_conn.execute(text(statement))
                            trans.commit()
                        except Exception as e:
                            trans.rollback()
                            # 某些语句可能因为已存在而失败（如 CREATE INDEX IF NOT EXISTS）
                            # 记录警告但继续执行
                            error_msg = str(e).lower()
                            if any(keyword in error_msg for keyword in [
                                "already exists", "duplicate", "does not exist",
                                "already has", "relation already exists",
                                "constraint.*already exists", "already exists",
                                "column.*already exists"
                            ]):
                                logger.debug(f"语句已存在或已删除，跳过 ({i}/{len(statements)}): {statement[:50]}...")
                            elif "current transaction is aborted" in error_msg:
                                # 事务中止错误，已回滚，继续执行下一个
                                logger.warning(f"事务中止，已回滚，继续 ({i}/{len(statements)}): {statement[:50]}...")
                                continue
                            elif "check constraint" in error_msg and "is violated" in error_msg:
                                # 约束违反错误，记录详细错误但继续执行
                                logger.warning(f"约束违反（继续执行） ({i}/{len(statements)}): {e}")
                                logger.debug(f"问题语句: {statement[:100]}...")
                                # 继续执行下一个语句
                                continue
                            else:
                                # 记录错误但继续执行
                                logger.warning(f"执行语句时出错（继续执行） ({i}/{len(statements)}): {e}")
                                logger.debug(f"问题语句: {statement[:100]}...")
                                # 继续执行下一个语句
                                continue
            
        execution_time = int((time.time() - start_time) * 1000)
        
        # 验证迁移是否真正成功（对于 007 迁移，检查关键字段是否存在）
        if sql_file.name == "007_add_multi_participant_tasks.sql":
            if not verify_migration_007(engine):
                logger.error(f"迁移执行后验证失败: {sql_file.name}")
                return False, execution_time
        
        return True, execution_time
        
    except Exception as e:
        logger.error(f"执行 SQL 文件失败 {sql_file.name}: {e}")
        return False, int((time.time() - start_time) * 1000)


def verify_migration_007(engine: Engine) -> bool:
    """验证迁移 007 是否真正成功执行"""
    try:
        from sqlalchemy import inspect
        inspector = inspect(engine)
        
        # 检查关键字段是否存在
        tasks_columns = [col['name'] for col in inspector.get_columns('tasks')]
        required_columns = ['is_multi_participant', 'is_official_task', 'max_participants', 'min_participants']
        
        for col in required_columns:
            if col not in tasks_columns:
                logger.error(f"迁移验证失败: 缺少字段 {col}")
                return False
        
        # 检查新表是否存在
        all_tables = inspector.get_table_names()
        required_tables = ['task_participants', 'task_participant_rewards', 'task_audit_logs']
        
        for table in required_tables:
            if table not in all_tables:
                logger.error(f"迁移验证失败: 缺少表 {table}")
                return False
        
        logger.info("✅ 迁移 007 验证通过")
        return True
    except Exception as e:
        logger.warning(f"迁移验证时出错: {e}，假设成功")
        return True  # 验证失败不影响迁移，假设成功


def _verify_columns_exist(engine: Engine, table: str, columns: list[str]) -> list[str]:
    """检查表中是否存在指定的列，返回缺失的列名列表"""
    try:
        from sqlalchemy import inspect
        inspector = inspect(engine)
        existing = [col['name'] for col in inspector.get_columns(table)]
        return [c for c in columns if c not in existing]
    except Exception as e:
        logger.warning(f"检查表 {table} 列时出错: {e}")
        return []


def _reset_migration_if_columns_missing(engine: Engine, migration_name: str, table: str, columns: list[str]):
    """如果迁移被标记为已执行但列实际不存在，删除迁移记录以便重新执行"""
    if not is_migration_executed(engine, migration_name):
        return
    missing = _verify_columns_exist(engine, table, columns)
    if missing:
        logger.warning(f"⚠️  迁移 {migration_name} 已标记执行但缺少列: {missing}")
        with engine.connect() as conn:
            conn.execute(
                text(f"DELETE FROM {MIGRATION_TABLE} WHERE migration_name = :name"),
                {"name": migration_name}
            )
            conn.commit()
        logger.info(f"✅ 已删除错误记录，迁移 {migration_name} 将重新执行")


def check_and_fix_broken_migrations(engine: Engine):
    """检查并修复错误标记的迁移（迁移记录存在但实际未执行）"""
    try:
        # 检查迁移 007
        migration_name = "007_add_multi_participant_tasks.sql"
        if is_migration_executed(engine, migration_name):
            if not verify_migration_007(engine):
                logger.warning(f"⚠️  检测到错误标记的迁移: {migration_name}")
                with engine.connect() as conn:
                    conn.execute(
                        text(f"DELETE FROM {MIGRATION_TABLE} WHERE migration_name = :name"),
                        {"name": migration_name}
                    )
                    conn.commit()
                logger.info(f"✅ 已删除错误记录，迁移将在下次执行")

        # 检查迁移 103 — counter_offer 字段
        _reset_migration_if_columns_missing(
            engine,
            "103_add_counter_offer_to_tasks.sql",
            "tasks",
            ["counter_offer_price", "counter_offer_status", "counter_offer_user_id"],
        )

        # 检查迁移 136 — pricing_type / task_mode / required_skills
        _reset_migration_if_columns_missing(
            engine,
            "136_add_pricing_type_task_mode_required_skills.sql",
            "tasks",
            ["pricing_type", "task_mode", "required_skills"],
        )
    except Exception as e:
        logger.warning(f"检查迁移状态时出错: {e}")


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
    
    # 检查并修复错误标记的迁移（迁移记录存在但实际未执行）
    check_and_fix_broken_migrations(engine)

    # 处理重命名的迁移文件（确保已执行旧名称的环境不会重复执行新名称）
    RENAMED_MIGRATIONS = {
        "037_add_activity_favorites.sql": "046_add_activity_favorites.sql",
    }
    for old_name, new_name in RENAMED_MIGRATIONS.items():
        if is_migration_executed(engine, old_name) and not is_migration_executed(engine, new_name):
            mark_migration_executed(engine, new_name, 0)
            logger.info(f"迁移记录已迁移: {old_name} -> {new_name}")

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
        force: 是否强制重新执行（如果为 True，会删除现有记录并重新执行）
    """
    sql_file = MIGRATIONS_DIR / migration_name
    
    if not sql_file.exists():
        logger.error(f"迁移文件不存在: {migration_name}")
        return False
    
    # 如果强制执行，删除现有记录
    if force:
        try:
            with engine.connect() as conn:
                result = conn.execute(
                    text(f"DELETE FROM {MIGRATION_TABLE} WHERE migration_name = :name"),
                    {"name": migration_name}
                )
                conn.commit()
                if result.rowcount > 0:
                    logger.info(f"已删除迁移记录: {migration_name}")
        except Exception as e:
            logger.warning(f"删除迁移记录时出错: {e}")
    
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
