# Newbie Tasks & User Incentive System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a newbie task center, official tasks, skill leaderboard, and badge system to encourage users to showcase their skills and gain visibility on the platform.

**Architecture:** Backend adds new SQLAlchemy models, SQL migrations, and API routes (in new route files under `app/routes/`). Flutter app adds 3 new feature modules (newbie_tasks, skill_leaderboard, badges) with BLoC pattern. React admin frontend adds management pages for task config, official tasks, rewards, and leaderboard.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter/BLoC (mobile), React/TypeScript (admin), PostgreSQL (database)

**Design Doc:** `docs/plans/2026-03-08-newbie-tasks-incentive-design.md`

---

## Phase 0: Database & Backend Infrastructure

### Task 1: Database Migrations — User Fields & Config Tables

**Files:**
- Create: `backend/migrations/109_add_user_bio_and_profile_views.sql`
- Create: `backend/migrations/110_create_user_skills_table.sql`
- Create: `backend/migrations/111_create_newbie_task_config_tables.sql`

**Step 1: Write migration 109 — add bio and profile_views to users**

```sql
-- 109_add_user_bio_and_profile_views.sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_views INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS displayed_badge_id INTEGER;
```

**Step 2: Write migration 110 — user_skills table**

```sql
-- 110_create_user_skills_table.sql
CREATE TABLE IF NOT EXISTS user_skills (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    skill_category VARCHAR(50) NOT NULL,
    skill_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, skill_name)
);
CREATE INDEX IF NOT EXISTS idx_user_skills_user_id ON user_skills(user_id);
CREATE INDEX IF NOT EXISTS idx_user_skills_category ON user_skills(skill_category);
```

**Step 3: Write migration 111 — newbie task config and progress tables**

```sql
-- 111_create_newbie_task_config_tables.sql

-- Newbie task reward config (admin-editable)
CREATE TABLE IF NOT EXISTS newbie_task_config (
    id SERIAL PRIMARY KEY,
    task_key VARCHAR(50) UNIQUE NOT NULL,
    stage INTEGER NOT NULL,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    description_zh TEXT DEFAULT '',
    description_en TEXT DEFAULT '',
    reward_type VARCHAR(20) NOT NULL DEFAULT 'points',
    reward_amount INTEGER NOT NULL DEFAULT 0,
    coupon_id INTEGER REFERENCES coupons(id),
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Stage bonus config (admin-editable)
CREATE TABLE IF NOT EXISTS stage_bonus_config (
    id SERIAL PRIMARY KEY,
    stage INTEGER UNIQUE NOT NULL,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    reward_type VARCHAR(20) NOT NULL DEFAULT 'points',
    reward_amount INTEGER NOT NULL DEFAULT 0,
    coupon_id INTEGER REFERENCES coupons(id),
    is_active BOOLEAN DEFAULT true,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- User task progress
CREATE TABLE IF NOT EXISTS user_tasks_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_key VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMP,
    claimed_at TIMESTAMP,
    UNIQUE(user_id, task_key)
);
CREATE INDEX IF NOT EXISTS idx_user_tasks_progress_user_id ON user_tasks_progress(user_id);

-- Stage bonus progress
CREATE TABLE IF NOT EXISTS stage_bonus_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stage INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    claimed_at TIMESTAMP,
    UNIQUE(user_id, stage)
);

-- Seed default newbie task configs
INSERT INTO newbie_task_config (task_key, stage, title_zh, title_en, description_zh, description_en, reward_type, reward_amount, display_order) VALUES
('upload_avatar', 1, '上传头像', 'Upload Avatar', '上传一张个人头像，让大家认识你', 'Upload a profile photo so others can recognize you', 'points', 50, 1),
('fill_bio', 1, '填写个人简介', 'Write Bio', '填写至少10个字的个人简介', 'Write a bio with at least 10 characters', 'points', 50, 2),
('add_skills', 1, '添加技能标签', 'Add Skills', '添加至少3个技能标签', 'Add at least 3 skill tags', 'points', 100, 3),
('student_verify', 1, '完成学生认证', 'Student Verification', '完成学生邮箱认证', 'Complete student email verification', 'points', 200, 4),
('first_post', 2, '发布第一个帖子', 'First Forum Post', '在论坛发布你的第一个帖子', 'Publish your first forum post', 'points', 200, 5),
('first_flea_item', 2, '发布跳蚤市场商品', 'First Flea Market Item', '在跳蚤市场发布你的第一个商品或服务', 'List your first item or service on the flea market', 'points', 200, 6),
('join_activity', 2, '参加一个活动', 'Join an Activity', '报名参加一个平台活动', 'Sign up for a platform activity', 'points', 200, 7),
('posts_5', 3, '累计发帖5个', '5 Forum Posts', '在论坛累计发布5个帖子', 'Publish 5 forum posts in total', 'points', 300, 8),
('posts_20', 3, '累计发帖20个', '20 Forum Posts', '在论坛累计发布20个帖子', 'Publish 20 forum posts in total', 'points', 500, 9),
('first_assigned_task', 3, '收到第一个指定任务', 'First Assigned Task', '有人向你发布了指定任务', 'Someone assigned a task specifically to you', 'points', 500, 10),
('complete_5_tasks', 3, '完成5个好评任务', '5 Well-Rated Tasks', '完成5个任务并获得好评(评分>=4)', 'Complete 5 tasks with good ratings (>=4)', 'points', 500, 11),
('profile_views_50', 3, '主页被浏览50次', '50 Profile Views', '你的个人主页被浏览了50次', 'Your profile has been viewed 50 times', 'points', 300, 12),
('profile_views_200', 3, '主页被浏览200次', '200 Profile Views', '你的个人主页被浏览了200次', 'Your profile has been viewed 200 times', 'points', 500, 13),
('checkin_7', 3, '连续签到7天', '7-Day Check-in Streak', '连续签到7天', 'Check in for 7 consecutive days', 'points', 200, 14),
('checkin_30', 3, '连续签到30天', '30-Day Check-in Streak', '连续签到30天', 'Check in for 30 consecutive days', 'points', 500, 15)
ON CONFLICT (task_key) DO NOTHING;

-- Seed stage bonus configs
INSERT INTO stage_bonus_config (stage, title_zh, title_en, reward_type, reward_amount) VALUES
(1, '第一阶段完成奖励', 'Stage 1 Completion Bonus', 'points', 100),
(2, '第二阶段完成奖励', 'Stage 2 Completion Bonus', 'coupon', 0),
(3, '第三阶段完成奖励', 'Stage 3 Completion Bonus', 'points', 1000)
ON CONFLICT (stage) DO NOTHING;
```

**Step 4: Commit**

```bash
git add backend/migrations/109_*.sql backend/migrations/110_*.sql backend/migrations/111_*.sql
git commit -m "feat: add migrations for user bio, skills, and newbie task config tables"
```

---

### Task 2: Database Migrations — Official Tasks, Leaderboard, Badges, Admin Rewards

**Files:**
- Create: `backend/migrations/112_create_official_tasks_tables.sql`
- Create: `backend/migrations/113_create_leaderboard_and_badges_tables.sql`
- Create: `backend/migrations/114_create_admin_reward_logs.sql`

**Step 1: Write migration 112 — official tasks**

```sql
-- 112_create_official_tasks_tables.sql
CREATE TABLE IF NOT EXISTS official_tasks (
    id SERIAL PRIMARY KEY,
    title_zh VARCHAR(200) NOT NULL,
    title_en VARCHAR(200) NOT NULL,
    description_zh TEXT DEFAULT '',
    description_en TEXT DEFAULT '',
    topic_tag VARCHAR(50),
    task_type VARCHAR(20) NOT NULL DEFAULT 'forum_post',
    reward_type VARCHAR(20) NOT NULL DEFAULT 'points',
    reward_amount INTEGER NOT NULL DEFAULT 0,
    coupon_id INTEGER REFERENCES coupons(id),
    max_per_user INTEGER NOT NULL DEFAULT 1,
    valid_from TIMESTAMP,
    valid_until TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS official_task_submissions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    official_task_id INTEGER NOT NULL REFERENCES official_tasks(id) ON DELETE CASCADE,
    forum_post_id INTEGER,
    status VARCHAR(20) NOT NULL DEFAULT 'submitted',
    submitted_at TIMESTAMP DEFAULT NOW(),
    claimed_at TIMESTAMP,
    reward_amount INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_official_task_submissions_user ON official_task_submissions(user_id);
CREATE INDEX IF NOT EXISTS idx_official_task_submissions_task ON official_task_submissions(official_task_id);

-- Add official_task_id to forum_posts
ALTER TABLE forum_posts ADD COLUMN IF NOT EXISTS official_task_id INTEGER REFERENCES official_tasks(id);
```

**Step 2: Write migration 113 — leaderboard and badges**

```sql
-- 113_create_leaderboard_and_badges_tables.sql

-- Skill categories (admin-managed)
CREATE TABLE IF NOT EXISTS skill_categories (
    id SERIAL PRIMARY KEY,
    name_zh VARCHAR(100) NOT NULL,
    name_en VARCHAR(100) NOT NULL,
    icon VARCHAR(200) DEFAULT '',
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS skill_leaderboard (
    id SERIAL PRIMARY KEY,
    skill_category VARCHAR(50) NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    completed_tasks INTEGER DEFAULT 0,
    total_amount INTEGER DEFAULT 0,
    avg_rating FLOAT DEFAULT 0.0,
    score FLOAT DEFAULT 0.0,
    rank INTEGER DEFAULT 0,
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(skill_category, user_id)
);
CREATE INDEX IF NOT EXISTS idx_skill_leaderboard_category_rank ON skill_leaderboard(skill_category, rank);

CREATE TABLE IF NOT EXISTS user_badges (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_type VARCHAR(50) NOT NULL DEFAULT 'skill_rank',
    skill_category VARCHAR(50) NOT NULL,
    rank INTEGER NOT NULL,
    is_displayed BOOLEAN DEFAULT false,
    granted_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, skill_category)
);
CREATE INDEX IF NOT EXISTS idx_user_badges_user_id ON user_badges(user_id);

-- Add FK from users.displayed_badge_id to user_badges
ALTER TABLE users ADD CONSTRAINT fk_users_displayed_badge
    FOREIGN KEY (displayed_badge_id) REFERENCES user_badges(id) ON DELETE SET NULL;
```

**Step 3: Write migration 114 — admin reward logs**

```sql
-- 114_create_admin_reward_logs.sql
CREATE TABLE IF NOT EXISTS admin_reward_logs (
    id SERIAL PRIMARY KEY,
    admin_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reward_type VARCHAR(20) NOT NULL,
    points_amount INTEGER,
    coupon_id INTEGER REFERENCES coupons(id),
    reason TEXT DEFAULT '',
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_reward_logs_user ON admin_reward_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_admin_reward_logs_admin ON admin_reward_logs(admin_id);
```

**Step 4: Commit**

```bash
git add backend/migrations/112_*.sql backend/migrations/113_*.sql backend/migrations/114_*.sql
git commit -m "feat: add migrations for official tasks, leaderboard, badges, and admin rewards"
```

---

### Task 3: Backend Models — SQLAlchemy Models

**Files:**
- Modify: `backend/app/models.py` — add new model classes
- Modify: `backend/app/schemas.py` — add Pydantic schemas (if separate file, otherwise in models.py)

**Step 1: Add new SQLAlchemy models to models.py**

Add these model classes at the end of `backend/app/models.py` (before any final lines):

```python
# ============ Newbie Tasks & Incentive System ============

class UserSkill(Base):
    __tablename__ = "user_skills"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    skill_category = Column(String(50), nullable=False)
    skill_name = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=func.now())
    __table_args__ = (UniqueConstraint("user_id", "skill_name"),)


class NewbieTaskConfig(Base):
    __tablename__ = "newbie_task_config"
    id = Column(Integer, primary_key=True, index=True)
    task_key = Column(String(50), unique=True, nullable=False)
    stage = Column(Integer, nullable=False)
    title_zh = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    description_zh = Column(Text, default="")
    description_en = Column(Text, default="")
    reward_type = Column(String(20), nullable=False, default="points")
    reward_amount = Column(Integer, nullable=False, default=0)
    coupon_id = Column(Integer, ForeignKey("coupons.id"), nullable=True)
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class StageBonusConfig(Base):
    __tablename__ = "stage_bonus_config"
    id = Column(Integer, primary_key=True, index=True)
    stage = Column(Integer, unique=True, nullable=False)
    title_zh = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    reward_type = Column(String(20), nullable=False, default="points")
    reward_amount = Column(Integer, nullable=False, default=0)
    coupon_id = Column(Integer, ForeignKey("coupons.id"), nullable=True)
    is_active = Column(Boolean, default=True)
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class UserTasksProgress(Base):
    __tablename__ = "user_tasks_progress"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    task_key = Column(String(50), nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    completed_at = Column(DateTime, nullable=True)
    claimed_at = Column(DateTime, nullable=True)
    __table_args__ = (UniqueConstraint("user_id", "task_key"),)


class StageBonusProgress(Base):
    __tablename__ = "stage_bonus_progress"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    stage = Column(Integer, nullable=False)
    status = Column(String(20), nullable=False, default="pending")
    claimed_at = Column(DateTime, nullable=True)
    __table_args__ = (UniqueConstraint("user_id", "stage"),)


class OfficialTask(Base):
    __tablename__ = "official_tasks"
    id = Column(Integer, primary_key=True, index=True)
    title_zh = Column(String(200), nullable=False)
    title_en = Column(String(200), nullable=False)
    description_zh = Column(Text, default="")
    description_en = Column(Text, default="")
    topic_tag = Column(String(50), nullable=True)
    task_type = Column(String(20), nullable=False, default="forum_post")
    reward_type = Column(String(20), nullable=False, default="points")
    reward_amount = Column(Integer, nullable=False, default=0)
    coupon_id = Column(Integer, ForeignKey("coupons.id"), nullable=True)
    max_per_user = Column(Integer, nullable=False, default=1)
    valid_from = Column(DateTime, nullable=True)
    valid_until = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    created_by = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=func.now())
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())


class OfficialTaskSubmission(Base):
    __tablename__ = "official_task_submissions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    official_task_id = Column(Integer, ForeignKey("official_tasks.id", ondelete="CASCADE"), nullable=False)
    forum_post_id = Column(Integer, nullable=True)
    status = Column(String(20), nullable=False, default="submitted")
    submitted_at = Column(DateTime, default=func.now())
    claimed_at = Column(DateTime, nullable=True)
    reward_amount = Column(Integer, default=0)


class SkillCategory(Base):
    __tablename__ = "skill_categories"
    id = Column(Integer, primary_key=True, index=True)
    name_zh = Column(String(100), nullable=False)
    name_en = Column(String(100), nullable=False)
    icon = Column(String(200), default="")
    display_order = Column(Integer, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=func.now())


class SkillLeaderboard(Base):
    __tablename__ = "skill_leaderboard"
    id = Column(Integer, primary_key=True, index=True)
    skill_category = Column(String(50), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    completed_tasks = Column(Integer, default=0)
    total_amount = Column(Integer, default=0)
    avg_rating = Column(Float, default=0.0)
    score = Column(Float, default=0.0)
    rank = Column(Integer, default=0)
    updated_at = Column(DateTime, default=func.now())
    __table_args__ = (UniqueConstraint("skill_category", "user_id"),)


class UserBadge(Base):
    __tablename__ = "user_badges"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    badge_type = Column(String(50), nullable=False, default="skill_rank")
    skill_category = Column(String(50), nullable=False)
    rank = Column(Integer, nullable=False)
    is_displayed = Column(Boolean, default=False)
    granted_at = Column(DateTime, default=func.now())
    __table_args__ = (UniqueConstraint("user_id", "skill_category"),)


class AdminRewardLog(Base):
    __tablename__ = "admin_reward_logs"
    id = Column(Integer, primary_key=True, index=True)
    admin_id = Column(Integer, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    reward_type = Column(String(20), nullable=False)
    points_amount = Column(Integer, nullable=True)
    coupon_id = Column(Integer, ForeignKey("coupons.id"), nullable=True)
    reason = Column(Text, default="")
    created_at = Column(DateTime, default=func.now())
```

**Step 2: Add bio and profile_views to existing User model**

In the `User` class in `models.py`, add:

```python
    bio = Column(Text, default="")
    profile_views = Column(Integer, default=0)
    displayed_badge_id = Column(Integer, ForeignKey("user_badges.id", ondelete="SET NULL"), nullable=True)
```

**Step 3: Add official_task_id to ForumPost model (if exists in models.py)**

```python
    official_task_id = Column(Integer, ForeignKey("official_tasks.id"), nullable=True)
```

**Step 4: Commit**

```bash
git add backend/app/models.py
git commit -m "feat: add SQLAlchemy models for newbie tasks, official tasks, leaderboard, badges"
```

---

### Task 4: Backend Schemas

**Files:**
- Modify: `backend/app/schemas.py` — add Pydantic request/response schemas

**Step 1: Add schemas for all new features**

Add to `backend/app/schemas.py`:

```python
# ============ User Skills ============

class UserSkillCreate(BaseModel):
    skill_category: str
    skill_name: str

class UserSkillOut(BaseModel):
    id: int
    skill_category: str
    skill_name: str
    class Config:
        from_attributes = True

# ============ Newbie Tasks ============

class NewbieTaskConfigOut(BaseModel):
    task_key: str
    stage: int
    title_zh: str
    title_en: str
    description_zh: str
    description_en: str
    reward_type: str
    reward_amount: int
    coupon_id: Optional[int] = None
    display_order: int
    is_active: bool
    class Config:
        from_attributes = True

class NewbieTaskConfigUpdate(BaseModel):
    title_zh: Optional[str] = None
    title_en: Optional[str] = None
    description_zh: Optional[str] = None
    description_en: Optional[str] = None
    reward_type: Optional[str] = None
    reward_amount: Optional[int] = None
    coupon_id: Optional[int] = None
    is_active: Optional[bool] = None

class UserTaskProgressOut(BaseModel):
    task_key: str
    status: str  # pending / completed / claimed
    completed_at: Optional[datetime] = None
    claimed_at: Optional[datetime] = None
    config: NewbieTaskConfigOut
    class Config:
        from_attributes = True

class StageBonusConfigOut(BaseModel):
    stage: int
    title_zh: str
    title_en: str
    reward_type: str
    reward_amount: int
    coupon_id: Optional[int] = None
    is_active: bool
    class Config:
        from_attributes = True

class StageBonusConfigUpdate(BaseModel):
    title_zh: Optional[str] = None
    title_en: Optional[str] = None
    reward_type: Optional[str] = None
    reward_amount: Optional[int] = None
    coupon_id: Optional[int] = None

class StageProgressOut(BaseModel):
    stage: int
    status: str  # pending / completed / claimed
    claimed_at: Optional[datetime] = None
    config: StageBonusConfigOut
    class Config:
        from_attributes = True

# ============ Official Tasks ============

class OfficialTaskCreate(BaseModel):
    title_zh: str
    title_en: str
    description_zh: str = ""
    description_en: str = ""
    topic_tag: Optional[str] = None
    task_type: str = "forum_post"
    reward_type: str = "points"
    reward_amount: int = 0
    coupon_id: Optional[int] = None
    max_per_user: int = 1
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None

class OfficialTaskUpdate(BaseModel):
    title_zh: Optional[str] = None
    title_en: Optional[str] = None
    description_zh: Optional[str] = None
    description_en: Optional[str] = None
    topic_tag: Optional[str] = None
    task_type: Optional[str] = None
    reward_type: Optional[str] = None
    reward_amount: Optional[int] = None
    coupon_id: Optional[int] = None
    max_per_user: Optional[int] = None
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None
    is_active: Optional[bool] = None

class OfficialTaskOut(BaseModel):
    id: int
    title_zh: str
    title_en: str
    description_zh: str
    description_en: str
    topic_tag: Optional[str] = None
    task_type: str
    reward_type: str
    reward_amount: int
    coupon_id: Optional[int] = None
    max_per_user: int
    valid_from: Optional[datetime] = None
    valid_until: Optional[datetime] = None
    is_active: bool
    created_at: datetime
    class Config:
        from_attributes = True

class OfficialTaskSubmissionOut(BaseModel):
    id: int
    official_task_id: int
    forum_post_id: Optional[int] = None
    status: str
    submitted_at: datetime
    claimed_at: Optional[datetime] = None
    reward_amount: int
    class Config:
        from_attributes = True

class OfficialTaskSubmit(BaseModel):
    forum_post_id: int

# ============ Skill Leaderboard ============

class SkillCategoryCreate(BaseModel):
    name_zh: str
    name_en: str
    icon: str = ""
    display_order: int = 0

class SkillCategoryOut(BaseModel):
    id: int
    name_zh: str
    name_en: str
    icon: str
    display_order: int
    is_active: bool
    class Config:
        from_attributes = True

class LeaderboardEntryOut(BaseModel):
    user_id: int
    user_name: str
    user_avatar: str
    skill_category: str
    completed_tasks: int
    total_amount: int
    avg_rating: float
    score: float
    rank: int
    class Config:
        from_attributes = True

# ============ Badges ============

class UserBadgeOut(BaseModel):
    id: int
    badge_type: str
    skill_category: str
    rank: int
    is_displayed: bool
    granted_at: datetime
    class Config:
        from_attributes = True

# ============ Admin Rewards ============

class AdminRewardSend(BaseModel):
    user_id: int
    reward_type: str  # points / coupon
    points_amount: Optional[int] = None
    coupon_id: Optional[int] = None
    reason: str = ""

class AdminRewardLogOut(BaseModel):
    id: int
    admin_id: int
    user_id: int
    reward_type: str
    points_amount: Optional[int] = None
    coupon_id: Optional[int] = None
    reason: str
    created_at: datetime
    class Config:
        from_attributes = True

# ============ Profile Update Extension ============

class ProfileUpdateExtended(BaseModel):
    bio: Optional[str] = None
    skills: Optional[List[UserSkillCreate]] = None
```

**Step 2: Commit**

```bash
git add backend/app/schemas.py
git commit -m "feat: add Pydantic schemas for newbie tasks, official tasks, leaderboard, badges"
```

---

## Phase 1: Backend API Routes

### Task 5: Newbie Tasks API Routes

**Files:**
- Create: `backend/app/routes/newbie_tasks.py`
- Modify: `backend/app/main.py` — register new router

**Step 1: Create newbie tasks route file**

Create `backend/app/routes/newbie_tasks.py` with these endpoints:

- `GET /api/newbie-tasks/progress` — get all task progress for current user (auto-detect completed tasks on first call)
- `POST /api/newbie-tasks/{task_key}/claim` — claim reward for a completed task
- `GET /api/newbie-tasks/stages` — get stage progress
- `POST /api/newbie-tasks/stages/{stage}/claim` — claim stage bonus

Key implementation details:
- On first call to `/progress`, check each task's completion condition against user data and create `user_tasks_progress` records
- Task detection logic (per task_key):
  - `upload_avatar`: `user.avatar` is not empty and not the preset default avatar URL
  - `fill_bio`: `user.bio` is not empty and `len(user.bio) >= 10`
  - `add_skills`: count of `user_skills` for user >= 3
  - `student_verify`: `user.is_student_verified == True`
  - `first_post`: count of `forum_posts` by user >= 1
  - `first_flea_item`: count of `flea_items` by user >= 1
  - `join_activity`: count of `activity_applications` by user >= 1
  - `posts_5` / `posts_20`: count of `forum_posts` by user >= 5 / 20
  - `first_assigned_task`: exists a task where `assigned_to == user_id`
  - `complete_5_tasks`: count of completed tasks with rating >= 4 for user >= 5
  - `profile_views_50` / `profile_views_200`: `user.profile_views >= 50 / 200`
  - `checkin_7` / `checkin_30`: max `consecutive_days` from `check_ins` for user >= 7 / 30
- On claim: verify status is "completed", award points via existing `PointsAccount` system, set status to "claimed"
- Send push notification when a task transitions to "completed" status

**Step 2: Register router in main.py**

Add to `backend/app/main.py`:

```python
from app.routes.newbie_tasks import router as newbie_tasks_router
app.include_router(newbie_tasks_router, prefix="/api/newbie-tasks", tags=["newbie-tasks"])
```

**Step 3: Commit**

```bash
git add backend/app/routes/newbie_tasks.py backend/app/main.py
git commit -m "feat: add newbie tasks API routes with auto-detection and claim logic"
```

---

### Task 6: Profile Update Extension & User Skills API

**Files:**
- Modify: `backend/app/routers.py` — extend PATCH /profile endpoint
- Create: `backend/app/routes/user_skills.py`

**Step 1: Extend PATCH /profile to support bio**

Find the existing `PATCH /profile` endpoint in `backend/app/routers.py` (around line 5234). Add `bio` field support to `ProfileUpdate` schema and the handler.

**Step 2: Create user skills routes**

Create `backend/app/routes/user_skills.py` with:

- `GET /api/skills/my` — get current user's skills
- `POST /api/skills/my` — add a skill (body: `{skill_category, skill_name}`)
- `DELETE /api/skills/my/{skill_id}` — remove a skill
- `GET /api/skills/categories` — get all system skill categories

**Step 3: Register in main.py**

```python
from app.routes.user_skills import router as user_skills_router
app.include_router(user_skills_router, prefix="/api/skills", tags=["skills"])
```

**Step 4: Commit**

```bash
git add backend/app/routers.py backend/app/routes/user_skills.py backend/app/main.py
git commit -m "feat: extend profile update with bio, add user skills API"
```

---

### Task 7: Profile View Counter

**Files:**
- Modify: `backend/app/routers.py` — increment profile_views on profile detail endpoint

**Step 1: Find the GET user profile detail endpoint and add view counting**

Find the endpoint that returns user profile detail (e.g., `GET /api/users/{user_id}/profile`). Add:

```python
# Increment profile views (don't count self-views)
if current_user and current_user.id != user_id:
    user.profile_views = (user.profile_views or 0) + 1
    db.commit()
```

**Step 2: Commit**

```bash
git add backend/app/routers.py
git commit -m "feat: increment profile view counter on profile detail endpoint"
```

---

### Task 8: Official Tasks API Routes

**Files:**
- Create: `backend/app/routes/official_tasks.py`
- Modify: `backend/app/forum_routes.py` — add official_task_id support to post creation
- Modify: `backend/app/main.py` — register router

**Step 1: Create official tasks route file**

Endpoints:
- `GET /api/official-tasks` — list active official tasks for current user (include submission count per user)
- `GET /api/official-tasks/{id}` — official task detail
- `POST /api/official-tasks/{id}/submit` — submit (body: `{forum_post_id}`)
  - Validate: task is active, not expired, user hasn't exceeded max_per_user
  - Validate: forum_post_id belongs to current user and has matching topic_tag
  - Create submission record, set status to "submitted" (claimable)
- `POST /api/official-tasks/{id}/claim` — claim reward
  - Validate: submission exists with status "submitted"
  - Award points/coupon, update status to "claimed"

**Step 2: Modify forum post creation to accept official_task_id**

In `backend/app/forum_routes.py`, in the `create_post` function (line ~2828):
- Add `official_task_id` as optional field in `ForumPostCreate` schema
- When creating the post, set `official_task_id` if provided
- Validate that the official task exists, is active, and is of type "forum_post"

**Step 3: Register router**

```python
from app.routes.official_tasks import router as official_tasks_router
app.include_router(official_tasks_router, prefix="/api/official-tasks", tags=["official-tasks"])
```

**Step 4: Commit**

```bash
git add backend/app/routes/official_tasks.py backend/app/forum_routes.py backend/app/main.py
git commit -m "feat: add official tasks API with forum post association"
```

---

### Task 9: Skill Leaderboard API Routes

**Files:**
- Create: `backend/app/routes/leaderboard.py`
- Modify: `backend/app/main.py`

**Step 1: Create leaderboard route file**

Endpoints:
- `GET /api/leaderboard/skills` — list all skill categories
- `GET /api/leaderboard/skills/{category}` — get Top 10 for a category
- `GET /api/leaderboard/skills/{category}/my-rank` — get current user's rank in a category

**Step 2: Create leaderboard recalculation logic**

Add a function `recalculate_leaderboard(db, category=None)` that:
1. For each skill category (or a specific one):
   - Query all users who have completed tasks tagged with that skill category
   - Calculate: completed_tasks count, total_amount sum, avg_rating
   - Apply formula: `score = completed_tasks * 50 + (total_amount / 100) * 2 + avg_rating * 10`
   - Rank by score descending
   - Upsert into `skill_leaderboard` table
2. For Top 10 users: create/update `user_badges`, remove badges for users who dropped out
3. This function will be called by admin endpoint and can be scheduled as a daily cron job

**Step 3: Register router**

```python
from app.routes.leaderboard import router as leaderboard_router
app.include_router(leaderboard_router, prefix="/api/leaderboard", tags=["leaderboard"])
```

**Step 4: Commit**

```bash
git add backend/app/routes/leaderboard.py backend/app/main.py
git commit -m "feat: add skill leaderboard API with ranking calculation"
```

---

### Task 10: Badges API Routes

**Files:**
- Create: `backend/app/routes/badges.py`
- Modify: `backend/app/main.py`

**Step 1: Create badges route file**

Endpoints:
- `GET /api/badges/my` — get current user's badges
- `PUT /api/badges/{id}/display` — toggle a badge as displayed (set is_displayed=true, set all others to false)
- `GET /api/users/{user_id}/badges` — get a user's badges (public)

When setting a badge as displayed, also update `users.displayed_badge_id`.

**Step 2: Register router**

**Step 3: Commit**

```bash
git add backend/app/routes/badges.py backend/app/main.py
git commit -m "feat: add badges API with display toggle"
```

---

### Task 11: Admin API Routes

**Files:**
- Create: `backend/app/routes/admin_incentive.py`
- Modify: `backend/app/main.py`

**Step 1: Create admin incentive route file**

All endpoints require admin authentication (`separate_auth` dependency).

Endpoints:
- **Newbie task config:**
  - `GET /api/admin/newbie-tasks/config` — list all task configs
  - `PUT /api/admin/newbie-tasks/config/{task_key}` — update task config (reward amount, text, active status)
  - `GET /api/admin/stage-bonus/config` — list stage bonus configs
  - `PUT /api/admin/stage-bonus/config/{stage}` — update stage bonus config

- **Official tasks:**
  - `POST /api/admin/official-tasks` — create official task
  - `PUT /api/admin/official-tasks/{id}` — update official task
  - `DELETE /api/admin/official-tasks/{id}` — deactivate (set is_active=false)
  - `GET /api/admin/official-tasks` — list all (including inactive)
  - `GET /api/admin/official-tasks/{id}/stats` — participation stats

- **Manual rewards:**
  - `POST /api/admin/rewards/send` — send points/coupon to a user
  - `GET /api/admin/rewards/logs` — query reward logs (with pagination, filter by user)

- **Check-in rewards:**
  - `GET /api/admin/checkin/rewards` — list check-in reward configs
  - `PUT /api/admin/checkin/rewards/{id}` — update check-in reward
  - `POST /api/admin/checkin/rewards` — create new check-in reward

- **Skill categories:**
  - `GET /api/admin/skill-categories` — list all
  - `POST /api/admin/skill-categories` — create
  - `PUT /api/admin/skill-categories/{id}` — update
  - `DELETE /api/admin/skill-categories/{id}` — deactivate

- **Leaderboard:**
  - `POST /api/admin/leaderboard/refresh` — trigger recalculation

**Step 2: Register router**

```python
from app.routes.admin_incentive import router as admin_incentive_router
app.include_router(admin_incentive_router, prefix="/api/admin", tags=["admin-incentive"])
```

**Step 3: Commit**

```bash
git add backend/app/routes/admin_incentive.py backend/app/main.py
git commit -m "feat: add admin API routes for incentive system management"
```

---

## Phase 2: Flutter App

### Task 12: Flutter Models

**Files:**
- Create: `link2ur/lib/data/models/newbie_task.dart`
- Create: `link2ur/lib/data/models/official_task.dart`
- Create: `link2ur/lib/data/models/skill_leaderboard_entry.dart`
- Create: `link2ur/lib/data/models/badge.dart`
- Create: `link2ur/lib/data/models/skill_category.dart`
- Modify: `link2ur/lib/data/models/user.dart` — add bio, skills, displayedBadge fields

**Step 1: Create all model files**

Each model should extend `Equatable`, have `fromJson()`, `toJson()`, and `copyWith()` methods following existing patterns in the codebase.

Key models:
- `NewbieTaskProgress` — task_key, status, completed_at, claimed_at, config (nested)
- `NewbieTaskConfig` — task_key, stage, title_zh, title_en, description_zh, description_en, reward_type, reward_amount
- `StageProgress` — stage, status, claimed_at, config (nested)
- `OfficialTask` — id, title_zh, title_en, description_zh, description_en, topic_tag, task_type, reward_type, reward_amount, max_per_user, valid_from, valid_until, user_submission_count
- `SkillLeaderboardEntry` — user_id, user_name, user_avatar, skill_category, completed_tasks, total_amount, avg_rating, score, rank
- `UserBadge` — id, badge_type, skill_category, rank, is_displayed, granted_at
- `SkillCategory` — id, name_zh, name_en, icon, display_order

**Step 2: Update User model**

Add to `link2ur/lib/data/models/user.dart`:
- `final String? bio;` (if not already present — it is, but verify backend now supports it)
- `final List<UserSkill>? skills;`
- `final UserBadge? displayedBadge;`

**Step 3: Commit**

```bash
git add link2ur/lib/data/models/
git commit -m "feat: add Flutter models for newbie tasks, official tasks, leaderboard, badges"
```

---

### Task 13: Flutter API Endpoints & Repositories

**Files:**
- Modify: `link2ur/lib/core/constants/api_endpoints.dart` — add new endpoint constants
- Create: `link2ur/lib/data/repositories/newbie_tasks_repository.dart`
- Create: `link2ur/lib/data/repositories/official_tasks_repository.dart`
- Create: `link2ur/lib/data/repositories/skill_leaderboard_repository.dart`
- Create: `link2ur/lib/data/repositories/badges_repository.dart`
- Create: `link2ur/lib/data/repositories/user_skills_repository.dart`

**Step 1: Add endpoint constants**

Add to `api_endpoints.dart`:

```dart
// Newbie Tasks
static const String newbieTasksProgress = '/api/newbie-tasks/progress';
static const String newbieTasksClaim = '/api/newbie-tasks'; // /{task_key}/claim
static const String newbieTasksStages = '/api/newbie-tasks/stages';
static const String newbieTasksStagesClaim = '/api/newbie-tasks/stages'; // /{stage}/claim

// Official Tasks
static const String officialTasks = '/api/official-tasks';

// Skills
static const String userSkills = '/api/skills/my';
static const String skillCategories = '/api/skills/categories';

// Leaderboard
static const String leaderboardSkills = '/api/leaderboard/skills';

// Badges
static const String badgesMy = '/api/badges/my';
static const String badgesDisplay = '/api/badges'; // /{id}/display
static const String userBadges = '/api/users'; // /{id}/badges
```

**Step 2: Create repositories**

Each repository wraps `ApiService` calls, following existing repository patterns (see `coupon_points_repository.dart` for reference).

**Step 3: Commit**

```bash
git add link2ur/lib/core/constants/api_endpoints.dart link2ur/lib/data/repositories/
git commit -m "feat: add Flutter repositories and API endpoints for incentive system"
```

---

### Task 14: Flutter BLoCs — Newbie Tasks

**Files:**
- Create: `link2ur/lib/features/newbie_tasks/bloc/newbie_tasks_bloc.dart`
- Events and states as `part of` the bloc file (per project convention)

**Step 1: Define events**

```dart
// Events:
// NewbieTasksLoadRequested — load all progress + stages
// NewbieTaskClaimRequested(taskKey) — claim a task reward
// NewbieStageBonusClaimRequested(stage) — claim stage bonus
// NewbieTasksRefreshRequested — refresh after user action
```

**Step 2: Define state**

```dart
// State fields:
// status: loading / loaded / error
// tasks: List<NewbieTaskProgress>
// stages: List<StageProgress>
// officialTasks: List<OfficialTask>
// errorMessage: String?
```

**Step 3: Implement bloc handlers**

- `_onLoadRequested`: call repository to get progress + stages + official tasks
- `_onClaimRequested`: call claim endpoint, show success, refresh
- `_onStageBonusClaim`: call stage claim endpoint, refresh

**Step 4: Commit**

```bash
git add link2ur/lib/features/newbie_tasks/
git commit -m "feat: add NewbieTasksBloc with load, claim, and refresh logic"
```

---

### Task 15: Flutter BLoCs — Skill Leaderboard & Badges

**Files:**
- Create: `link2ur/lib/features/skill_leaderboard/bloc/skill_leaderboard_bloc.dart`
- Create: `link2ur/lib/features/badges/bloc/badges_bloc.dart`

**Step 1: Skill Leaderboard BLoC**

```dart
// Events:
// LeaderboardLoadRequested — load categories
// LeaderboardCategorySelected(category) — load Top 10 for category
// LeaderboardMyRankRequested(category) — load my rank

// State:
// categories: List<SkillCategory>
// entries: List<SkillLeaderboardEntry>
// selectedCategory: String?
// myRank: int?
// status: loading / loaded / error
```

**Step 2: Badges BLoC**

```dart
// Events:
// BadgesLoadRequested — load my badges
// BadgeDisplayToggled(badgeId) — set as displayed badge

// State:
// badges: List<UserBadge>
// status: loading / loaded / error
```

**Step 3: Commit**

```bash
git add link2ur/lib/features/skill_leaderboard/ link2ur/lib/features/badges/
git commit -m "feat: add SkillLeaderboardBloc and BadgesBloc"
```

---

### Task 16: Flutter Views — Newbie Task Center

**Files:**
- Create: `link2ur/lib/features/newbie_tasks/views/newbie_tasks_center_view.dart`
- Create: `link2ur/lib/features/newbie_tasks/views/widgets/task_item_widget.dart`
- Create: `link2ur/lib/features/newbie_tasks/views/widgets/stage_progress_widget.dart`
- Create: `link2ur/lib/features/newbie_tasks/views/widgets/official_task_card.dart`

**Step 1: Build the task center page**

- Full-page view with sections for each stage
- Each stage shows a progress bar and list of tasks
- Tasks show: icon, title (localized), reward preview, status badge (pending/completed/claimed)
- "Claim" button for completed tasks with animation
- Official tasks section at the bottom with "Official" badge
- Stage completion bonus card at the end of each stage

**Step 2: Commit**

```bash
git add link2ur/lib/features/newbie_tasks/views/
git commit -m "feat: add newbie task center UI"
```

---

### Task 17: Flutter Views — Leaderboard & Badges

**Files:**
- Create: `link2ur/lib/features/skill_leaderboard/views/skill_leaderboard_view.dart`
- Create: `link2ur/lib/features/skill_leaderboard/views/widgets/leaderboard_item_widget.dart`
- Create: `link2ur/lib/features/badges/views/badges_display_view.dart`
- Create: `link2ur/lib/features/badges/views/badge_selector_dialog.dart`

**Step 1: Leaderboard page**

- Tab bar with skill categories
- Each tab shows Top 10 list with: rank number, avatar, name, completed tasks, total amount, rating, score
- Highlight current user's position if on the list
- "My Rank" section at bottom if user is not in Top 10

**Step 2: Badges display**

- Grid/list view of user's badges on profile page
- Each badge shows: skill category icon, "Top N" label, rank number
- Badge selector dialog for choosing which badge to display on avatar

**Step 3: Commit**

```bash
git add link2ur/lib/features/skill_leaderboard/views/ link2ur/lib/features/badges/views/
git commit -m "feat: add leaderboard and badges UI views"
```

---

### Task 18: Flutter Integration — Wire Into Existing Pages

**Files:**
- Modify: `link2ur/lib/app_providers.dart` — register new repositories
- Modify: `link2ur/lib/core/router/app_router.dart` — add routes
- Modify: Home view — insert newbie task card
- Modify: Profile view — add badges display section
- Modify: Edit profile view — add bio field and skill tags editor
- Modify: Forum post creation view — add official task selector
- Modify: User avatar widget — show badge indicator

**Step 1: Register repositories in app_providers.dart**

Add `NewbieTasksRepository`, `OfficialTasksRepository`, `SkillLeaderboardRepository`, `BadgesRepository`, `UserSkillsRepository` to `MultiRepositoryProvider`.

**Step 2: Add routes in app_router.dart**

```dart
// /newbie-tasks → NewbieTasksCenterView
// /leaderboard → SkillLeaderboardView
// /badges → BadgesDisplayView
```

**Step 3: Modify profile view**

Add badges section after existing profile info, showing user's badges from `BadgesBloc`.

**Step 4: Modify edit profile**

Add `TextFormField` for bio and a skill tag editor (chip-style with add/remove).

**Step 5: Modify forum post creation**

Add optional dropdown/selector for "Associate with Official Task" when official tasks of type `forum_post` are available.

**Step 6: Modify avatar widget**

If the user being displayed has a `displayedBadge`, show a small badge indicator (e.g., colored border or small icon overlay).

**Step 7: Commit**

```bash
git add link2ur/lib/app_providers.dart link2ur/lib/core/router/ link2ur/lib/features/
git commit -m "feat: integrate newbie tasks, leaderboard, and badges into existing pages"
```

---

## Phase 3: Admin Frontend (React)

### Task 19: Admin — Newbie Task Config Page

**Files:**
- Create: `frontend/src/pages/NewbieTaskConfig.tsx`
- Modify: `frontend/src/App.tsx` — add route

**Step 1: Build config page**

- Table listing all newbie task configs: task_key, stage, title_zh, title_en, reward_type, reward_amount, is_active
- Edit button per row → modal/inline edit for reward_amount, titles, descriptions, is_active
- Stage bonus config section below with same editing capability
- API calls: `GET /api/admin/newbie-tasks/config`, `PUT /api/admin/newbie-tasks/config/{task_key}`

**Step 2: Add route in App.tsx**

**Step 3: Commit**

```bash
git add frontend/src/pages/NewbieTaskConfig.tsx frontend/src/App.tsx
git commit -m "feat: add admin newbie task config management page"
```

---

### Task 20: Admin — Official Tasks Management Page

**Files:**
- Create: `frontend/src/pages/OfficialTaskManagement.tsx`
- Modify: `frontend/src/App.tsx`

**Step 1: Build management page**

- List of official tasks with filters (active/inactive, task_type)
- Create button → form with all fields (title_zh/en, description_zh/en, topic_tag, task_type, reward_type, reward_amount, max_per_user, valid_from, valid_until)
- Edit/deactivate actions per row
- Stats view per task: participation count, submission count

**Step 2: Commit**

```bash
git add frontend/src/pages/OfficialTaskManagement.tsx frontend/src/App.tsx
git commit -m "feat: add admin official tasks management page"
```

---

### Task 21: Admin — Manual Rewards & Check-in Config Pages

**Files:**
- Create: `frontend/src/pages/ManualRewards.tsx`
- Create: `frontend/src/pages/CheckinRewardConfig.tsx`
- Modify: `frontend/src/App.tsx`

**Step 1: Manual rewards page**

- User search (by name/ID/email)
- Reward form: reward type (points/coupon), amount, coupon selector, reason
- Send button with confirmation dialog
- Reward log table below with pagination and user filter

**Step 2: Check-in reward config page**

- Table of check-in rewards: consecutive_days, reward_type, points_reward, is_active
- Edit per row
- Add new reward button

**Step 3: Commit**

```bash
git add frontend/src/pages/ManualRewards.tsx frontend/src/pages/CheckinRewardConfig.tsx frontend/src/App.tsx
git commit -m "feat: add admin manual rewards and check-in config pages"
```

---

### Task 22: Admin — Skill Categories & Leaderboard Management

**Files:**
- Create: `frontend/src/pages/SkillCategoryManagement.tsx`
- Create: `frontend/src/pages/LeaderboardManagement.tsx`
- Modify: `frontend/src/App.tsx`

**Step 1: Skill categories page**

- CRUD table: name_zh, name_en, icon, display_order, is_active
- Add/edit/deactivate

**Step 2: Leaderboard management page**

- View leaderboard by category (dropdown selector)
- Top 10 table showing user, tasks, amount, rating, score, rank
- "Refresh Leaderboard" button (calls `POST /api/admin/leaderboard/refresh`)

**Step 3: Commit**

```bash
git add frontend/src/pages/SkillCategoryManagement.tsx frontend/src/pages/LeaderboardManagement.tsx frontend/src/App.tsx
git commit -m "feat: add admin skill categories and leaderboard management pages"
```

---

## Phase 4: Localization & Notifications

### Task 23: Flutter Localization

**Files:**
- Modify: `link2ur/lib/l10n/app_en.arb`
- Modify: `link2ur/lib/l10n/app_zh.arb`
- Modify: `link2ur/lib/l10n/app_zh_Hant.arb` (if exists)
- Modify: `link2ur/lib/core/utils/error_localizer.dart` — add error codes

**Step 1: Add localization keys**

Add keys for:
- Newbie task center titles, stage names, button labels
- "Claim Reward", "Completed", "Pending", "Claimed"
- Official task labels
- Leaderboard titles, rank labels
- Badge names, display toggle labels
- Notification messages: "You have completed '{taskName}'! Claim your {reward} reward now!"

**Step 2: Add error codes to error_localizer.dart**

```dart
'newbie_task_not_completed': context.l10n.errorNewbieTaskNotCompleted,
'newbie_task_already_claimed': context.l10n.errorNewbieTaskAlreadyClaimed,
'official_task_max_reached': context.l10n.errorOfficialTaskMaxReached,
'official_task_expired': context.l10n.errorOfficialTaskExpired,
```

**Step 3: Run gen-l10n**

```bash
cd link2ur && flutter gen-l10n
```

**Step 4: Commit**

```bash
git add link2ur/lib/l10n/ link2ur/lib/core/utils/error_localizer.dart
git commit -m "feat: add localization for newbie tasks, leaderboard, and badges"
```

---

### Task 24: Backend Notification Integration

**Files:**
- Modify: `backend/app/routes/newbie_tasks.py` — send notification on task completion

**Step 1: Add notification sending**

When a task status changes to "completed" during the auto-detection phase, send a push notification:

```python
from app.push_notification_service import send_push_notification_async_safe

# After detecting a task is completed:
await send_push_notification_async_safe(
    user_id=user.id,
    title_en="Task Completed!",
    title_zh="任务完成！",
    body_en=f"You've completed '{config.title_en}'. Claim your {config.reward_amount // 100} points now!",
    body_zh=f"你已完成'{config.title_zh}'，快去领取{config.reward_amount // 100}积分奖励！",
    data={"type": "newbie_task", "task_key": task_key}
)
```

**Step 2: Commit**

```bash
git add backend/app/routes/newbie_tasks.py
git commit -m "feat: send push notifications when newbie tasks are completed"
```

---

## Phase 5: Testing & Final Integration

### Task 25: Backend Tests

**Files:**
- Create: `backend/tests/test_newbie_tasks.py`
- Create: `backend/tests/test_official_tasks.py`
- Create: `backend/tests/test_leaderboard.py`

**Step 1: Write key test cases**

- Newbie tasks: auto-detection logic for each task_key, claim flow, double-claim prevention, stage bonus claim
- Official tasks: submission with valid/invalid post, max_per_user enforcement, expired task rejection
- Leaderboard: score calculation formula verification, ranking order, badge assignment for Top 10

**Step 2: Run tests**

```bash
cd backend && python -m pytest tests/test_newbie_tasks.py tests/test_official_tasks.py tests/test_leaderboard.py -v
```

**Step 3: Commit**

```bash
git add backend/tests/
git commit -m "test: add backend tests for newbie tasks, official tasks, and leaderboard"
```

---

### Task 26: Flutter Tests

**Files:**
- Create: `link2ur/test/features/newbie_tasks/bloc/newbie_tasks_bloc_test.dart`
- Create: `link2ur/test/features/skill_leaderboard/bloc/skill_leaderboard_bloc_test.dart`

**Step 1: Write BLoC tests**

Using `bloc_test` + `mocktail` (per project convention):
- NewbieTasksBloc: load, claim success, claim failure, stage bonus claim
- SkillLeaderboardBloc: load categories, select category, load my rank

**Step 2: Run tests**

```bash
cd link2ur && flutter test test/features/newbie_tasks/ test/features/skill_leaderboard/
```

**Step 3: Commit**

```bash
git add link2ur/test/
git commit -m "test: add Flutter BLoC tests for newbie tasks and leaderboard"
```

---

### Task 27: Final Review & Cleanup

**Step 1: Run Flutter analyze**

```bash
cd link2ur && flutter analyze
```

Fix any warnings.

**Step 2: Run all Flutter tests**

```bash
cd link2ur && flutter test
```

**Step 3: Run backend tests**

```bash
cd backend && python -m pytest -v
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: fix lint warnings and finalize incentive system implementation"
```
