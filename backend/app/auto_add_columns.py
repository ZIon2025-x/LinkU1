"""
自动检测并添加缺失的数据库字段

在 create_all 之前运行，用于给已有表添加新字段。
create_all(checkfirst=True) 只能创建新表，不能修改已有表结构。
"""

import logging
from sqlalchemy import text, inspect
from sqlalchemy.engine import Engine

logger = logging.getLogger(__name__)

# 定义需要自动添加的字段
# 格式: (表名, 字段名, SQL类型定义)
COLUMNS_TO_ADD = [
    # Flea market rental support (2026-03-25)
    ("flea_market_items", "listing_type", "VARCHAR(20) NOT NULL DEFAULT 'sale'"),
    ("flea_market_items", "deposit", "DECIMAL(12,2)"),
    ("flea_market_items", "rental_price", "DECIMAL(12,2)"),
    ("flea_market_items", "rental_unit", "VARCHAR(20)"),
]

# 定义需要自动添加的索引
# 格式: (索引名, 表名, 字段名)
INDEXES_TO_ADD = [
    ("idx_flea_market_items_listing_type", "flea_market_items", "listing_type"),
]


def auto_add_missing_columns(engine: Engine):
    """检测并添加缺失的字段和索引"""
    inspector = inspect(engine)
    tables = inspector.get_table_names()

    added_count = 0

    with engine.connect() as conn:
        for table_name, column_name, column_type in COLUMNS_TO_ADD:
            if table_name not in tables:
                continue

            existing_columns = [c["name"] for c in inspector.get_columns(table_name)]
            if column_name in existing_columns:
                continue

            try:
                sql = f'ALTER TABLE "{table_name}" ADD COLUMN "{column_name}" {column_type}'
                conn.execute(text(sql))
                conn.commit()
                logger.info(f"  ✅ 已添加字段: {table_name}.{column_name}")
                added_count += 1
            except Exception as e:
                logger.warning(f"  ⚠️ 添加字段 {table_name}.{column_name} 失败: {e}")
                conn.rollback()

        # 添加索引
        for index_name, table_name, column_name in INDEXES_TO_ADD:
            if table_name not in tables:
                continue

            existing_indexes = [i["name"] for i in inspector.get_indexes(table_name)]
            if index_name in existing_indexes:
                continue

            try:
                sql = f'CREATE INDEX "{index_name}" ON "{table_name}" ("{column_name}")'
                conn.execute(text(sql))
                conn.commit()
                logger.info(f"  ✅ 已添加索引: {index_name}")
                added_count += 1
            except Exception as e:
                logger.warning(f"  ⚠️ 添加索引 {index_name} 失败: {e}")
                conn.rollback()

    if added_count > 0:
        logger.info(f"✅ 自动迁移完成: 添加了 {added_count} 个字段/索引")
    else:
        logger.info("✅ 所有字段已存在，无需迁移")
