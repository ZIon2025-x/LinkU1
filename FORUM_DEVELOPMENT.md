# 论坛功能开发文档

> **版本**: v1.4  
> **创建日期**: 2025-01-27  
> **最后更新**: 2025-01-27  
> **设计原则**: 可扩展、高性能、用户友好、安全优先

---

## 📋 目录

1. [需求概述](#需求概述)
2. [功能设计](#功能设计)
3. [数据库设计](#数据库设计)
4. [API设计](#api设计)
5. [前端设计](#前端设计)
6. [开发步骤](#开发步骤)
7. [测试计划](#测试计划)
8. [部署说明](#部署说明)
9. [性能优化](#性能优化)
10. [安全考虑](#安全考虑)
11. [重要实现注意事项](#重要实现注意事项)

---

## 📋 需求概述

### 核心目标

开发一个完整的论坛系统，允许用户：
- 创建和管理论坛板块（分类）
- 发布主题帖
- 回复和评论
- 点赞/收藏帖子
- 搜索和筛选内容
- 管理自己的帖子

### 业务价值

- **增强用户粘性**: 提供社区交流平台
- **内容沉淀**: 积累用户生成内容（UGC）
- **知识分享**: 促进用户之间的经验交流
- **社区建设**: 形成活跃的用户社区

---

## 🎯 功能设计

### 1. 论坛板块（Forum Category）

#### 功能特性
- 创建和管理论坛板块（管理员）
- 板块列表展示
- 板块详情（包含帖子统计）
- 板块图标和描述
- 板块排序和显示顺序

#### 板块属性
- 名称（必填）
- 描述（可选）
- 图标（可选）
- 排序权重
- 是否显示
- 帖子数量统计
- 最后更新时间

### 2. 主题帖（Post）

#### 功能特性
- 发布主题帖
- 编辑自己的帖子
- 删除自己的帖子
- 帖子详情查看
- 帖子列表（分页）
- 帖子搜索
- 帖子筛选（按板块、时间、热度等）
- 帖子置顶（管理员）
- 帖子加精（管理员）
- 帖子锁定（管理员）

#### 帖子属性
- 标题（必填，最大200字符）
- 内容（必填，支持Markdown）
- 所属板块（必填）
- 发布者（必填）
- 发布时间
- 最后更新时间
- 浏览次数
- 回复数
- 点赞数
- 收藏数
- 是否置顶
- 是否加精
- 是否锁定
- 是否删除（软删除）

### 3. 回复（Reply）

#### 功能特性
- 回复主题帖
- 回复其他回复（嵌套回复，最多3层）
- 编辑自己的回复
- 删除自己的回复
- 回复列表（分页）
- 回复点赞

#### 回复属性
- 内容（必填，支持Markdown）
- 所属帖子（必填）
- 父回复ID（可选，用于嵌套回复）
- 回复层级（1-3层）
- 发布者（必填）
- 发布时间
- 最后更新时间
- 点赞数
- 是否删除（软删除）

### 4. 点赞（Like）

#### 功能特性
- 点赞/取消点赞帖子
- 点赞/取消点赞回复
- 查看点赞列表

#### 点赞属性
- 目标类型（post/reply）
- 目标ID
- 用户ID
- 创建时间

### 5. 收藏（Favorite）

#### 功能特性
- 收藏/取消收藏帖子
- 查看收藏列表

#### 收藏属性
- 帖子ID
- 用户ID
- 创建时间

### 6. 搜索功能

#### 功能特性
- 全文搜索（标题和内容）
- 按板块筛选
- 按时间排序（最新、最热）
- 按回复数排序
- 按点赞数排序

### 7. 通知功能

#### 功能特性
- 帖子被回复时通知
- 回复被回复时通知
- 帖子被点赞时通知（可选）
- 帖子被加精/置顶时通知
- 通知已读/未读状态管理
- 通知列表查看

#### 通知属性
- 通知类型（reply_post/reply_reply/like_post/feature_post/pin_post）
- 目标类型（post/reply）
- 目标ID
- 发送者ID
- 接收者ID
- 是否已读
- 创建时间

**通知类型范围说明**:
- **目前只对帖子点赞发通知**，不包含回复点赞；如后续需要可以增加 `like_reply` 类型，并扩展表约束
- 通知类型枚举：`reply_post`（回复帖子）、`reply_reply`（回复回复）、`like_post`（点赞帖子）、`feature_post`（加精帖子）、`pin_post`（置顶帖子）

### 8. 举报/审核功能

#### 功能特性
- 用户举报帖子/回复
- 管理员审核举报
- 举报状态管理（待处理/已处理/已驳回）
- 举报原因记录

#### 举报属性
- 目标类型（post/reply）
- 目标ID
- 举报人ID
- 举报原因
- 举报说明
- 处理状态（pending/processed/rejected）
- 处理人ID（管理员）
- 处理时间
- 创建时间

---

## 🗄️ 数据库设计

### 1. 论坛板块表（forum_categories）

```sql
CREATE TABLE forum_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    icon VARCHAR(200),
    sort_order INTEGER DEFAULT 0,
    is_visible BOOLEAN DEFAULT TRUE,
    post_count INTEGER DEFAULT 0,
    last_post_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_forum_categories_visible ON forum_categories(is_visible, sort_order);
```

### 2. 主题帖表（forum_posts）

```sql
CREATE TABLE forum_posts (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES forum_categories(id) ON DELETE CASCADE,
    author_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    view_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    favorite_count INTEGER DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    is_featured BOOLEAN DEFAULT FALSE,
    is_locked BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    is_visible BOOLEAN DEFAULT TRUE NOT NULL,  -- 风控隐藏字段，FALSE 时对普通用户不可见
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_reply_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_forum_posts_category ON forum_posts(category_id, is_deleted, is_visible, created_at DESC);
CREATE INDEX idx_forum_posts_author ON forum_posts(author_id, is_deleted, is_visible);
CREATE INDEX idx_forum_posts_pinned ON forum_posts(is_pinned DESC, created_at DESC);
CREATE INDEX idx_forum_posts_last_reply ON forum_posts(is_deleted, is_visible, last_reply_at DESC NULLS LAST);

-- 注意：索引中的 DESC 排序方向与常用 ORDER BY 场景对齐，提升查询性能
-- 全文搜索索引：使用 'simple' 配置（对中文分词效果较差）
-- ⚠️ 建议：尽快接入 MeiliSearch / Elasticsearch 或使用 pg_bigm 扩展 + gin 索引以获得更好的中文搜索体验
CREATE INDEX idx_forum_posts_search ON forum_posts USING GIN(to_tsvector('simple', title || ' ' || content));

-- 如果使用 pg_bigm 扩展（推荐用于中文搜索）：
-- CREATE EXTENSION IF NOT EXISTS pg_bigm;
-- CREATE INDEX idx_forum_posts_search_bigm ON forum_posts USING gin(to_tsvector('public.bigm', title || ' ' || content));
```

### 3. 回复表（forum_replies）

```sql
CREATE TABLE forum_replies (
    id SERIAL PRIMARY KEY,
    content TEXT NOT NULL,
    post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    parent_reply_id INTEGER REFERENCES forum_replies(id) ON DELETE CASCADE,
    reply_level INTEGER DEFAULT 1 CHECK (reply_level BETWEEN 1 AND 3),
    author_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    like_count INTEGER DEFAULT 0,
    is_deleted BOOLEAN DEFAULT FALSE,
    is_visible BOOLEAN DEFAULT TRUE NOT NULL,  -- 风控隐藏字段，FALSE 时对普通用户不可见
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_forum_replies_post ON forum_replies(post_id, created_at ASC);
CREATE INDEX idx_forum_replies_parent ON forum_replies(parent_reply_id);
CREATE INDEX idx_forum_replies_author ON forum_replies(author_id, is_deleted, is_visible);
```

### 4. 点赞表（forum_likes）

```sql
CREATE TABLE forum_likes (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(target_type, target_id, user_id)
);

CREATE INDEX idx_forum_likes_target ON forum_likes(target_type, target_id);
CREATE INDEX idx_forum_likes_user ON forum_likes(user_id);
```

### 5. 收藏表（forum_favorites）

```sql
CREATE TABLE forum_favorites (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES forum_posts(id) ON DELETE CASCADE,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

CREATE INDEX idx_forum_favorites_user ON forum_favorites(user_id, created_at DESC);
CREATE INDEX idx_forum_favorites_post ON forum_favorites(post_id);
```

### 6. 通知表（forum_notifications）

```sql
CREATE TABLE forum_notifications (
    id SERIAL PRIMARY KEY,
    notification_type VARCHAR(20) NOT NULL CHECK (notification_type IN ('reply_post', 'reply_reply', 'like_post', 'feature_post', 'pin_post')),
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    from_user_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    to_user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_read BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_forum_notifications_user ON forum_notifications(to_user_id, is_read, created_at DESC);
CREATE INDEX idx_forum_notifications_target ON forum_notifications(target_type, target_id);
```

**通知类型扩展说明**:
- 当前枚举：`reply_post`、`reply_reply`、`like_post`、`feature_post`、`pin_post`
- **如需新增类型**（例如 `like_reply`），需要同时：
  1. 更新数据库 CheckConstraint：`CHECK (notification_type IN ('reply_post', 'reply_reply', 'like_post', 'feature_post', 'pin_post', 'like_reply'))`
  2. 更新 Alembic 迁移文件中的约束定义
  3. 更新后端枚举和发送逻辑
  4. 更新前端文案和通知处理逻辑

### 7. 举报表（forum_reports）

```sql
CREATE TABLE forum_reports (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    reporter_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason VARCHAR(50) NOT NULL,  -- 举报原因：spam/abuse/inappropriate/copyright/other（由业务层校验，DB不做枚举约束）
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'processed', 'rejected')),
    processor_id VARCHAR(8) REFERENCES users(id) ON DELETE SET NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    action VARCHAR(50),  -- 处理动作：delete_post, delete_reply, no_action, warn_user 等（用于审计追溯）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX idx_forum_reports_status ON forum_reports(status, created_at DESC);
CREATE INDEX idx_forum_reports_target ON forum_reports(target_type, target_id);
CREATE INDEX idx_forum_reports_reporter ON forum_reports(reporter_id);

-- 防止同一用户对同一目标重复举报（仅限 pending 状态）
-- 注意：PostgreSQL 不支持在表级 UNIQUE 约束后加 WHERE，必须使用部分唯一索引
CREATE UNIQUE INDEX idx_forum_reports_unique_pending 
ON forum_reports(target_type, target_id, reporter_id) 
WHERE status = 'pending';
```

### 8. 数据库迁移文件

创建文件：`backend/alembic/versions/xxx_add_forum_tables.py`

```python
"""add forum tables

Revision ID: xxxxx
Revises: previous_revision
Create Date: 2025-01-27
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers
revision = 'xxxxx'
down_revision = 'previous_revision'
branch_labels = None
depends_on = None

def upgrade():
    # 创建论坛板块表
    op.create_table(
        'forum_categories',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('icon', sa.String(length=200), nullable=True),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_visible', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('post_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('last_post_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name')
    )
    op.create_index('idx_forum_categories_visible', 'forum_categories', ['is_visible', 'sort_order'])
    
    # 创建主题帖表
    op.create_table(
        'forum_posts',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('category_id', sa.Integer(), nullable=False),
        sa.Column('author_id', sa.String(length=8), nullable=False),
        sa.Column('view_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('reply_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('like_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('favorite_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_pinned', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_featured', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_locked', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_visible', sa.Boolean(), nullable=False, server_default=sa.text('true')),  -- 风控隐藏字段
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('last_reply_at', sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(['category_id'], ['forum_categories.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['author_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    # 注意：PostgreSQL 索引支持 DESC 排序，使用 op.execute 创建带排序的索引以与常用查询对齐
    # 注意：索引中包含 is_visible 以匹配查询约定（WHERE is_deleted = FALSE AND is_visible = TRUE）
    op.execute("CREATE INDEX idx_forum_posts_author ON forum_posts(author_id, is_deleted, is_visible)")
    op.execute("CREATE INDEX idx_forum_posts_category ON forum_posts(category_id, is_deleted, is_visible, created_at DESC)")
    op.execute("CREATE INDEX idx_forum_posts_pinned ON forum_posts(is_pinned DESC, created_at DESC)")
    op.execute("CREATE INDEX idx_forum_posts_last_reply ON forum_posts(is_deleted, is_visible, last_reply_at DESC NULLS LAST)")
    
    # 创建全文搜索索引（PostgreSQL）
    # ⚠️ 注意：'simple' 配置对中文分词效果较差
    # 推荐方案1：使用 pg_bigm 扩展（需要先安装扩展）
    # op.execute("CREATE EXTENSION IF NOT EXISTS pg_bigm")
    # op.execute("""
    #     CREATE INDEX idx_forum_posts_search ON forum_posts 
    #     USING GIN(to_tsvector('public.bigm', title || ' ' || content))
    # """)
    # 推荐方案2：接入 MeiliSearch / Elasticsearch（生产环境推荐）
    # 当前使用 simple 配置作为临时方案
    op.execute("""
        CREATE INDEX idx_forum_posts_search ON forum_posts 
        USING GIN(to_tsvector('simple', title || ' ' || content))
    """)
    
    # 创建回复表
    op.create_table(
        'forum_replies',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('post_id', sa.Integer(), nullable=False),
        sa.Column('parent_reply_id', sa.Integer(), nullable=True),
        sa.Column('reply_level', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('author_id', sa.String(length=8), nullable=False),
        sa.Column('like_count', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('is_deleted', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_visible', sa.Boolean(), nullable=False, server_default=sa.text('true')),  -- 风控隐藏字段
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['post_id'], ['forum_posts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['parent_reply_id'], ['forum_replies.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['author_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint('reply_level BETWEEN 1 AND 3', name='check_reply_level')
    )
    op.create_index('idx_forum_replies_post', 'forum_replies', ['post_id', 'created_at'], postgresql_ops={'created_at': 'ASC'})
    op.create_index('idx_forum_replies_parent', 'forum_replies', ['parent_reply_id'])
    # 注意：索引中包含 is_visible 以匹配查询约定（WHERE is_deleted = FALSE AND is_visible = TRUE）
    op.execute("CREATE INDEX idx_forum_replies_author ON forum_replies(author_id, is_deleted, is_visible)")
    
    # 创建点赞表
    # 注意：target_id 没有外键约束（因为是多态关联），需要在业务逻辑中处理级联删除
    # 删除帖子/回复时，必须同时删除对应的点赞记录
    op.create_table(
        'forum_likes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('target_type', sa.String(length=10), nullable=False),
        sa.Column('target_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.String(length=8), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('target_type', 'target_id', 'user_id'),
        sa.CheckConstraint("target_type IN ('post', 'reply')", name='check_target_type')
    )
    op.create_index('idx_forum_likes_target', 'forum_likes', ['target_type', 'target_id'])
    op.create_index('idx_forum_likes_user', 'forum_likes', ['user_id'])
    
    # 创建收藏表
    op.create_table(
        'forum_favorites',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('post_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.String(length=8), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['post_id'], ['forum_posts.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('post_id', 'user_id')
    )
    op.execute("CREATE INDEX idx_forum_favorites_user ON forum_favorites(user_id, created_at DESC)")
    op.create_index('idx_forum_favorites_post', 'forum_favorites', ['post_id'])
    
    # 创建通知表
    op.create_table(
        'forum_notifications',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('notification_type', sa.String(length=20), nullable=False),
        sa.Column('target_type', sa.String(length=10), nullable=False),
        sa.Column('target_id', sa.Integer(), nullable=False),
        sa.Column('from_user_id', sa.String(length=8), nullable=True),
        sa.Column('to_user_id', sa.String(length=8), nullable=False),
        sa.Column('is_read', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['from_user_id'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['to_user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint("notification_type IN ('reply_post', 'reply_reply', 'like_post', 'feature_post', 'pin_post')", name='check_notification_type'),
        sa.CheckConstraint("target_type IN ('post', 'reply')", name='check_notification_target_type')
    )
    op.execute("CREATE INDEX idx_forum_notifications_user ON forum_notifications(to_user_id, is_read, created_at DESC)")
    op.create_index('idx_forum_notifications_target', 'forum_notifications', ['target_type', 'target_id'])
    
    # 创建举报表
    op.create_table(
        'forum_reports',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('target_type', sa.String(length=10), nullable=False),
        sa.Column('target_id', sa.Integer(), nullable=False),
        sa.Column('reporter_id', sa.String(length=8), nullable=False),
        sa.Column('reason', sa.String(length=50), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='pending'),
        sa.Column('processor_id', sa.String(length=8), nullable=True),
        sa.Column('processed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('action', sa.String(length=50), nullable=True),  # 处理动作：用于审计追溯
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.ForeignKeyConstraint(['reporter_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['processor_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        sa.CheckConstraint("target_type IN ('post', 'reply')", name='check_report_target_type'),
        sa.CheckConstraint("status IN ('pending', 'processed', 'rejected')", name='check_report_status')
    )
    # 创建部分唯一索引：防止同一用户对同一目标的 pending 举报重复
    op.execute("""
        CREATE UNIQUE INDEX idx_forum_reports_unique_pending 
        ON forum_reports(target_type, target_id, reporter_id) 
        WHERE status = 'pending'
    """)
    op.execute("CREATE INDEX idx_forum_reports_status ON forum_reports(status, created_at DESC)")
    op.create_index('idx_forum_reports_target', 'forum_reports', ['target_type', 'target_id'])
    op.create_index('idx_forum_reports_reporter', 'forum_reports', ['reporter_id'])
    
    # 创建触发器：自动清理软删除帖子/回复的点赞记录
    op.execute("""
        CREATE OR REPLACE FUNCTION cleanup_post_likes()
        RETURNS TRIGGER AS $$
        BEGIN
            DELETE FROM forum_likes 
            WHERE target_type = 'post' AND target_id = OLD.id;
            RETURN OLD;
        END;
        $$ LANGUAGE plpgsql;
    """)
    
    op.execute("""
        CREATE TRIGGER trigger_cleanup_post_likes
        AFTER UPDATE ON forum_posts
        FOR EACH ROW
        WHEN (OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE)
        EXECUTE FUNCTION cleanup_post_likes();
    """)
    
    op.execute("""
        CREATE OR REPLACE FUNCTION cleanup_reply_likes()
        RETURNS TRIGGER AS $$
        BEGIN
            DELETE FROM forum_likes 
            WHERE target_type = 'reply' AND target_id = OLD.id;
            RETURN OLD;
        END;
        $$ LANGUAGE plpgsql;
    """)
    
    op.execute("""
        CREATE TRIGGER trigger_cleanup_reply_likes
        AFTER UPDATE ON forum_replies
        FOR EACH ROW
        WHEN (OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE)
        EXECUTE FUNCTION cleanup_reply_likes();
    """)

def downgrade():
    # 删除触发器
    op.execute("DROP TRIGGER IF EXISTS trigger_cleanup_reply_likes ON forum_replies")
    op.execute("DROP FUNCTION IF EXISTS cleanup_reply_likes()")
    op.execute("DROP TRIGGER IF EXISTS trigger_cleanup_post_likes ON forum_posts")
    op.execute("DROP FUNCTION IF EXISTS cleanup_post_likes()")
    
    op.drop_index('idx_forum_reports_reporter', table_name='forum_reports')
    op.drop_index('idx_forum_reports_target', table_name='forum_reports')
    op.drop_index('idx_forum_reports_status', table_name='forum_reports')
    op.drop_index('idx_forum_reports_unique_pending', table_name='forum_reports')
    op.drop_table('forum_reports')
    op.drop_index('idx_forum_notifications_target', table_name='forum_notifications')
    op.drop_index('idx_forum_notifications_user', table_name='forum_notifications')
    op.drop_table('forum_notifications')
    op.drop_index('idx_forum_favorites_post', table_name='forum_favorites')
    op.drop_index('idx_forum_favorites_user', table_name='forum_favorites')
    op.drop_table('forum_favorites')
    op.drop_index('idx_forum_likes_user', table_name='forum_likes')
    op.drop_index('idx_forum_likes_target', table_name='forum_likes')
    op.drop_table('forum_likes')
    op.drop_index('idx_forum_replies_author', table_name='forum_replies')
    op.drop_index('idx_forum_replies_parent', table_name='forum_replies')
    op.drop_index('idx_forum_replies_post', table_name='forum_replies')
    op.drop_table('forum_replies')
    op.drop_index('idx_forum_posts_search', table_name='forum_posts')
    op.drop_index('idx_forum_posts_last_reply', table_name='forum_posts')
    op.drop_index('idx_forum_posts_pinned', table_name='forum_posts')
    op.drop_index('idx_forum_posts_author', table_name='forum_posts')
    op.drop_index('idx_forum_posts_category', table_name='forum_posts')
    op.drop_table('forum_posts')
    op.drop_index('idx_forum_categories_visible', table_name='forum_categories')
    op.drop_table('forum_categories')
```

---

## 🔌 API设计

### 1. 论坛板块API

#### 获取板块列表
```
GET /api/forum/categories
```

**响应示例**:
```json
{
  "categories": [
    {
      "id": 1,
      "name": "技术交流",
      "description": "分享技术经验和问题",
      "icon": "https://example.com/icon.png",
      "post_count": 150,
      "last_post_at": "2025-01-27T10:00:00Z"
    }
  ]
}
```

#### 获取板块详情
```
GET /api/forum/categories/{category_id}
```

**响应示例**:
```json
{
  "id": 1,
  "name": "技术交流",
  "description": "分享技术经验和问题",
  "icon": "https://example.com/icon.png",
  "sort_order": 1,
  "is_visible": true,
  "post_count": 150,
  "last_post_at": "2025-01-27T10:00:00Z",
  "created_at": "2025-01-20T00:00:00Z",
  "updated_at": "2025-01-27T10:00:00Z"
}
```

#### 创建板块（管理员）
```
POST /api/forum/categories
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "name": "技术交流",
  "description": "分享技术经验和问题",
  "icon": "https://example.com/icon.png",
  "sort_order": 1
}
```

#### 更新板块（管理员）
```
PUT /api/forum/categories/{category_id}
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "name": "技术交流（更新）",
  "description": "更新后的描述",
  "icon": "https://example.com/new-icon.png",
  "sort_order": 2,
  "is_visible": true
}
```

**响应示例**:
```json
{
  "id": 1,
  "name": "技术交流（更新）",
  "description": "更新后的描述",
  "icon": "https://example.com/new-icon.png",
  "sort_order": 2,
  "is_visible": true,
  "post_count": 150,
  "last_post_at": "2025-01-27T10:00:00Z",
  "updated_at": "2025-01-27T15:00:00Z"
}
```

#### 删除板块（管理员）
```
DELETE /api/forum/categories/{category_id}
Authorization: Bearer {admin_token}
```

**响应示例**:
```json
{
  "message": "板块删除成功"
}
```

### 2. 主题帖API

#### 获取帖子列表
```
GET /api/forum/posts?category_id=1&page=1&page_size=20&sort=latest&q=关键词
```

**查询参数**:
- `category_id`: 板块ID（可选）
- `page`: 页码（默认1）
- `page_size`: 每页数量（默认20）
- `sort`: 排序方式（可选，默认 `last_reply`，详见下方排序字段映射表）
- `q`: 搜索关键词（可选，使用简单 LIKE 查询，适用于轻量搜索）

**注意**: 
- 此接口的 `q` 参数使用简单的 LIKE 查询，适用于轻量级搜索场景
- 如需全文搜索，请使用 `/api/forum/search` 接口（基于全文索引，性能更好）

**响应示例**:
```json
{
  "posts": [
    {
      "id": 1,
      "title": "如何优化数据库查询性能？",
      "content_preview": "内容预览（前200字，已去除Markdown标记）...",
      "category": {
        "id": 1,
        "name": "技术交流"
      },
      "author": {
        "id": "12345678",
        "name": "张三",
        "avatar": "https://example.com/avatar.png"
      },
      "view_count": 100,
      "reply_count": 15,
      "like_count": 25,
      "is_pinned": false,
      "is_featured": true,
      "is_locked": false,
      "created_at": "2025-01-27T10:00:00Z",
      "last_reply_at": "2025-01-27T12:00:00Z"
    }
  ],
  "total": 100,
  "page": 1,
  "page_size": 20
}
```

**注意**:
- `content_preview`: 列表接口返回的是截断后的内容预览（前200字符，已去除Markdown标记），不返回完整内容以节省流量和提升性能
- 完整内容仅在帖子详情接口中返回

#### 获取帖子详情
```
GET /api/forum/posts/{post_id}
```

**响应示例**:
```json
{
  "id": 1,
  "title": "如何优化数据库查询性能？",
  "content": "完整内容...",
  "category": {
    "id": 1,
    "name": "技术交流"
  },
  "author": {
    "id": "12345678",
    "name": "张三",
    "avatar": "https://example.com/avatar.png"
  },
  "view_count": 100,
  "reply_count": 15,
  "like_count": 25,
  "favorite_count": 10,
  "is_pinned": false,
  "is_featured": true,
  "is_locked": false,
  "is_liked": true,
  "is_favorited": false,
  "created_at": "2025-01-27T10:00:00Z",
  "updated_at": "2025-01-27T10:00:00Z",
  "last_reply_at": "2025-01-27T12:00:00Z"
}
```

**注意**:
- `is_liked`: 当前登录用户是否已点赞该帖子（未登录用户返回 `false` 或省略该字段）
- `is_favorited`: 当前登录用户是否已收藏该帖子（未登录用户返回 `false` 或省略该字段）
- 这两个字段不是数据库字段，而是后端根据当前用户动态计算填充的

#### 创建帖子
```
POST /api/forum/posts
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "如何优化数据库查询性能？",
  "content": "完整内容...",
  "category_id": 1
}
```

#### 更新帖子
```
PUT /api/forum/posts/{post_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "title": "更新后的标题",
  "content": "更新后的内容...",
  "category_id": 1
}
```

**响应示例**:
```json
{
  "id": 1,
  "title": "更新后的标题",
  "content": "更新后的内容...",
  "category": {
    "id": 1,
    "name": "技术交流"
  },
  "author": {
    "id": "12345678",
    "name": "张三",
    "avatar": "https://example.com/avatar.png"
  },
  "updated_at": "2025-01-27T15:00:00Z"
}
```

#### 删除帖子
```
DELETE /api/forum/posts/{post_id}
Authorization: Bearer {token}
```

**说明**:
- 实际实现为**软删除**：将 `is_deleted = true`，并触发点赞清理触发器
- 软删除的帖子在列表中不再显示，详情页返回 404 或"该帖子已被删除"提示
- 只有作者或管理员可以删除帖子

**响应示例**:
```json
{
  "message": "帖子删除成功"
}
```

#### 置顶帖子（管理员）
```
POST /api/forum/posts/{post_id}/pin
Authorization: Bearer {admin_token}
```

**响应示例**:
```json
{
  "id": 1,
  "is_pinned": true,
  "message": "帖子已置顶"
}
```

#### 取消置顶（管理员）
```
DELETE /api/forum/posts/{post_id}/pin
Authorization: Bearer {admin_token}
```

#### 加精帖子（管理员）
```
POST /api/forum/posts/{post_id}/feature
Authorization: Bearer {admin_token}
```

**响应示例**:
```json
{
  "id": 1,
  "is_featured": true,
  "message": "帖子已加精"
}
```

#### 取消加精（管理员）
```
DELETE /api/forum/posts/{post_id}/feature
Authorization: Bearer {admin_token}
```

#### 锁定帖子（管理员）
```
POST /api/forum/posts/{post_id}/lock
Authorization: Bearer {admin_token}
```

**响应示例**:
```json
{
  "id": 1,
  "is_locked": true,
  "message": "帖子已锁定"
}
```

#### 解锁帖子（管理员）
```
DELETE /api/forum/posts/{post_id}/lock
Authorization: Bearer {admin_token}
```

### 3. 回复API

#### 获取回复列表
```
GET /api/forum/posts/{post_id}/replies?page=1&page_size=20
```

**分页说明**:
- ⚠️ **重要**: `page` 和 `page_size` 参数**仅针对一级回复**进行分页
- 每个一级回复会附带**完整的子回复树**（最多3层嵌套）
- 例如：如果 `page_size=20`，返回20个一级回复，每个一级回复的所有子回复都会包含在内
- `total` 字段表示一级回复的总数（不包括子回复）

**响应示例**:
```json
{
  "replies": [
    {
      "id": 1,
      "content": "回复内容...",
      "author": {
        "id": "12345678",
        "name": "李四",
        "avatar": "https://example.com/avatar.png"
      },
      "parent_reply_id": null,
      "reply_level": 1,
      "like_count": 5,
      "is_liked": false,
      "created_at": "2025-01-27T11:00:00Z",
      "replies": [
        {
          "id": 2,
          "content": "嵌套回复...",
          "author": {
            "id": "87654321",
            "name": "王五",
            "avatar": "https://example.com/avatar.png"
          },
          "parent_reply_id": 1,
          "reply_level": 2,
          "like_count": 2,
          "is_liked": false,
          "created_at": "2025-01-27T11:30:00Z"
        }
      ]
    }
  ],
  "total": 15,
  "page": 1,
  "page_size": 20
}
```

#### 创建回复
```
POST /api/forum/posts/{post_id}/replies
Authorization: Bearer {token}
Content-Type: application/json

{
  "content": "回复内容...",
  "parent_reply_id": null
}
```

**业务层校验**:
- ⚠️ **必须校验回复层级**: 如果 `parent_reply_id` 不为空，必须检查父回复的 `reply_level < 3`
- 如果父回复的 `reply_level >= 3`，返回 403 错误：
  ```json
  {
    "error": "回复层级最多三层",
    "code": "REPLY_LEVEL_LIMIT"
  }
  ```
- 这样可以避免数据库约束错误，返回友好的业务提示

**实现示例**:
```python
from sqlalchemy import select
from fastapi import HTTPException

async def create_reply(post_id: int, content: str, parent_reply_id: int = None, db: AsyncSession = None):
    # 如果是指定父回复，检查层级
    if parent_reply_id:
        result = await db.execute(
            select(ForumReply).where(ForumReply.id == parent_reply_id)
        )
        parent_reply = result.scalar_one_or_none()
        if not parent_reply:
            raise HTTPException(404, "父回复不存在")
        if parent_reply.reply_level >= 3:
            raise HTTPException(
                status_code=403,
                detail="回复层级最多三层"
            )
        reply_level = parent_reply.reply_level + 1
    else:
        reply_level = 1
    
    # 创建回复
    reply = ForumReply(
        post_id=post_id,
        content=content,
        parent_reply_id=parent_reply_id,
        reply_level=reply_level,
        author_id=current_user.id
    )
    db.add(reply)
    await db.commit()
    return reply
```

#### 更新回复
```
PUT /api/forum/replies/{reply_id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "content": "更新后的回复内容..."
}
```

**响应示例**:
```json
{
  "id": 1,
  "content": "更新后的回复内容...",
  "post_id": 123,
  "author": {
    "id": "12345678",
    "name": "李四",
    "avatar": "https://example.com/avatar.png"
  },
  "updated_at": "2025-01-27T15:00:00Z"
}
```

#### 删除回复
```
DELETE /api/forum/replies/{reply_id}
Authorization: Bearer {token}
```

**说明**:
- 实际实现为**软删除**：将 `is_deleted = true`，并触发点赞清理触发器
- 软删除的回复在列表中保留一行"该回复已被删除"占位（方便理解楼层结构），但内容不展示
- 只有作者或管理员可以删除回复

**响应示例**:
```json
{
  "message": "回复删除成功"
}
```

### 4. 点赞API

#### 点赞/取消点赞
```
POST /api/forum/likes
Authorization: Bearer {token}
Content-Type: application/json

{
  "target_type": "post",
  "target_id": 1
}
```

**响应示例**:
```json
{
  "liked": true,
  "like_count": 26
}
```

#### 获取点赞列表
```
GET /api/forum/posts/{post_id}/likes?page=1&page_size=20
GET /api/forum/replies/{reply_id}/likes?page=1&page_size=20
```

**响应示例**:
```json
{
  "likes": [
    {
      "user": {
        "id": "12345678",
        "name": "张三",
        "avatar": "https://example.com/avatar.png"
      },
      "created_at": "2025-01-27T10:00:00Z"
    }
  ],
  "total": 25,
  "page": 1,
  "page_size": 20
}
```

#### 获取我赞过的内容
```
GET /api/forum/my/likes?target_type=post&page=1&page_size=20
Authorization: Bearer {token}
```

**查询参数**:
- `target_type`: 目标类型（`post` 或 `reply`，可选，不传则返回所有）
- `page`: 页码（默认1）
- `page_size`: 每页数量（默认20）

**响应示例**:
```json
{
  "likes": [
    {
      "target_type": "post",
      "post": {
        "id": 123,
        "title": "被点赞的帖子",
        "content_preview": "内容预览...",
        "category": {
          "id": 1,
          "name": "技术交流"
        },
        "author": {
          "id": "87654321",
          "name": "作者名",
          "avatar": "https://example.com/avatar.png"
        },
        "view_count": 200,
        "reply_count": 30,
        "like_count": 50,
        "created_at": "2025-01-26T10:00:00Z",
        "last_reply_at": "2025-01-27T12:00:00Z"
      },
      "created_at": "2025-01-27T10:00:00Z"
    },
    {
      "target_type": "reply",
      "reply": {
        "id": 456,
        "content": "被点赞的回复内容...",
        "post": {
          "id": 123,
          "title": "原帖子标题"
        },
        "author": {
          "id": "11111111",
          "name": "回复作者",
          "avatar": "https://example.com/avatar.png"
        },
        "like_count": 10,
        "created_at": "2025-01-27T09:00:00Z"
      },
      "created_at": "2025-01-27T11:00:00Z"
    }
  ],
  "total": 20,
  "page": 1,
  "page_size": 20
}
```

**注意**: 
- 当 `target_type` 为 `post` 时，返回 `post` 字段
- 当 `target_type` 为 `reply` 时，返回 `reply` 字段
- 当不指定 `target_type` 时，可能同时包含 `post` 和 `reply` 两种类型

### 5. 收藏API

#### 收藏/取消收藏
```
POST /api/forum/favorites
Authorization: Bearer {token}
Content-Type: application/json

{
  "post_id": 1
}
```

#### 获取收藏列表
```
GET /api/forum/favorites?page=1&page_size=20
Authorization: Bearer {token}
```

### 6. 搜索API

#### 搜索帖子（全文搜索）
```
GET /api/forum/search?q=关键词&category_id=1&sort=latest&page=1&page_size=20
```

**查询参数**:
- `q`: 搜索关键词（必填，用于全文搜索）
- `category_id`: 板块ID（可选）
- `sort`: 排序方式（可选，默认 `last_reply`，详见下方排序字段映射表）
- `page`: 页码（默认1）
- `page_size`: 每页数量（默认20）

**实现说明**:
- **当前实现**: 使用 PostgreSQL 的 `pg_trgm` 扩展进行相似度搜索
- **搜索方式**: 
  - 使用 `similarity(title, q) > 0.2` 和 `similarity(content, q) > 0.2` 进行相似度匹配
  - 同时保留 `ILIKE` 作为兜底方案，确保能匹配到结果
  - 按相似度排序（标题相似度优先，然后是内容相似度）
- **pg_trgm 优势**:
  - ✅ 对中文、英文、数字都有良好的支持
  - ✅ 支持容错搜索（拼写错误、部分匹配）
  - ✅ 使用三元组（trigram）进行相似度匹配，效果优于 simple 配置
  - ✅ 性能良好，适合中小规模数据
- **配置要求**:
  - 需要设置环境变量 `USE_PG_TRGM=true` 启用 pg_trgm
  - 需要执行迁移文件 `023_add_pg_trgm_for_forum_search.sql` 创建扩展和索引
- **降级方案**: 如果未启用 `USE_PG_TRGM`，将使用 `ILIKE` 模糊搜索
- **与 `/api/forum/posts` 的区别**:
  - `/api/forum/posts?q=...`: 使用简单 LIKE 查询，轻量级，适合简单搜索
  - `/api/forum/search?q=...`: 使用 pg_trgm 相似度搜索，性能更好，支持中文，适合复杂搜索场景

**未来扩展方案**:
- **大规模阶段**（数据量 > 100万）:
  - 可考虑引入独立搜索服务（MeiliSearch/Elasticsearch）
  - 写数据时同步推送，`/api/forum/search` 切到外部搜索引擎
  - pg_trgm 索引作为 fallback

### 6.1 排序字段映射表

**统一的排序参数与数据库字段映射关系**:

| sort 参数 | 排序字段 | 说明 |
|-----------|---------|------|
| `latest` | `created_at DESC` | 按创建时间降序（最新发布） |
| `last_reply` | `last_reply_at DESC NULLS LAST` | 按最后回复时间降序（最新回复，**默认值**） |
| `hot` | 综合评分（见下方公式） | 按热度排序 |
| `replies` | `reply_count DESC` | 按回复数降序 |
| `likes` | `like_count DESC` | 按点赞数降序 |

**热度排序公式（sort=hot）**:

热度排序使用综合评分公式，在数据库查询时实时计算：

```sql
-- 热度评分计算公式（PostgreSQL）
SELECT 
    *,
    (
        like_count * 3.0 + 
        reply_count * 2.0 + 
        view_count * 0.1 - 
        EXTRACT(EPOCH FROM (NOW() - created_at)) / 86400.0 * 0.5
    ) AS hot_score
FROM forum_posts
WHERE is_deleted = FALSE AND is_visible = TRUE
ORDER BY hot_score DESC
```

**公式说明**:
- `like_count * 3.0`: 点赞权重最高
- `reply_count * 2.0`: 回复数权重次之
- `view_count * 0.1`: 浏览数权重较低
- `时间衰减`: 每过一天热度衰减 0.5 分

**性能优化建议**:
- 对于高并发场景，可以考虑创建物化视图（Materialized View）定期刷新
- 或使用 Redis 缓存热门帖子列表，定时更新

**完整实现方案（推荐）**:

**方案一：Materialized View（物化视图）**

创建物化视图存储热度评分，定期刷新：

```sql
-- 1. 创建物化视图
CREATE MATERIALIZED VIEW forum_posts_hot_score AS
SELECT 
    id,
    category_id,
    author_id,
    title,
    content,
    is_pinned,
    is_featured,
    is_locked,
    is_deleted,
    view_count,
    reply_count,
    like_count,
    favorite_count,
    created_at,
    last_reply_at,
    -- 热度评分计算（使用改进的公式）
    (
        (like_count * 5.0 + 
         reply_count * 3.0 + 
         view_count * 0.1) / 
        POW(EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600.0 + 2.0, 1.5)
    ) AS hot_score
FROM forum_posts
WHERE is_deleted = FALSE AND is_visible = TRUE;

-- 2. 创建索引以加速排序查询
CREATE INDEX idx_forum_posts_hot_score ON forum_posts_hot_score(hot_score DESC);
CREATE INDEX idx_forum_posts_hot_category ON forum_posts_hot_score(category_id, hot_score DESC);

-- 3. 创建刷新函数（可被 Celery 定时任务调用）
CREATE OR REPLACE FUNCTION refresh_forum_posts_hot_score()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY forum_posts_hot_score;
END;
$$ LANGUAGE plpgsql;

-- 4. 使用物化视图查询（性能最优）
SELECT * FROM forum_posts_hot_score
WHERE category_id = 1  -- 可选：按板块筛选
ORDER BY hot_score DESC
LIMIT 20;
```

**刷新策略**:
- 使用 Celery 定时任务，每 5-10 分钟刷新一次物化视图
- 使用 `REFRESH MATERIALIZED VIEW CONCURRENTLY` 避免锁表
- 在帖子被点赞/回复/浏览后，可以触发增量更新（可选）

**方案二：实时计算（适合中小规模）**

如果数据量不大（< 10万帖子），可以直接在查询时计算：

```sql
-- 实时计算热度评分（适合中小规模）
SELECT 
    *,
    (
        (like_count * 5.0 + 
         reply_count * 3.0 + 
         view_count * 0.1) / 
        POW(EXTRACT(EPOCH FROM (NOW() - created_at)) / 3600.0 + 2.0, 1.5)
    ) AS hot_score
FROM forum_posts
WHERE is_deleted = FALSE AND is_visible = TRUE
ORDER BY hot_score DESC
LIMIT 20;
```

**方案三：Redis 缓存（推荐配合方案一）**

将热门帖子列表缓存到 Redis，减少数据库查询：

```python
# 伪代码示例
def get_hot_posts(category_id=None, limit=20):
    cache_key = f"forum:hot_posts:{category_id or 'all'}"
    cached = redis.get(cache_key)
    if cached:
        return json.loads(cached)
    
    # 从物化视图查询
    posts = db.execute(
        select(ForumPostHotScore)
        .where(ForumPostHotScore.category_id == category_id if category_id else True)
        .order_by(ForumPostHotScore.hot_score.desc())
        .limit(limit)
    ).scalars().all()
    
    # 缓存 5 分钟
    redis.setex(cache_key, 300, json.dumps([post.to_dict() for post in posts]))
    return posts
```

**公式说明**:
- `like_count * 5.0`: 点赞权重最高（5倍）
- `reply_count * 3.0`: 回复数权重次之（3倍）
- `view_count * 0.1`: 浏览数权重较低（0.1倍）
- `时间衰减`: 使用 `POW((小时数 + 2), 1.5)` 进行时间衰减，新帖子有初始优势，老帖子逐渐衰减

**注意**: 所有排序都只统计 `is_deleted = FALSE AND is_visible = TRUE` 的帖子

### 7. 通知API

#### 获取通知列表
```
GET /api/forum/notifications?page=1&page_size=20&unread_only=false
Authorization: Bearer {token}
```

**查询参数**:
- `page`: 页码（默认1）
- `page_size`: 每页数量（默认20）
- `unread_only`: 是否只获取未读通知（默认false）

**响应示例**:
```json
{
  "notifications": [
    {
      "id": 1,
      "notification_type": "reply_post",
      "target_type": "post",
      "target_id": 1,
      "from_user": {
        "id": "12345678",
        "name": "李四",
        "avatar": "https://example.com/avatar.png"
      },
      "is_read": false,
      "created_at": "2025-01-27T11:00:00Z"
    }
  ],
  "total": 10,
  "unread_count": 5,
  "page": 1,
  "page_size": 20
}
```

**字段说明**:
- `unread_count`: **该用户所有未读通知的总数**（不是当前页的未读数），用于前端显示红点提示
- `from_user`: 可能为 `null`（例如系统通知、发送者账号被删除等情况），前端需要做空值处理

#### 标记通知为已读
```
PUT /api/forum/notifications/{notification_id}/read
Authorization: Bearer {token}
```

#### 标记所有通知为已读
```
PUT /api/forum/notifications/read-all
Authorization: Bearer {token}
```

### 8. 举报API

#### 举报帖子/回复
```
POST /api/forum/reports
Authorization: Bearer {token}
Content-Type: application/json

{
  "target_type": "post",
  "target_id": 1,
  "reason": "spam",
  "description": "这是垃圾内容"
}
```

**举报原因（reason）**:
- `spam`: 垃圾信息
- `abuse`: 辱骂/人身攻击
- `inappropriate`: 不当内容
- `copyright`: 版权问题
- `other`: 其他

#### 获取举报列表（管理员）
```
GET /api/forum/reports?status=pending&page=1&page_size=20
Authorization: Bearer {admin_token}
```

#### 处理举报（管理员）
```
PUT /api/forum/reports/{report_id}/process
Authorization: Bearer {admin_token}
Content-Type: application/json

{
  "status": "processed",
  "action": "delete_post"
}
```

**请求参数**:
- `status`: 处理状态（`processed` 或 `rejected`）
- `action`: 处理动作（可选）
  - `delete_post`: 删除帖子
  - `delete_reply`: 删除回复
  - `warn_user`: 警告用户
  - `no_action`: 无操作
  - 其他自定义动作

**注意**:
- `action` 字段会保存到数据库的 `forum_reports.action` 字段，用于审计追溯
- 处理完成后，`processor_id`、`processed_at` 会自动更新

### 9. 我的内容API

#### 获取我的帖子
```
GET /api/forum/my/posts?page=1&page_size=20
Authorization: Bearer {token}
```

**响应示例**:
```json
{
  "posts": [
    {
      "id": 1,
      "title": "我的帖子标题",
      "content_preview": "内容预览...",
      "category": {
        "id": 1,
        "name": "技术交流"
      },
      "view_count": 100,
      "reply_count": 15,
      "like_count": 25,
      "created_at": "2025-01-27T10:00:00Z",
      "last_reply_at": "2025-01-27T12:00:00Z"
    }
  ],
  "total": 20,
  "page": 1,
  "page_size": 20
}
```

#### 获取我的回复
```
GET /api/forum/my/replies?page=1&page_size=20
Authorization: Bearer {token}
```

**响应示例**:
```json
{
  "replies": [
    {
      "id": 1,
      "content": "我的回复内容...",
      "post": {
        "id": 123,
        "title": "原帖子标题",
        "category": {
          "id": 1,
          "name": "技术交流"
        }
      },
      "parent_reply_id": null,
      "reply_level": 1,
      "like_count": 5,
      "created_at": "2025-01-27T11:00:00Z"
    }
  ],
  "total": 15,
  "page": 1,
  "page_size": 20
}
```

#### 获取我的收藏
```
GET /api/forum/favorites?page=1&page_size=20
Authorization: Bearer {token}
```

**响应示例**:
```json
{
  "favorites": [
    {
      "id": 1,
      "post": {
        "id": 123,
        "title": "收藏的帖子标题",
        "content_preview": "内容预览...",
        "category": {
          "id": 1,
          "name": "技术交流"
        },
        "author": {
          "id": "87654321",
          "name": "作者名",
          "avatar": "https://example.com/avatar.png"
        },
        "view_count": 200,
        "reply_count": 30,
        "like_count": 50,
        "created_at": "2025-01-26T10:00:00Z",
        "last_reply_at": "2025-01-27T12:00:00Z"
      },
      "created_at": "2025-01-27T09:00:00Z"
    }
  ],
  "total": 10,
  "page": 1,
  "page_size": 20
}
```

---

## 🎨 前端设计

### 1. 页面结构

```
/forum
  ├── /forum                    # 论坛首页（板块列表）
  ├── /forum/category/:id       # 板块详情页（帖子列表）
  ├── /forum/post/:id           # 帖子详情页
  ├── /forum/post/new           # 发布新帖
  ├── /forum/post/:id/edit      # 编辑帖子
  ├── /forum/search              # 搜索结果页
  ├── /forum/notifications       # 通知列表页
  └── /forum/my                  # 我的帖子/回复/收藏
```

### 2. 组件设计

#### ForumHomePage（论坛首页）
- 板块列表展示
- 热门帖子推荐
- 最新帖子列表

#### CategoryPage（板块页）
- 板块信息
- 帖子列表（支持筛选和排序）
- 发布新帖按钮

#### PostDetailPage（帖子详情页）
- 帖子内容展示
- 回复列表（支持嵌套显示）
- 回复输入框
- 点赞/收藏按钮
- 编辑/删除按钮（仅作者可见）

#### PostEditor（帖子编辑器）
- 标题输入
- 内容编辑器（支持Markdown）
- 板块选择
- 发布/保存按钮

#### ReplyList（回复列表）
- 回复项组件
- 嵌套回复展示
- 分页加载

#### ReplyEditor（回复编辑器）
- 回复输入框
- 支持引用回复
- 提交按钮

#### ForumSearchPage（搜索结果页）
- 搜索输入框
- 搜索结果列表
- 筛选和排序选项

#### NotificationListPage（通知列表页）
- 通知列表展示
- 未读/已读筛选
- 标记已读功能

### 3. 状态管理

使用 React Query 管理数据：
- 帖子列表缓存
- 帖子详情缓存
- 回复列表缓存
- 点赞/收藏状态

### 4. UI/UX 设计要点

- **响应式设计**: 支持移动端和桌面端
- **加载状态**: 显示加载动画
- **错误处理**: 友好的错误提示
- **分页加载**: 支持无限滚动或分页
- **实时更新**: 新回复实时显示
- **Markdown渲染**: 支持Markdown格式内容
  - **安全渲染**: 必须使用安全模式，对HTML标签做白名单过滤，防止XSS攻击
  - 推荐使用 `DOMPurify` 或类似库进行内容清理

### 4.1 帖子状态矩阵表（前端参考）

**用户角色 × 帖子状态 × 可见性规则**:

| 用户角色 | 帖子状态 | 列表中显示 | 详情页可见 | 可回复 | 可编辑 | 可删除 |
|---------|---------|-----------|-----------|--------|--------|--------|
| 普通用户 | 正常（`is_deleted=FALSE, is_visible=TRUE, is_locked=FALSE`） | ✅ | ✅ | ✅ | ❌ | ❌ |
| 普通用户 | 已锁定（`is_locked=TRUE`） | ✅ | ✅ | ❌ | ❌ | ❌ |
| 普通用户 | 已隐藏（`is_visible=FALSE`） | ❌ | ❌ | ❌ | ❌ | ❌ |
| 普通用户 | 已删除（`is_deleted=TRUE`） | ❌ | ❌（404） | ❌ | ❌ | ❌ |
| 帖子作者 | 正常 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 帖子作者 | 已锁定 | ✅ | ✅ | ❌ | ✅ | ✅ |
| 帖子作者 | 已隐藏 | ✅ | ✅（显示"仅自己可见"） | ❌ | ✅ | ✅ |
| 帖子作者 | 已删除 | ❌ | ❌（404） | ❌ | ❌ | ❌ |
| 管理员 | 正常 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 管理员 | 已锁定 | ✅ | ✅ | ❌ | ✅ | ✅ |
| 管理员 | 已隐藏 | ✅ | ✅（显示"已隐藏"标记） | ❌ | ✅ | ✅ |
| 管理员 | 已删除 | ❌ | ✅（显示"已删除"标记） | ❌ | ✅ | ✅ |

**说明**:
- **列表中显示**: 是否在帖子列表中出现
- **详情页可见**: 是否可以访问帖子详情页（普通用户访问隐藏/删除内容返回 404）
- **可回复**: 是否可以创建新回复（锁定后禁止）
- **可编辑**: 是否可以编辑帖子内容（只有作者和管理员）
- **可删除**: 是否可以删除帖子（只有作者和管理员）

### 5. 嵌套回复实现

**实现方式**:
- API返回时，后端一次性查询所有回复，在代码中组装成树形结构
- 避免在后端做大量递归查询，使用单次查询 + 内存组装的方式
- 前端接收到嵌套好的 `replies: []` 数组，直接渲染即可

**示例数据结构**:
```json
{
  "replies": [
    {
      "id": 1,
      "content": "一级回复",
      "replies": [
        {
          "id": 2,
          "content": "二级回复",
          "replies": [
            {
              "id": 3,
              "content": "三级回复",
              "replies": []  // 最多3层
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 🛠️ 开发步骤

### 阶段一：数据库和模型（1-2天）

1. **创建数据库迁移文件**
   - 创建所有论坛相关表
   - 添加索引和约束
   - 测试迁移脚本

2. **创建SQLAlchemy模型**
   - `ForumCategory` 模型
   - `ForumPost` 模型
   - `ForumReply` 模型
   - `ForumLike` 模型
   - `ForumFavorite` 模型
   - `ForumNotification` 模型
   - `ForumReport` 模型

3. **创建Pydantic Schemas**
   - 请求schemas
   - 响应schemas
   - 验证规则

### 阶段二：后端API开发（3-4天）

1. **创建路由文件**
   - `backend/app/forum_routes.py`

2. **实现CRUD操作**
   - 板块CRUD
   - 帖子CRUD
   - 回复CRUD
   - 点赞/收藏操作

3. **实现业务逻辑**
   - 帖子统计更新（回复数、点赞数等）
   - 搜索功能
   - 权限检查
   - 软删除逻辑

4. **集成到主应用**
   - 在 `main.py` 中注册路由
   - 添加权限依赖

### 阶段三：前端开发（4-5天）

1. **创建页面组件**
   - 论坛首页
   - 板块页
   - 帖子详情页
   - 帖子编辑页

2. **创建通用组件**
   - 帖子卡片
   - 回复项
   - 编辑器
   - 点赞/收藏按钮

3. **实现API调用**
   - 创建API服务文件
   - 使用React Query管理数据

4. **实现路由**
   - 配置React Router
   - 添加导航链接

### 阶段四：功能完善（2-3天）

1. **搜索功能**
   - 全文搜索
   - 筛选和排序

2. **通知功能**
   - 回复通知
   - 点赞通知（通过配置开关控制是否启用）

3. **管理功能**
   - 帖子置顶/加精/锁定
   - 板块管理

### 阶段五：测试和优化（2-3天）

1. **单元测试**
   - API测试
   - 业务逻辑测试

2. **集成测试**
   - 端到端测试
   - 性能测试

3. **优化**
   - 数据库查询优化
   - 缓存策略
   - 前端性能优化

---

## 🧪 测试计划

### 1. 单元测试

#### 后端测试
- 模型验证测试
- API端点测试
- 业务逻辑测试
- 权限检查测试

#### 前端测试
- 组件渲染测试
- 用户交互测试
- API调用测试

### 2. 集成测试

- 完整的用户流程测试
- 并发操作测试
- 错误处理测试

### 3. 性能测试

- 大量数据加载测试
- 搜索性能测试
- 并发请求测试

### 4. 安全测试

- SQL注入测试
- XSS攻击测试
- CSRF保护测试
- 权限绕过测试

---

## 🚀 部署说明

### 1. 数据库迁移

```bash
# 在Railway或本地环境运行迁移
cd backend
alembic upgrade head
```

**启用 pg_trgm 搜索**（推荐）:
```bash
# 执行 pg_trgm 扩展迁移
psql $DATABASE_URL -f migrations/023_add_pg_trgm_for_forum_search.sql

# 或者如果使用自动迁移，确保迁移文件已执行
# 迁移文件会自动创建 pg_trgm 扩展和索引
```

**验证 pg_trgm 扩展**:
```sql
-- 检查扩展是否已安装
SELECT * FROM pg_extension WHERE extname = 'pg_trgm';

-- 检查索引是否已创建
SELECT indexname FROM pg_indexes 
WHERE tablename = 'forum_posts' 
AND indexname LIKE '%trgm%';
```

### 2. 环境变量

**必需的环境变量**:
- `REDIS_URL`: Redis 连接地址（用于缓存、计数和 Celery 消息队列/结果存储）

**可选的环境变量**:
- `USE_PG_TRGM`: 是否启用 pg_trgm 扩展进行相似度搜索（默认 `false`，建议设置为 `true`）
  - 设置为 `true` 时，搜索API将使用 pg_trgm 相似度搜索，对中文支持更好
  - 设置为 `false` 时，将使用 `ILIKE` 模糊搜索作为降级方案

**说明**:
- Redis 用于缓存板块列表、热门帖子、帖子详情等，以及浏览数计数
- Celery 使用 `REDIS_URL` 作为 broker 和 backend（项目已有 Celery 配置，无需额外环境变量）
- Celery 用于异步任务处理，如浏览数批量落库、通知发送等
- **pg_trgm 扩展**: 如果启用 `USE_PG_TRGM=true`，需要执行迁移文件 `023_add_pg_trgm_for_forum_search.sql` 创建扩展和索引

### 3. 初始化数据

创建初始板块数据（可选）：

```python
# backend/scripts/init_forum_categories.py
from app.database import get_async_db
from app.models import ForumCategory

async def init_categories():
    async for db in get_async_db():
        categories = [
            ForumCategory(name="技术交流", description="分享技术经验和问题", sort_order=1),
            ForumCategory(name="生活分享", description="分享生活点滴", sort_order=2),
            ForumCategory(name="问答求助", description="有问题？来这里求助", sort_order=3),
        ]
        db.add_all(categories)
        await db.commit()
```

### 4. 部署检查清单

- [ ] 数据库迁移成功
- [ ] API端点正常响应
- [ ] 前端页面正常显示
- [ ] 搜索功能正常
- [ ] 权限检查正常
- [ ] 性能测试通过

---

## ⚡ 性能优化

### 1. 数据库优化

- **索引优化**: 为常用查询字段添加索引
- **分页查询**: 使用LIMIT和OFFSET进行分页（详见下方分页策略说明）
- **全文搜索**: 使用PostgreSQL的全文搜索功能
- **统计字段**: 使用冗余字段存储统计数据，避免实时计算

**分页策略推荐使用场景**:
- **列表页（用户按时间/板块浏览）**: 数据量大时推荐使用 **Keyset Pagination（游标分页）**
- **搜索结果**: 为兼容跳转到任意页，可以暂时保留 **LIMIT/OFFSET**
- **"我的帖子/回复/收藏"**: 一般数据量不会特别大，用 **OFFSET** 足够

### 2. 缓存策略

- **板块列表缓存**: Redis缓存板块列表（TTL: 1小时）
- **热门帖子缓存**: Redis缓存热门帖子（TTL: 30分钟）
- **帖子详情缓存**: Redis缓存帖子详情（TTL: 10分钟）

### 2.1 计数字段的写入热点优化

**问题**: `view_count`、`reply_count`、`like_count`、`favorite_count` 等计数字段在高并发下容易形成"热点行"。

**解决方案**:

1. **浏览数（view_count）**:
   - 在 Redis 中累加浏览数，使用 `INCR` 命令
   - 定时批量落库（例如每5分钟或每100次浏览）
   - 使用 Celery 异步任务定期同步到数据库

2. **点赞数/收藏数（like_count/favorite_count）**:
   - 使用 Redis 计数器累加，使用 `INCR` 命令
   - 定时批量落库（例如每5分钟或每100次操作）
   - 使用 Celery 异步任务定期同步到数据库
   - 配合乐观锁策略，避免并发冲突

3. **回复数（reply_count）**:
   - 在创建/删除回复时直接更新（因为频率相对较低）
   - 使用数据库事务确保一致性
   - 定期校验和修复（防止数据不一致）

### 3. 前端优化

- **虚拟滚动**: 长列表使用虚拟滚动
- **懒加载**: 图片和内容懒加载
- **代码分割**: 路由级别的代码分割
- **防抖节流**: 搜索和滚动事件使用防抖节流

### 4. 查询优化

- **N+1查询问题**: 使用JOIN或批量查询避免N+1问题
- **只查询必要字段**: 列表查询不包含完整内容（返回 `content_preview` 而非完整 `content`）
- **使用预加载**: SQLAlchemy的joinedload或selectinload
- **嵌套回复优化**: 一次性查询所有回复，在代码中组装树形结构，避免递归查询

### 5. 点赞记录的级联删除

详见「重要实现注意事项 - 5. 点赞记录的级联删除」章节。

**清理任务**:
- 定期运行清理任务，删除无效的点赞记录（使用 Celery 定时任务，每天执行一次）

---

## 🔒 安全考虑

### 1. 输入验证

- **内容过滤**: 过滤XSS攻击代码
- **长度限制**: 标题和内容长度限制
- **Markdown安全**: 安全渲染Markdown内容
  - **必须使用安全模式**: 对HTML标签做白名单过滤
  - 推荐使用 `DOMPurify` 或 `bleach` 等库进行内容清理
  - 禁止执行JavaScript代码
  - 只允许安全的HTML标签和属性（如 `<p>`, `<strong>`, `<em>`, `<code>`, `<pre>` 等）

### 2. 权限控制

- **创建权限**: 只有登录用户可以创建帖子
- **编辑权限**: 只有作者可以编辑自己的帖子
- **删除权限**: 只有作者或管理员可以删除帖子
- **管理权限**: 只有管理员可以置顶/加精/锁定帖子

**实现建议**:
- 后端统一使用已有的认证中间件（比如 FastAPI `Depends`），在论坛路由上挂一个 `get_current_user` 依赖
- 权限检查在路由层统一处理，避免在业务逻辑中重复检查

### 3. 速率限制

- **发帖限制**: 限制用户发帖频率（防止刷屏）
- **回复限制**: 限制用户回复频率
- **搜索限制**: 限制搜索请求频率

**实现建议**:
- **网关层限流**: 可以在网关（Nginx / API Gateway）层做 IP 级限流
- **业务级限流**: 业务级限流（比如"单用户每分钟最多发帖 2 条"）用 Redis + Lua 实现
- **Redis Key 规范**: `forum:rate:user:{user_id}:create_post`、`forum:rate:user:{user_id}:create_reply` 等

### 4. 内容审核

- **敏感词过滤**: 自动过滤敏感词
- **举报功能**: 用户可以举报不当内容
- **管理员审核**: 管理员可以审核和删除内容

---

## 📝 后续扩展功能

### 1. 高级功能

- **标签系统**: 帖子支持标签分类
- **附件上传**: 支持图片和文件上传
- **@提及功能**: 回复时可以@其他用户
- **私信功能**: 用户之间可以私信

### 2. 社区功能

- **用户等级**: 根据发帖和回复数设置用户等级
- **徽章系统**: 用户可以获得各种徽章
- **积分系统**: 发帖和回复可以获得积分

### 3. 管理功能

- **内容审核**: 管理员审核新帖子
- **用户管理**: 禁言、封禁用户
- **数据统计**: 论坛数据统计和分析
- **风控策略**: 自动处理多次举报的内容（详见下方详细设计）
- **操作日志**: 管理员操作审计日志（详见下方详细设计）

### 4. 实时通信

- **WebSocket 实时推送**: 新回复、新通知实时推送给用户
- **Server-Sent Events (SSE)**: 单向实时推送方案
- **消息队列**: 使用 Celery + Redis 处理异步通知任务

### 5. 分页优化

- **Keyset Pagination**: 大数据量场景下的游标分页方案
- **虚拟滚动**: 前端虚拟滚动优化长列表性能

### 6. 风控策略：自动处理多次举报内容

**功能说明**: 当帖子或回复被举报达到一定阈值时，系统自动执行预设的风控动作（隐藏、锁定、删除等），无需管理员手动处理。

**数据库设计**:

```sql
-- 风控规则配置表
CREATE TABLE forum_risk_control_rules (
    id SERIAL PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    trigger_count INTEGER NOT NULL DEFAULT 3,  -- 触发阈值（举报次数）
    trigger_time_window INTEGER NOT NULL DEFAULT 24,  -- 时间窗口（小时）
    action_type VARCHAR(20) NOT NULL CHECK (action_type IN ('hide', 'lock', 'soft_delete', 'notify_admin')),
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 风控执行记录表
CREATE TABLE forum_risk_control_logs (
    id SERIAL PRIMARY KEY,
    target_type VARCHAR(10) NOT NULL CHECK (target_type IN ('post', 'reply')),
    target_id INTEGER NOT NULL,
    rule_id INTEGER REFERENCES forum_risk_control_rules(id),
    trigger_count INTEGER NOT NULL,  -- 触发时的举报数
    action_type VARCHAR(20) NOT NULL,
    action_result VARCHAR(50),  -- 执行结果（success/failed/reverted）
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    executed_by VARCHAR(8) REFERENCES users(id),  -- NULL 表示系统自动执行
    reverted_at TIMESTAMP WITH TIME ZONE,  -- 如果被管理员撤销
    reverted_by VARCHAR(8) REFERENCES users(id)
);

-- 索引
CREATE INDEX idx_risk_control_logs_target ON forum_risk_control_logs(target_type, target_id);
CREATE INDEX idx_risk_control_logs_executed ON forum_risk_control_logs(executed_at DESC);
```

**业务逻辑**:

1. **触发条件检查**:
   - 当有新的举报被创建时，检查该目标（帖子/回复）在时间窗口内的举报总数
   - 如果达到规则阈值，触发风控动作

2. **风控动作类型**:
   - `hide`: 自动设置 `is_visible = FALSE`，内容对普通用户不可见
   - `lock`: 自动设置 `is_locked = TRUE`，禁止新回复
   - `soft_delete`: 自动软删除内容
   - `notify_admin`: 仅通知管理员，不自动处理

3. **实现示例**:

```python
# 伪代码：检查并执行风控
async def check_and_trigger_risk_control(target_type: str, target_id: int, db: AsyncSession):
    # 1. 获取该目标在时间窗口内的举报数
    # 注意：使用 rule.trigger_time_window 而不是硬编码 24 小时
    # 先查找匹配的规则以获取时间窗口配置
    rule = await db.execute(
        select(ForumRiskControlRule)
        .where(
            ForumRiskControlRule.target_type == target_type,
            ForumRiskControlRule.is_enabled == True
        )
        .order_by(ForumRiskControlRule.trigger_count.desc())
        .limit(1)
    ).scalar_one_or_none()
    
    if not rule:
        return
    
    # 使用规则中配置的时间窗口（小时）
    time_window = timedelta(hours=rule.trigger_time_window)
    cutoff_time = datetime.now(timezone.utc) - time_window
    
    report_count = await db.execute(
        select(func.count(ForumReport.id))
        .where(
            ForumReport.target_type == target_type,
            ForumReport.target_id == target_id,
            ForumReport.status == 'pending',
            ForumReport.created_at >= cutoff_time
        )
    ).scalar()
    
    # 2. 检查是否达到规则阈值
    if report_count < rule.trigger_count:
        return  # 未达到触发阈值
    
    # 3. 执行风控动作
    if rule.action_type == 'hide':
        if target_type == 'post':
            await db.execute(
                update(ForumPost)
                .where(ForumPost.id == target_id)
                .values(is_visible=False)
            )
        else:
            await db.execute(
                update(ForumReply)
                .where(ForumReply.id == target_id)
                .values(is_visible=False)
            )
    
    elif rule.action_type == 'lock':
        await db.execute(
            update(ForumPost)
            .where(ForumPost.id == target_id)
            .values(is_locked=True)
        )
    
    elif rule.action_type == 'soft_delete':
        if target_type == 'post':
            await db.execute(
                update(ForumPost)
                .where(ForumPost.id == target_id)
                .values(is_deleted=True)
            )
        else:
            await db.execute(
                update(ForumReply)
                .where(ForumReply.id == target_id)
                .values(is_deleted=True)
            )
    
    # 4. 记录执行日志
    log = ForumRiskControlLog(
        target_type=target_type,
        target_id=target_id,
        rule_id=rule.id,
        trigger_count=report_count,
        action_type=rule.action_type,
        action_result='success',
        executed_by=None  # 系统自动执行
    )
    db.add(log)
    await db.commit()
```

**默认规则配置**:

```sql
-- 插入默认风控规则
INSERT INTO forum_risk_control_rules (rule_name, target_type, trigger_count, trigger_time_window, action_type) VALUES
('帖子被举报3次自动隐藏', 'post', 3, 24, 'hide'),
('帖子被举报5次自动锁定', 'post', 5, 24, 'lock'),
('回复被举报3次自动隐藏', 'reply', 3, 24, 'hide'),
('回复被举报5次自动删除', 'reply', 5, 24, 'soft_delete');
```

### 7. 管理员操作日志表

**功能说明**: 记录所有管理员操作（置顶、加精、锁定、删除、封禁等），用于审计和合规要求。

**数据库设计**:

```sql
-- 管理员操作日志表
CREATE TABLE forum_admin_operation_logs (
    id SERIAL PRIMARY KEY,
    operator_id VARCHAR(8) NOT NULL REFERENCES users(id),  -- 操作者（管理员）
    operation_type VARCHAR(50) NOT NULL,  -- 操作类型：pin_post, unpin_post, feature_post, unfeature_post, lock_post, unlock_post, delete_post, delete_reply, ban_user, unban_user 等
    target_type VARCHAR(20) NOT NULL,  -- 目标类型：post, reply, user, category 等
    target_id INTEGER NOT NULL,  -- 目标ID
    target_title VARCHAR(500),  -- 目标标题（冗余字段，便于查询）
    action VARCHAR(50) NOT NULL,  -- 具体动作：pin, unpin, feature, delete, ban 等
    reason TEXT,  -- 操作原因
    ip_address VARCHAR(45),  -- 操作者IP地址
    user_agent TEXT,  -- 操作者User-Agent
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE INDEX idx_admin_logs_operator ON forum_admin_operation_logs(operator_id, created_at DESC);
CREATE INDEX idx_admin_logs_target ON forum_admin_operation_logs(target_type, target_id);
CREATE INDEX idx_admin_logs_operation ON forum_admin_operation_logs(operation_type, created_at DESC);
CREATE INDEX idx_admin_logs_created ON forum_admin_operation_logs(created_at DESC);
```

**操作类型枚举**:

| 操作类型 | 目标类型 | 说明 |
|---------|---------|------|
| `pin_post` | `post` | 置顶帖子 |
| `unpin_post` | `post` | 取消置顶 |
| `feature_post` | `post` | 加精帖子 |
| `unfeature_post` | `post` | 取消加精 |
| `lock_post` | `post` | 锁定帖子 |
| `unlock_post` | `post` | 解锁帖子 |
| `delete_post` | `post` | 删除帖子（软删除） |
| `restore_post` | `post` | 恢复帖子 |
| `delete_reply` | `reply` | 删除回复（软删除） |
| `restore_reply` | `reply` | 恢复回复 |
| `ban_user` | `user` | 封禁用户 |
| `unban_user` | `user` | 解封用户 |
| `process_report` | `report` | 处理举报 |
| `create_category` | `category` | 创建板块 |
| `update_category` | `category` | 更新板块 |
| `delete_category` | `category` | 删除板块 |

**实现示例**:

```python
# 伪代码：记录管理员操作日志
async def log_admin_operation(
    operator_id: str,  # 注意：users.id 是 VARCHAR(8)，不是 INTEGER
    operation_type: str,
    target_type: str,
    target_id: int,
    action: str,
    reason: str = None,
    request: Request = None,
    db: AsyncSession = None
):
    # 获取目标标题（用于日志查询）
    target_title = None
    if target_type == 'post':
        post = await db.execute(
            select(ForumPost).where(ForumPost.id == target_id)
        ).scalar_one_or_none()
        target_title = post.title if post else None
    elif target_type == 'reply':
        reply = await db.execute(
            select(ForumReply).where(ForumReply.id == target_id)
        ).scalar_one_or_none()
        target_title = reply.content[:100] if reply else None  # 截取前100字符
    
    # 获取IP和User-Agent
    ip_address = request.client.host if request else None
    user_agent = request.headers.get('user-agent') if request else None
    
    # 创建日志记录
    log = ForumAdminOperationLog(
        operator_id=operator_id,
        operation_type=operation_type,
        target_type=target_type,
        target_id=target_id,
        target_title=target_title,
        action=action,
        reason=reason,
        ip_address=ip_address,
        user_agent=user_agent
    )
    db.add(log)
    await db.commit()

# 使用示例：置顶帖子
async def pin_post(post_id: int, operator_id: str, reason: str, request: Request, db: AsyncSession):  # 注意：operator_id 是 VARCHAR(8)
    # 执行置顶操作
    await db.execute(
        update(ForumPost)
        .where(ForumPost.id == post_id)
        .values(is_pinned=True)
    )
    
    # 记录操作日志
    await log_admin_operation(
        operator_id=operator_id,
        operation_type='pin_post',
        target_type='post',
        target_id=post_id,
        action='pin',
        reason=reason,
        request=request,
        db=db
    )
    
    await db.commit()
```

**查询示例**:

```sql
-- 查询某个管理员的所有操作（注意：operator_id 是 VARCHAR(8)）
SELECT * FROM forum_admin_operation_logs
WHERE operator_id = '12345678'  -- 示例：用户 ID 是字符串格式
ORDER BY created_at DESC
LIMIT 50;

-- 查询某个帖子的所有管理操作历史
SELECT * FROM forum_admin_operation_logs
WHERE target_type = 'post' AND target_id = 123
ORDER BY created_at DESC;

-- 查询最近一周的删除操作
SELECT * FROM forum_admin_operation_logs
WHERE operation_type IN ('delete_post', 'delete_reply')
  AND created_at >= NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

## 📚 参考资源

- [FastAPI文档](https://fastapi.tiangolo.com/)
- [SQLAlchemy文档](https://docs.sqlalchemy.org/)
- [React Query文档](https://tanstack.com/query/latest)
- [PostgreSQL全文搜索](https://www.postgresql.org/docs/current/textsearch.html)

---

## 📞 技术支持

如有问题，请：
1. 查看本文档
2. 检查代码注释
3. 查看相关日志
4. 联系开发团队

---

---

## 📌 重要实现注意事项

### 1. 数据库约束一致性

- ✅ 所有字段的默认值和 NOT NULL 约束已在 Alembic 迁移中正确设置
- ✅ 使用 `server_default` 确保数据库层面的默认值
- ✅ 计数字段（`view_count`、`reply_count` 等）都有默认值 0
- ✅ 索引排序方向已与常用 ORDER BY 场景对齐

### 2. 统计字段更新策略

**重要约定**: 
- 所有统计字段**只统计 `is_deleted = FALSE AND is_visible = TRUE` 的数据**
- 软删除的数据（`is_deleted = TRUE`）不参与统计
- 隐藏的数据（`is_visible = FALSE`）不参与公开统计
- **统计字段代表"公开可见的数量"**，用于展示给普通用户

#### 2.1 板块统计字段更新

**`forum_categories.post_count`**:
- ✅ 创建帖子时：`category.post_count += 1`（仅当 `is_deleted = FALSE AND is_visible = TRUE`）
- ✅ 删除帖子时（硬删除或软删除）：`category.post_count -= 1`（仅当原 `is_deleted = FALSE AND is_visible = TRUE` 时）
- ✅ 恢复软删除帖子时：`category.post_count += 1`（仅当恢复后 `is_deleted = FALSE AND is_visible = TRUE`）
- ✅ 隐藏帖子时：`category.post_count -= 1`（仅当原 `is_visible = TRUE` 时）
- ✅ 取消隐藏帖子时：`category.post_count += 1`（仅当 `is_deleted = FALSE` 且原 `is_visible = FALSE` 时）

**`forum_categories.last_post_at`**:
- ✅ 创建新帖子时：更新为当前时间
- ✅ 删除帖子时：如果删除的是最后一条帖子，需要重新查询该板块的最新帖子时间

#### 2.2 帖子统计字段更新

**`forum_posts.reply_count`**:
- ✅ 创建回复时：`post.reply_count += 1`（仅当回复 `is_deleted = FALSE AND is_visible = TRUE`）
- ✅ 删除回复时（硬删除或软删除）：`post.reply_count -= 1`（仅当原 `is_deleted = FALSE AND is_visible = TRUE` 时）
- ✅ 恢复软删除回复时：`post.reply_count += 1`（仅当恢复后 `is_deleted = FALSE AND is_visible = TRUE`）
- ✅ 隐藏回复时：`post.reply_count -= 1`（仅当原 `is_visible = TRUE` 时）
- ✅ 取消隐藏回复时：`post.reply_count += 1`（仅当 `is_deleted = FALSE` 且原 `is_visible = FALSE` 时）

**`forum_posts.last_reply_at`**:
- ✅ 创建新回复时：更新为当前时间
- ✅ 删除回复时：如果删除的是最后一条回复，需要重新查询该帖子的最新回复时间

**`forum_posts.like_count` / `favorite_count`**:
- ✅ 点赞/收藏时：`post.like_count += 1`
- ✅ 取消点赞/收藏时：`post.like_count -= 1`
- ⚠️ 删除帖子时：级联删除所有点赞/收藏记录，计数自动归零

**`forum_posts.view_count`**:
- ✅ 使用 Redis 累加，定时批量落库（详见性能优化章节）

#### 2.3 回复统计字段更新

**`forum_replies.like_count`**:
- ✅ 点赞回复时：`reply.like_count += 1`
- ✅ 取消点赞时：`reply.like_count -= 1`
- ⚠️ 删除回复时：级联删除所有点赞记录，计数自动归零

### 3. 软删除和风控隐藏的业务语义

**统一约定**:
- ✅ **所有对外查询默认 `WHERE is_deleted = FALSE AND is_visible = TRUE`**
- ✅ **统计字段只统计 `is_deleted = FALSE AND is_visible = TRUE` 的数据**（代表公开可见的数量）
- ✅ **软删除的帖子/回复在列表中不显示**
- ✅ **被隐藏（`is_visible = FALSE`）的帖子/回复对普通用户不可见，但作者和管理员仍可见**
- ✅ **访问软删除内容的详情页时，返回 404 或"该帖子已被删除"提示**
- ✅ **访问被隐藏内容的详情页时，普通用户返回 404，作者和管理员可正常查看（显示"仅自己可见"样式）**
- ✅ **举报/审核/通知中的 target 指向软删除内容时**:
  - 接口返回占位信息："内容已删除"
  - 或隐藏该条记录（根据业务需求决定）

**字段语义区分**:
- `is_deleted = TRUE`: 软删除，内容对所有人不可见（包括作者），用于用户主动删除或管理员删除
- `is_visible = FALSE`: 风控隐藏，内容对普通用户不可见，但作者和管理员仍可见，用于风控自动处理

**实现建议**:
```python
# 伪代码示例
from sqlalchemy import select
from fastapi import HTTPException

async def get_post(post_id, current_user, db: AsyncSession, is_admin: bool = False):
    result = await db.execute(
        select(ForumPost).where(
            ForumPost.id == post_id,
            ForumPost.is_deleted == False  # 软删除的内容对所有人不可见
        )
    )
    post = result.scalar_one_or_none()
    if not post:
        raise HTTPException(404, "帖子不存在或已删除")
    
    # 检查风控隐藏：普通用户不可见，但作者和管理员可见
    if not post.is_visible:
        if not is_admin and (not current_user or post.author_id != current_user.id):
            raise HTTPException(404, "帖子不存在或已被隐藏")
    
    return post

# 列表查询示例
async def get_posts_list(category_id: int, current_user, db: AsyncSession, is_admin: bool = False):
    query = select(ForumPost).where(
        ForumPost.category_id == category_id,
        ForumPost.is_deleted == False,
        ForumPost.is_visible == True  # 默认只显示可见内容
    )
    
    # 如果是管理员或作者，可以显示被隐藏的内容（可选）
    # if is_admin:
    #     query = query.where(or_(ForumPost.is_visible == True, ForumPost.author_id == current_user.id))
    
    result = await db.execute(query)
    return result.scalars().all()
```

### 4. 锁定帖子的行为规则

**当 `is_locked = TRUE` 时**:

- ✅ **禁止新回复**: 创建回复接口必须检查 `post.is_locked`，如果为 `TRUE`，返回错误：
  ```json
  {
    "error": "帖子已锁定，无法回复",
    "code": "POST_LOCKED"
  }
  ```
- ✅ **作者仍可编辑**: 帖子作者可以编辑自己的帖子（即使已锁定）
- ✅ **管理员可操作**: 管理员可以解锁、删除、置顶等操作
- ⚠️ **删除权限**: 根据业务需求决定，一般作者仍可删除自己的帖子

**前后端联动约定**:

1. **后端统一错误码**:
   - 详见下方「论坛业务错误码速查表」

2. **前端交互**:
   - 锁帖时隐藏回复输入框，显示"该帖子已锁定，无法继续回复"的提示
   - 避免用户打了一大段字，提交才发现锁帖，体验会很差

**论坛业务错误码速查表**:

| 错误码 | HTTP 状态码 | 说明 | 使用场景 |
|--------|------------|------|---------|
| `POST_LOCKED` | 403 | 帖子已锁定，无法回复 | 尝试回复已锁定的帖子 |
| `POST_DELETED` | 404 | 该帖子已被删除 | 访问已删除的帖子详情 |
| `POST_HIDDEN` | 404 | 该帖子已被隐藏 | 普通用户访问已隐藏的帖子 |
| `REPLY_LEVEL_LIMIT` | 403 | 回复层级最多三层 | 尝试创建超过3层的嵌套回复 |
| `REPLY_DELETED` | 404 | 该回复已被删除 | 访问已删除的回复 |
| `REPLY_HIDDEN` | 404 | 该回复已被隐藏 | 普通用户访问已隐藏的回复 |

**错误码使用说明**:
- 所有错误码应在后端统一管理，建议创建 `ForumErrorCode` 枚举类
- 前端根据错误码显示对应的提示文案
- 错误码通过响应体中的 `code` 字段传递，或通过响应头 `X-Error-Code` 传递

**实现建议**:
```python
# 伪代码示例
async def create_reply(post_id, content, user):
    post = await get_post(post_id)
    if post.is_locked:
        raise HTTPException(
            status_code=403,
            detail="帖子已锁定，无法回复",
            headers={"X-Error-Code": "POST_LOCKED"}  # 可选：在响应头中传递错误码
        )
    # ... 创建回复逻辑
```

### 5. 点赞记录的级联删除

- ⚠️ `forum_likes` 表的 `target_id` 没有外键约束（多态关联）
- ✅ 必须在业务逻辑中处理级联删除
- ✅ 删除帖子/回复时，同时删除对应的点赞记录

**推荐方案：使用数据库触发器（PostgreSQL）**:

为了彻底杜绝孤儿点赞记录，建议在数据库层面添加触发器：

```sql
-- 删除帖子时自动清理点赞记录
CREATE OR REPLACE FUNCTION cleanup_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM forum_likes 
    WHERE target_type = 'post' AND target_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cleanup_post_likes
AFTER UPDATE ON forum_posts
FOR EACH ROW
WHEN (OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE)
EXECUTE FUNCTION cleanup_post_likes();

-- 删除回复时自动清理点赞记录
CREATE OR REPLACE FUNCTION cleanup_reply_likes()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM forum_likes 
    WHERE target_type = 'reply' AND target_id = OLD.id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cleanup_reply_likes
AFTER UPDATE ON forum_replies
FOR EACH ROW
WHEN (OLD.is_deleted = FALSE AND NEW.is_deleted = TRUE)
EXECUTE FUNCTION cleanup_reply_likes();
```

**备选方案：使用 SQLAlchemy Mapper 事件**:

如果不想使用触发器，可以在模型层面使用 SQLAlchemy 的 `after_delete` 事件：

```python
from sqlalchemy import event
from sqlalchemy.orm import Session

@event.listens_for(ForumPost, 'after_delete')
def cleanup_post_likes(mapper, connection, target):
    connection.execute(
        delete(ForumLike).where(
            ForumLike.target_type == 'post',
            ForumLike.target_id == target.id
        )
    )

@event.listens_for(ForumReply, 'after_delete')
def cleanup_reply_likes(mapper, connection, target):
    connection.execute(
        delete(ForumLike).where(
            ForumLike.target_type == 'reply',
            ForumLike.target_id == target.id
        )
    )
```

**注意**: 触发器方案更可靠，因为即使业务层代码有遗漏，数据库层面也会自动清理。

**业务层实现示例**（作为双重保障）:
```python
from sqlalchemy import delete, update
from sqlalchemy.ext.asyncio import AsyncSession

async def delete_post(post_id: int, hard_delete: bool = False, db: AsyncSession = None):
    async with db.begin():
        # 删除点赞记录（多态关联，需要手动删除）
        await db.execute(
            delete(ForumLike).where(
                ForumLike.target_type == 'post',
                ForumLike.target_id == post_id
            )
        )
        
        if hard_delete:
            # 硬删除：物理删除记录，外键级联会自动删除收藏和回复
            await db.execute(
                delete(ForumPost).where(ForumPost.id == post_id)
            )
        else:
            # 软删除：只更新 is_deleted 标志
            # 注意：软删除不会触发外键级联，收藏和回复记录仍然存在
            await db.execute(
                update(ForumPost)
                .where(ForumPost.id == post_id)
                .values(is_deleted=True)
            )
            # 软删除时，需要手动更新统计字段
            # 收藏和回复虽然记录还在，但查询时会过滤掉 is_deleted=True 的
```

**重要说明**:
- **软删除（业务层）**: 使用 `UPDATE is_deleted = TRUE`，**不会触发外键级联**
  - 收藏、回复记录仍然存在，但查询时会被过滤
  - 需要手动更新统计字段（`reply_count`、`post_count` 等）
- **硬删除（数据清理）**: 使用 `DELETE`，**会触发外键级联**
  - 外键上的 `ON DELETE CASCADE` 会自动删除相关记录
  - 主要用于数据清理脚本、管理员强制删除等场景
- **业务层默认使用软删除**，硬删除仅在特殊场景使用（如管理员强制删除、数据清理等）

### 6. 并发唯一约束冲突处理

**问题**: 数据库唯一约束在并发场景下可能产生冲突，需要优雅处理。

#### 6.1 举报唯一约束冲突

**场景**: `forum_reports` 表有部分唯一索引 `(target_type, target_id, reporter_id) WHERE status = 'pending'`

**问题**: 并发情况下，同一用户快速点击两次举报，第二次 insert 会被 DB 拒绝（唯一约束错误）

**解决方案**:
```python
# 伪代码示例
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

async def create_report(target_type: str, target_id: int, reporter_id: str, reason: str, db: AsyncSession):
    try:
        report = ForumReport(
            target_type=target_type,
            target_id=target_id,
            reporter_id=reporter_id,
            reason=reason,
            status='pending'
        )
        db.add(report)
        await db.commit()
        return {"message": "举报成功"}
    except IntegrityError as e:
        # 捕获唯一约束冲突
        await db.rollback()
        # 检查是否是因为重复举报
        result = await db.execute(
            select(ForumReport).where(
                ForumReport.target_type == target_type,
                ForumReport.target_id == target_id,
                ForumReport.reporter_id == reporter_id,
                ForumReport.status == 'pending'
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            raise HTTPException(
                status_code=400,
                detail="您已举报过该内容，正在处理中"
            )
        raise  # 其他错误继续抛出
```

#### 6.2 点赞唯一约束冲突

**场景**: `forum_likes` 表有唯一约束 `UNIQUE(target_type, target_id, user_id)`

**问题**: 并发情况下，用户快速点击两次点赞，第二次 insert 会被 DB 拒绝

**解决方案**:
```python
# 伪代码示例
from sqlalchemy import select, delete
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException

async def toggle_like(target_type: str, target_id: int, user_id: str, db: AsyncSession):
    # 先检查是否已点赞
    result = await db.execute(
        select(ForumLike).where(
            ForumLike.target_type == target_type,
            ForumLike.target_id == target_id,
            ForumLike.user_id == user_id
        )
    )
    existing = result.scalar_one_or_none()
    
    if existing:
        # 取消点赞
        await db.execute(
            delete(ForumLike).where(ForumLike.id == existing.id)
        )
        await db.commit()
        return {"liked": False, "like_count": await get_like_count(target_type, target_id, db)}
    else:
        # 点赞
        try:
            like = ForumLike(
                target_type=target_type,
                target_id=target_id,
                user_id=user_id
            )
            db.add(like)
            await db.commit()
            return {"liked": True, "like_count": await get_like_count(target_type, target_id, db)}
        except IntegrityError:
            # 并发冲突：可能其他请求已经点赞了
            await db.rollback()
            # 重新查询确认状态
            result = await db.execute(
                select(ForumLike).where(
                    ForumLike.target_type == target_type,
                    ForumLike.target_id == target_id,
                    ForumLike.user_id == user_id
                )
            )
            existing = result.scalar_one_or_none()
            if existing:
                return {"liked": True, "like_count": await get_like_count(target_type, target_id, db)}
            raise HTTPException(500, "操作失败，请重试")
```

**重要提示**:
- ✅ 所有涉及唯一约束的操作都要捕获 `IntegrityError`
- ✅ 返回友好的业务提示，而不是 500 错误
- ✅ 使用乐观锁或分布式锁处理高并发场景

### 7. 通知触发策略

**通知触发规则表**:

| 场景 | 触发通知类型 | 接收者 | 说明 |
|------|------------|--------|------|
| A 回复帖子 P（楼主为 B） | `reply_post` | B（楼主） | 通知楼主有新回复 |
| A 回复回复 R（作者为 C） | `reply_reply` | C（被回复者） | 通知被回复者 |
| A 回复回复 R2（R2 的父回复是 R1，作者为 C） | `reply_reply` | C（父回复链上的所有作者） | **链式通知**：通知回复链上的所有相关用户 |
| A 点赞帖子 P（楼主为 B） | `like_post` | B（楼主） | 根据配置开关决定是否通知 |
| 管理员对帖子 P 加精（楼主为 B） | `feature_post` | B（楼主） | 通知楼主帖子被加精 |
| 管理员对帖子 P 置顶（楼主为 B） | `pin_post` | B（楼主） | 通知楼主帖子被置顶 |

**链式通知实现**:

当用户回复一个嵌套回复时，需要通知整个回复链上的所有相关用户（避免楼中楼里漏掉通知）：

```python
from sqlalchemy import select

async def create_reply_with_notifications(
    post_id: int, 
    content: str, 
    parent_reply_id: int = None, 
    author_id: str = None, 
    db: AsyncSession = None
):
    # 创建回复
    reply = ForumReply(
        post_id=post_id,
        content=content,
        parent_reply_id=parent_reply_id,
        reply_level=reply_level,  # 由业务层计算
        author_id=author_id
    )
    db.add(reply)
    await db.commit()
    
    # 发送通知
    if parent_reply_id:
        # 获取整个回复链（向上追溯所有父回复）
        reply_chain = []
        current_reply_id = parent_reply_id
        while current_reply_id:
            result = await db.execute(
                select(ForumReply).where(ForumReply.id == current_reply_id)
            )
            parent = result.scalar_one_or_none()
            if not parent:
                break
            reply_chain.append(parent)
            current_reply_id = parent.parent_reply_id
        
        # 通知回复链上的所有作者（排除当前用户自己）
        notified_users = set()
        for chain_reply in reply_chain:
            if chain_reply.author_id != author_id and chain_reply.author_id not in notified_users:
                notification = ForumNotification(
                    notification_type='reply_reply',
                    target_type='reply',
                    target_id=reply.id,
                    from_user_id=author_id,
                    to_user_id=chain_reply.author_id
                )
                db.add(notification)
                notified_users.add(chain_reply.author_id)
    else:
        # 直接回复帖子，通知楼主
        # 获取帖子作者
        result = await db.execute(
            select(ForumPost).where(ForumPost.id == post_id)
        )
        post = result.scalar_one_or_none()
        if post and post.author_id != author_id:
            notification = ForumNotification(
                notification_type='reply_post',
                target_type='post',
                target_id=post_id,
                from_user_id=author_id,
                to_user_id=post.author_id
            )
            db.add(notification)
    
    await db.commit()
```

**实现要求**:
- 回复通知：必须触发（包括链式通知，通知回复链上的所有相关用户）
- 点赞通知：通过配置开关控制（默认启用）
- 加精/置顶通知：必须触发

### 8. 全文搜索配置

- ✅ **当前使用 `pg_trgm` 扩展进行相似度搜索**
- **配置方式**:
  1. 设置环境变量 `USE_PG_TRGM=true` 启用 pg_trgm
  2. 执行迁移文件 `023_add_pg_trgm_for_forum_search.sql` 创建扩展和索引
- **pg_trgm 优势**:
  - ✅ 对中文、英文、数字都有良好的支持
  - ✅ 支持容错搜索和部分匹配
  - ✅ 性能良好，适合中小规模数据
- **降级方案**: 如果未启用 `USE_PG_TRGM`，将使用 `ILIKE` 模糊搜索
- **未来扩展**（大规模数据）:
  - 可考虑接入 MeiliSearch / Elasticsearch 作为独立搜索服务
  - pg_trgm 作为 fallback 方案

### 9. 用户态字段说明

- `is_liked` 和 `is_favorited` 不是数据库字段
- 由后端根据当前登录用户动态计算
- 未登录用户返回 `false` 或省略字段

### 10. 内容预览字段

- 列表接口返回 `content_preview`（截断后，前200字符）
- 详情接口返回完整 `content`
- 已去除 Markdown 标记以提升可读性

### 11. 嵌套回复实现

- 后端一次性查询所有回复，在代码中组装树形结构
- 避免递归查询，提升性能
- 前端直接渲染嵌套好的数据结构
- **分页仅针对一级回复**，每个一级回复附带完整的子回复树

### 12. 实时更新方案

**当前实现**:
- 使用 **React Query 轮询**机制
- 帖子详情页：每 30 秒轮询一次新回复
- 回复列表：使用 React Query 的 `refetchInterval` 配置

**未来扩展**:
- 可考虑使用 **WebSocket** 实现真正的实时推送
- 或使用 **Server-Sent Events (SSE)** 实现单向实时推送
- 具体实现方案见"后续扩展功能"章节

### 13. 大数据量分页优化

**当前方案**:
- 使用 `OFFSET` + `LIMIT` 进行分页
- 适合初期和中小数据量场景

**未来优化**:
- 对于热门板块，可考虑使用 **Keyset Pagination（游标分页）**
- 基于 `created_at` 或 `id` 的游标，避免 `OFFSET` 在大数据量下的性能问题
- 示例：`WHERE created_at < :cursor ORDER BY created_at DESC LIMIT :limit`

### 14. 已删除/隐藏内容的展示规则（前端需要）

**帖子被删除（`is_deleted = TRUE`）时**:
- 列表中不再展示
- 如果用户打开旧 URL，可以返回"该帖子已被删除"的占位页（HTTP 200 + 特定错误码），而不是 404，方便解释
- 后端返回示例：
  ```json
  {
    "error": "该帖子已被删除",
    "code": "POST_DELETED"
  }
  ```

**回复被删除时**:
- 列表中保留一行"该回复已被删除"占位（方便理解楼层结构）
- `content` 前端不展示，后端可选返回 `null` 或空字符串
- 后端返回示例：
  ```json
  {
    "id": 123,
    "content": null,  // 或空字符串
    "is_deleted": true,
    "author": {
      "id": "12345678",
      "name": "已删除用户"
    }
  }
  ```

**被隐藏（`is_visible = FALSE`）时**:
- 对普通用户不可见（列表中不显示，详情页返回 404）
- 帖子作者和管理员仍可见，用"仅自己可见"样式展示
- 前端显示提示："该内容已被隐藏，仅作者和管理员可见"
- 后端返回时，需要根据用户身份判断是否返回内容：
  ```python
  # 伪代码示例
  if not post.is_visible:
      if is_admin or post.author_id == current_user.id:
          # 返回内容，但标记为隐藏
          return {"post": post, "is_hidden": True, "hidden_reason": "风控隐藏"}
      else:
          raise HTTPException(404, "帖子不存在或已被隐藏")
  ```

**这些规则确定好后，前后端对"为什么我看不到 / 为什么还能看到"就不会吵架** 😂

---

---

## 📋 业务逻辑约定总结

### 统计字段更新清单

| 操作 | 需要更新的字段 | 更新逻辑 |
|------|--------------|---------|
| 创建帖子 | `category.post_count += 1`<br>`category.last_post_at = now()` | 仅当 `is_deleted = FALSE AND is_visible = TRUE` |
| 删除帖子 | `category.post_count -= 1`<br>`category.last_post_at` 重新查询 | 仅当原 `is_deleted = FALSE AND is_visible = TRUE` |
| 恢复帖子 | `category.post_count += 1`<br>`category.last_post_at` 重新查询 | 仅当恢复后 `is_deleted = FALSE AND is_visible = TRUE` |
| 隐藏帖子 | `category.post_count -= 1`<br>`category.last_post_at` 重新查询 | 仅当原 `is_visible = TRUE` |
| 取消隐藏帖子 | `category.post_count += 1`<br>`category.last_post_at` 重新查询 | 仅当 `is_deleted = FALSE` 且原 `is_visible = FALSE` |
| 创建回复 | `post.reply_count += 1`<br>`post.last_reply_at = now()` | 仅当 `is_deleted = FALSE AND is_visible = TRUE` |
| 删除回复 | `post.reply_count -= 1`<br>`post.last_reply_at` 重新查询 | 仅当原 `is_deleted = FALSE AND is_visible = TRUE` |
| 恢复回复 | `post.reply_count += 1`<br>`post.last_reply_at` 重新查询 | 仅当恢复后 `is_deleted = FALSE AND is_visible = TRUE` |
| 隐藏回复 | `post.reply_count -= 1`<br>`post.last_reply_at` 重新查询 | 仅当原 `is_visible = TRUE` |
| 取消隐藏回复 | `post.reply_count += 1`<br>`post.last_reply_at` 重新查询 | 仅当 `is_deleted = FALSE` 且原 `is_visible = FALSE` |
| 点赞/收藏 | `post.like_count += 1`<br>`post.favorite_count += 1` | 直接更新 |
| 取消点赞/收藏 | `post.like_count -= 1`<br>`post.favorite_count -= 1` | 直接更新 |

### 查询过滤约定

- ✅ 所有列表查询：`WHERE is_deleted = FALSE AND is_visible = TRUE`
- ✅ 所有统计查询：只统计 `is_deleted = FALSE AND is_visible = TRUE` 的数据
- ✅ 详情查询：
  - 如果 `is_deleted = TRUE`，返回 404 或"该帖子已被删除"
  - 如果 `is_visible = FALSE`，普通用户返回 404，作者和管理员可正常查看

### 权限和行为规则

- ✅ 锁定帖子：禁止新回复，但作者仍可编辑
- ✅ 软删除内容：不显示在列表中，详情页返回 404
- ✅ 举报唯一性：同一用户对同一目标的 pending 举报只能有一条

---

**文档版本**: v1.4  
**最后更新**: 2025-01-27  
**维护者**: LinkU开发团队

