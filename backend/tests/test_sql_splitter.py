"""
SQL 语句分割器单元测试

测试覆盖:
- split_sql_statements: 智能 SQL 语句分割
- 普通语句分割
- DO $$ ... END $$; 块处理
- CREATE FUNCTION 块处理
- 注释处理
- 混合场景

运行方式:
    pytest tests/test_sql_splitter.py -v
"""

import pytest
from app.db_migrations import split_sql_statements


class TestSplitSqlStatements:
    """SQL 语句分割测试"""

    def test_single_statement(self):
        """单个语句"""
        sql = "CREATE TABLE test (id SERIAL PRIMARY KEY);"
        result = split_sql_statements(sql)
        assert len(result) == 1
        assert "CREATE TABLE" in result[0]

    def test_multiple_simple_statements(self):
        """多个简单语句"""
        sql = """
CREATE TABLE users (id SERIAL PRIMARY KEY);
CREATE TABLE posts (id SERIAL PRIMARY KEY);
CREATE INDEX idx_posts ON posts(id);
"""
        result = split_sql_statements(sql)
        assert len(result) == 3

    def test_do_block_preserved(self):
        """DO $$ ... END $$; 块应作为一个整体"""
        sql = """
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_status') THEN
        CREATE TYPE task_status AS ENUM ('open', 'closed');
    END IF;
END $$;
CREATE TABLE test (id SERIAL PRIMARY KEY);
"""
        result = split_sql_statements(sql)
        assert len(result) == 2
        # DO 块应包含完整的 BEGIN ... END
        assert "BEGIN" in result[0]
        assert "END" in result[0]
        assert "CREATE TABLE" in result[1]

    def test_do_block_with_tag(self):
        """DO $body$ ... END $body$; 块应作为一个整体"""
        sql = """
DO $body$
BEGIN
    RAISE NOTICE 'test';
END $body$;
SELECT 1;
"""
        result = split_sql_statements(sql)
        assert len(result) == 2
        assert "$body$" in result[0]

    def test_function_definition(self):
        """CREATE FUNCTION 定义应作为一个整体"""
        sql = """
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TABLE test (id SERIAL PRIMARY KEY);
"""
        result = split_sql_statements(sql)
        assert len(result) == 2
        assert "FUNCTION" in result[0]
        assert "LANGUAGE" in result[0]

    def test_comments_skipped(self):
        """注释行应被忽略（不计入语句）"""
        sql = """
-- This is a comment
CREATE TABLE test (id SERIAL PRIMARY KEY);
-- Another comment
CREATE INDEX idx_test ON test(id);
"""
        result = split_sql_statements(sql)
        assert len(result) == 2

    def test_empty_input(self):
        """空输入应返回空列表"""
        assert split_sql_statements("") == []
        assert split_sql_statements("-- only comments\n-- nothing else") == []

    def test_insert_with_values(self):
        """INSERT 语句包含多行 VALUES"""
        sql = """
INSERT INTO configs (key, value) VALUES
('key1', 'value1'),
('key2', 'value2'),
('key3', 'value3')
ON CONFLICT (key) DO NOTHING;
"""
        result = split_sql_statements(sql)
        assert len(result) == 1
        assert "key1" in result[0]
        assert "key3" in result[0]

    def test_create_table_if_not_exists(self):
        """CREATE TABLE IF NOT EXISTS 语句"""
        sql = """
CREATE TABLE IF NOT EXISTS newbie_task_config (
    id SERIAL PRIMARY KEY,
    task_key VARCHAR(50) UNIQUE NOT NULL,
    stage INTEGER NOT NULL,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
"""
        result = split_sql_statements(sql)
        assert len(result) == 1
        assert "newbie_task_config" in result[0]

    def test_migration_111_structure(self):
        """模拟 migration 111 的结构（多个 CREATE TABLE + INSERT）"""
        sql = """
CREATE TABLE IF NOT EXISTS newbie_task_config (
    id SERIAL PRIMARY KEY,
    task_key VARCHAR(50) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS stage_bonus_config (
    id SERIAL PRIMARY KEY,
    stage INTEGER UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_user_tasks ON user_tasks(user_id);

INSERT INTO newbie_task_config (task_key) VALUES
('upload_avatar'),
('fill_bio')
ON CONFLICT (task_key) DO NOTHING;
"""
        result = split_sql_statements(sql)
        assert len(result) == 4

    def test_semicolons_in_do_block_not_split(self):
        """DO 块内的分号不应导致语句分割"""
        sql = """
DO $$
BEGIN
    INSERT INTO test VALUES (1);
    INSERT INTO test VALUES (2);
    INSERT INTO test VALUES (3);
END $$;
"""
        result = split_sql_statements(sql)
        assert len(result) == 1
        assert result[0].count("INSERT") == 3

    def test_alter_table_statements(self):
        """ALTER TABLE 语句"""
        sql = """
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
"""
        result = split_sql_statements(sql)
        assert len(result) == 2

    def test_statement_without_trailing_semicolon(self):
        """没有分号结尾的最后一个语句也应被包含"""
        sql = "SELECT 1"
        result = split_sql_statements(sql)
        assert len(result) == 1
        assert result[0] == "SELECT 1"

    def test_mixed_complex_migration(self):
        """复杂迁移：混合 CREATE TABLE、DO 块、INSERT"""
        sql = """
-- Migration: Add notification system

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'read_at'
    ) THEN
        ALTER TABLE notifications ADD COLUMN read_at TIMESTAMP;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);

INSERT INTO notifications (user_id, message) VALUES
(1, 'Welcome!')
ON CONFLICT DO NOTHING;
"""
        result = split_sql_statements(sql)
        assert len(result) == 4
        # 第一个是 CREATE TABLE
        assert "CREATE TABLE" in result[0]
        # 第二个是 DO 块
        assert "DO $$" in result[1]
        assert "END $$" in result[1]
        # 第三个是 CREATE INDEX
        assert "CREATE INDEX" in result[2]
        # 第四个是 INSERT
        assert "INSERT" in result[3]
