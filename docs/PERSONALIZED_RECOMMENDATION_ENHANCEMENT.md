# 个性化推荐优化实现方案

## 📊 现有推荐系统 vs 个性化推荐优化

### 现有推荐系统（已实现）✅

**当前功能**：
1. ✅ **基于内容的推荐**（35%权重）
   - 根据用户历史任务类型偏好
   - 根据用户位置偏好
   - 根据价格偏好
   - 根据任务等级偏好

2. ✅ **协同过滤推荐**（25%权重）
   - 找到相似用户
   - 推荐相似用户喜欢的任务

3. ✅ **地理位置推荐**（12%权重）
   - 基于用户居住城市
   - 推荐同城任务

4. ✅ **新任务优先**（15%权重）
   - 优先推荐新发布的任务

5. ✅ **时间匹配推荐**（5%权重）
   - 推荐即将截止的任务

### 个性化推荐优化（需要增强）⭐

**需要增强的功能**：

#### 1. **基于历史行为的深度分析** ⭐⭐⭐
**现有**：✅ 已有基础实现
- 分析用户接受的任务类型
- 分析用户发布的任务类型

**需要增强**：
- ❌ **分析用户浏览和搜索行为**（浏览时长、搜索关键词）
- ❌ **分析用户跳过/忽略的任务**（负反馈）
- ❌ **分析用户在不同时间段的活跃度**

#### 2. **基于位置的增强** ⭐⭐
**现有**：✅ 已有基础实现
- 基于用户居住城市推荐

**需要增强**：
- ❌ **考虑用户常去的地点**（不只是居住城市）
- ❌ **支持多城市偏好**（用户可能在多个城市活动）
- ❌ **考虑任务距离**（GPS距离，不只是城市匹配）

#### 3. **基于时间的增强** ⭐⭐⭐
**现有**：✅ 已有基础实现
- 推荐即将截止的任务（5%权重）

**需要增强**：
- ❌ **推荐适合当前时间段的任务**（早上推荐早上的任务）
- ❌ **考虑用户活跃时间**（用户通常在什么时间使用应用）
- ❌ **考虑任务时间段匹配**（任务需要的时间段 vs 用户可用时间段）

#### 4. **基于社交关系** ⭐⭐⭐⭐ **全新功能**
**现有**：❌ 完全没有实现

**需要新增**：
- ❌ **推荐好友发布的任务**
- ❌ **推荐同校/同城用户的任务**
- ❌ **推荐高评分用户的任务**
- ❌ **推荐用户关注的人发布的任务**

---

## 🎯 实现方案

### 阶段 1：增强现有功能（优先级高）

#### 1.1 增强基于历史行为的分析

**实现内容**：
```python
# backend/app/task_recommendation.py

def _enhanced_content_based_recommend(self, user: User, limit: int) -> List[Dict]:
    """增强的基于内容推荐"""
    
    # 1. 分析用户浏览行为（新增）
    view_history = self._get_user_view_history(user.id)
    view_preferences = self._analyze_view_preferences(view_history)
    
    # 2. 分析用户搜索行为（新增）
    search_history = self._get_user_search_history(user.id)
    search_keywords = self._extract_search_keywords(search_history)
    
    # 3. 分析用户跳过/忽略的任务（新增，负反馈）
    skipped_tasks = self._get_user_skipped_tasks(user.id)
    negative_preferences = self._analyze_negative_preferences(skipped_tasks)
    
    # 4. 分析用户活跃时间段（新增）
    active_time_slots = self._get_user_active_time_slots(user.id)
    
    # 5. 结合现有偏好
    user_preferences = self._get_user_preferences(user.id)
    user_history = self._get_user_task_history(user.id)
    
    # 6. 综合计算推荐分数
    # ...
```

**需要的数据**：
- 用户浏览记录（已有 `UserTaskInteraction` 表）
- 用户搜索记录（需要新增表或使用现有数据）
- 用户跳过任务记录（已有 `UserTaskInteraction` 表，`interaction_type='skip'`）

#### 1.2 增强地理位置推荐

**实现内容**：
```python
def _enhanced_location_based_recommend(self, user: User, limit: int) -> List[Dict]:
    """增强的地理位置推荐"""
    
    # 1. 用户居住城市（已有）
    residence_city = user.residence_city
    
    # 2. 用户常去的地点（新增）
    frequent_locations = self._get_user_frequent_locations(user.id)
    
    # 3. 用户历史任务地点（新增）
    historical_locations = self._get_user_historical_task_locations(user.id)
    
    # 4. 多城市偏好（新增）
    preferred_cities = self._get_user_preferred_cities(user.id)
    
    # 5. GPS距离计算（新增）
    if user.latitude and user.longitude:
        # 计算任务距离，优先推荐距离近的任务
        # ...
```

**需要的数据**：
- 用户GPS位置（如果用户允许）
- 用户历史任务地点（从 `TaskHistory` 表获取）
- 用户常去地点（从任务历史中分析）

#### 1.3 增强时间匹配推荐

**实现内容**：
```python
def _enhanced_time_based_recommend(self, user: User, limit: int) -> List[Dict]:
    """增强的时间匹配推荐"""
    
    # 1. 当前时间段（新增）
    current_hour = datetime.now().hour
    current_day_of_week = datetime.now().weekday()
    
    # 2. 用户活跃时间段（新增）
    user_active_hours = self._get_user_active_hours(user.id)
    user_active_days = self._get_user_active_days(user.id)
    
    # 3. 任务时间段匹配（新增）
    # 如果任务有明确的时间段要求，匹配用户可用时间段
    # ...
    
    # 4. 即将截止的任务（已有）
    # ...
```

**需要的数据**：
- 用户活跃时间分析（从 `UserTaskInteraction` 表分析）
- 任务时间段信息（如果任务有时间段要求）

---

### 阶段 2：新增社交关系推荐（优先级中）

#### 2.1 创建社交关系表（如果需要）

```sql
-- 如果还没有好友关系表，需要创建
CREATE TABLE IF NOT EXISTS user_follows (
    id SERIAL PRIMARY KEY,
    follower_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    following_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, following_id)
);

CREATE INDEX idx_follows_follower ON user_follows(follower_id);
CREATE INDEX idx_follows_following ON user_follows(following_id);
```

#### 2.2 实现社交关系推荐

```python
def _social_based_recommend(self, user: User, limit: int) -> List[Dict]:
    """基于社交关系的推荐"""
    
    # 1. 推荐好友发布的任务
    friends = self._get_user_friends(user.id)
    friend_tasks = self._get_friend_tasks(friends, limit=10)
    
    # 2. 推荐同校用户的任务
    if user.school_id or user.university_id:
        school_users = self._get_school_users(user)
        school_tasks = self._get_school_user_tasks(school_users, limit=10)
    
    # 3. 推荐高评分用户的任务
    high_rated_users = self._get_high_rated_users(limit=20)
    high_rated_tasks = self._get_high_rated_user_tasks(high_rated_users, limit=10)
    
    # 4. 推荐用户关注的人发布的任务
    following_users = self._get_following_users(user.id)
    following_tasks = self._get_following_user_tasks(following_users, limit=10)
    
    # 合并并去重
    # ...
```

---

## 📋 实现清单

### 需要新增的功能

#### 1. 用户行为深度分析 ⭐⭐⭐
- [ ] 分析用户浏览时长（从 `UserTaskInteraction` 表）
- [ ] 分析用户搜索关键词（需要记录搜索历史）
- [ ] 分析用户跳过/忽略的任务（负反馈）
- [ ] 分析用户活跃时间段

#### 2. 地理位置增强 ⭐⭐
- [ ] 分析用户常去的地点（从任务历史）
- [ ] 支持多城市偏好
- [ ] GPS距离计算（如果用户允许位置权限）

#### 3. 时间匹配增强 ⭐⭐⭐
- [ ] 分析用户活跃时间段
- [ ] 推荐适合当前时间段的任务
- [ ] 任务时间段匹配（如果任务有时间段要求）

#### 4. 社交关系推荐 ⭐⭐⭐⭐ **全新**
- [ ] 推荐好友发布的任务
- [ ] 推荐同校用户的任务
- [ ] 推荐高评分用户的任务
- [ ] 推荐用户关注的人发布的任务

---

## 🔄 与现有推荐系统的集成

### 更新混合推荐算法权重

**当前权重**：
- 基于内容：35%
- 协同过滤：25%
- 地理位置：12%
- 新任务优先：15%
- 时间匹配：5%
- 热门任务：8%

**优化后权重**（建议）：
- 基于内容（增强）：30%
- 协同过滤：25%
- **社交关系（新增）**：15% ⭐
- 地理位置（增强）：10%
- 新任务优先：10%
- 时间匹配（增强）：8%
- 热门任务：2%

---

## 🚀 实施步骤

### 第一步：增强现有功能（1-2周）

1. **增强基于历史行为的分析**
   - 分析用户浏览行为
   - 分析用户搜索行为
   - 分析用户活跃时间段

2. **增强地理位置推荐**
   - 分析用户常去地点
   - 支持多城市偏好

3. **增强时间匹配推荐**
   - 分析用户活跃时间段
   - 推荐适合当前时间段的任务

### 第二步：新增社交关系推荐（1周）

1. **创建社交关系表**（如果需要）
2. **实现社交关系推荐算法**
3. **集成到混合推荐算法**

### 第三步：测试和优化（1周）

1. A/B测试对比效果
2. 监控推荐质量指标
3. 根据数据调整权重

---

## 📊 预期效果

### 优化前 vs 优化后

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 任务申请率 | 基准 | +10-15% | ⬆️ |
| 任务完成率 | 基准 | +15-25% | ⬆️ |
| 用户满意度 | 基准 | +20-30% | ⬆️ |
| 推荐相关性 | 基准 | +25-35% | ⬆️ |

---

## 💡 总结

### 现有推荐系统 vs 个性化推荐优化

**现有系统**：
- ✅ 已有基础推荐功能
- ✅ 基于内容、协同过滤、地理位置
- ✅ 功能完善，但可以更精准

**个性化推荐优化**：
- ⭐ 增强现有功能（更精准）
- ⭐ 新增社交关系推荐（全新功能）
- ⭐ 更智能的时间匹配
- ⭐ 更精准的位置匹配

**主要区别**：
1. **深度分析**：不只是看用户接受的任务，还看浏览、搜索、跳过行为
2. **社交关系**：新增推荐好友、同校用户的任务
3. **时间智能**：不只是推荐即将截止的，还推荐适合当前时间段和用户活跃时间的
4. **位置精准**：不只是同城，还考虑常去地点、GPS距离

需要我开始实现这些功能吗？
