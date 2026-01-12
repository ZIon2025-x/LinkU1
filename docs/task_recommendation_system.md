# 任务匹配与推荐系统设计方案

## 📊 现状分析

### 现有数据结构

1. **任务模型 (Task)**
   - 基本信息：标题、描述、类型、位置、价格、截止日期
   - 地理位置：latitude, longitude（用于距离计算）
   - 任务等级：normal, vip, super, expert
   - 状态：open, accepted, completed, cancelled

2. **用户模型 (User)**
   - 基本信息：用户等级、完成任务数、平均评分
   - 地理位置：residence_city（常住城市）
   - 统计数据：task_count, completed_task_count, avg_rating

3. **用户偏好 (UserPreferences)**
   - task_types: 偏好的任务类型（JSON数组）
   - locations: 偏好的地点（JSON数组）
   - task_levels: 偏好的任务等级（JSON数组）
   - keywords: 偏好关键词（JSON数组）
   - min_deadline_days: 最少截止时间（天）

4. **任务历史 (TaskHistory)**
   - 记录用户接受、完成、取消任务的行为
   - 可用于分析用户偏好和行为模式

### 现有功能

- ✅ 基础任务查询（按类型、地点、关键词筛选）
- ✅ 用户偏好设置
- ✅ 任务历史记录
- ❌ **缺少智能推荐算法**
- ❌ **缺少用户行为追踪（浏览、点击）**
- ❌ **缺少任务匹配评分系统**

---

## 🎯 推荐系统架构设计

### 1. 数据层扩展

#### 1.1 用户行为追踪表

```sql
CREATE TABLE user_task_interactions (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    interaction_type VARCHAR(20) NOT NULL,  -- view, click, apply, accept, complete, skip
    interaction_time TIMESTAMPTZ DEFAULT NOW(),
    duration_seconds INTEGER,  -- 浏览时长（秒）
    device_type VARCHAR(20),  -- mobile, desktop, tablet
    metadata JSONB,  -- 额外信息（如来源页面、推荐原因等）
    
    UNIQUE(user_id, task_id, interaction_type, DATE(interaction_time))
);

CREATE INDEX idx_interactions_user ON user_task_interactions(user_id, interaction_time DESC);
CREATE INDEX idx_interactions_task ON user_task_interactions(task_id);
CREATE INDEX idx_interactions_type ON user_task_interactions(interaction_type);
```

#### 1.2 任务特征向量表（用于机器学习）

```sql
CREATE TABLE task_features (
    task_id INTEGER PRIMARY KEY REFERENCES tasks(id) ON DELETE CASCADE,
    feature_vector JSONB,  -- 任务特征向量（类型、价格、位置等）
    popularity_score FLOAT DEFAULT 0.0,  -- 受欢迎程度分数
    urgency_score FLOAT DEFAULT 0.0,  -- 紧急程度分数
    quality_score FLOAT DEFAULT 0.0,  -- 质量分数
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_task_features_popularity ON task_features(popularity_score DESC);
CREATE INDEX idx_task_features_urgency ON task_features(urgency_score DESC);
```

#### 1.3 用户画像表

```sql
CREATE TABLE user_profiles (
    user_id VARCHAR(8) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    preference_vector JSONB,  -- 用户偏好向量
    behavior_vector JSONB,  -- 行为特征向量
    skill_tags TEXT[],  -- 技能标签数组
    preferred_price_range JSONB,  -- 偏好价格范围 {min, max}
    preferred_distance_km INTEGER DEFAULT 10,  -- 偏好距离（公里）
    active_time_slots JSONB,  -- 活跃时间段 [{start, end}, ...]
    last_profile_update TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 🧮 推荐算法方案

### 方案1：基于内容的推荐（Content-Based Filtering）

**原理**：根据用户历史行为和偏好，推荐相似的任务

**优点**：
- 不需要其他用户数据（冷启动友好）
- 可解释性强
- 实现简单，性能好

**实现步骤**：

1. **任务特征提取**
   ```python
   def extract_task_features(task):
       return {
           'task_type': task.task_type,
           'location': task.location,
           'price_range': categorize_price(task.reward),
           'deadline_urgency': calculate_urgency(task.deadline),
           'task_level': task.task_level,
           'keywords': extract_keywords(task.title, task.description)
       }
   ```

2. **用户偏好向量构建**
   ```python
   def build_user_preference_vector(user, interactions):
       # 从用户历史行为中提取偏好
       preferred_types = get_frequent_types(interactions)
       preferred_locations = get_frequent_locations(interactions)
       preferred_price_range = get_price_range(interactions)
       return {
           'task_types': preferred_types,
           'locations': preferred_locations,
           'price_range': preferred_price_range,
           'keywords': extract_keywords_from_history(interactions)
       }
   ```

3. **相似度计算**
   ```python
   def calculate_similarity(user_vector, task_features):
       score = 0.0
       
       # 任务类型匹配（权重：0.3）
       if task_features['task_type'] in user_vector['task_types']:
           score += 0.3
       
       # 位置匹配（权重：0.25）
       if is_location_match(task_features['location'], user_vector['locations']):
           score += 0.25
       
       # 价格匹配（权重：0.2）
       if is_price_in_range(task_features['price_range'], user_vector['price_range']):
           score += 0.2
       
       # 关键词匹配（权重：0.15）
       keyword_match = calculate_keyword_similarity(
           task_features['keywords'], 
           user_vector['keywords']
       )
       score += 0.15 * keyword_match
       
       # 任务等级匹配（权重：0.1）
       if task_features['task_level'] in user_vector.get('task_levels', []):
           score += 0.1
       
       return score
   ```

---

### 方案2：协同过滤（Collaborative Filtering）

**原理**：找到与目标用户相似的其他用户，推荐他们喜欢的任务

**优点**：
- 可以发现用户潜在兴趣
- 推荐多样性好

**缺点**：
- 需要大量用户数据
- 冷启动问题（新用户、新任务）

**实现步骤**：

1. **用户相似度计算**
   ```python
   def calculate_user_similarity(user1_id, user2_id, interactions):
       # 获取两个用户都交互过的任务
       user1_tasks = get_user_interacted_tasks(user1_id)
       user2_tasks = get_user_interacted_tasks(user2_id)
       
       common_tasks = set(user1_tasks) & set(user2_tasks)
       if not common_tasks:
           return 0.0
       
       # 计算余弦相似度或皮尔逊相关系数
       return cosine_similarity(user1_tasks, user2_tasks, common_tasks)
   ```

2. **基于用户的协同过滤**
   ```python
   def recommend_by_collaborative_filtering(user_id, k=10):
       # 1. 找到最相似的K个用户
       similar_users = find_k_similar_users(user_id, k)
       
       # 2. 获取这些用户喜欢的任务
       recommended_tasks = []
       for similar_user in similar_users:
           liked_tasks = get_user_liked_tasks(similar_user.id)
           for task in liked_tasks:
               if task not in user_interacted_tasks(user_id):
                   recommended_tasks.append((task, similar_user.similarity))
       
       # 3. 按相似度加权排序
       recommended_tasks.sort(key=lambda x: x[1], reverse=True)
       return [task for task, _ in recommended_tasks[:20]]
   ```

---

### 方案3：混合推荐（Hybrid Recommendation）⭐ **推荐使用**

**原理**：结合多种推荐算法，取长补短

**优点**：
- 准确率高
- 覆盖冷启动场景
- 推荐多样性好

**实现策略**：

```python
def hybrid_recommend(user_id, limit=20):
    scores = {}
    
    # 1. 基于内容的推荐（权重：40%）
    content_based = content_based_recommend(user_id, limit=50)
    for task, score in content_based:
        scores[task.id] = scores.get(task.id, 0) + score * 0.4
    
    # 2. 协同过滤推荐（权重：30%）
    if has_enough_data(user_id):
        collaborative = collaborative_filtering_recommend(user_id, limit=50)
        for task, score in collaborative:
            scores[task.id] = scores.get(task.id, 0) + score * 0.3
    
    # 3. 热门任务推荐（权重：15%）
    popular = get_popular_tasks(limit=30)
    for task in popular:
        scores[task.id] = scores.get(task.id, 0) + 0.15
    
    # 4. 地理位置推荐（权重：10%）
    location_based = get_nearby_tasks(user_id, radius_km=10, limit=30)
    for task in location_based:
        scores[task.id] = scores.get(task.id, 0) + 0.1
    
    # 5. 时间匹配推荐（权重：5%）
    time_based = get_time_matched_tasks(user_id, limit=20)
    for task in time_based:
        scores[task.id] = scores.get(task.id, 0) + 0.05
    
    # 排序并返回
    sorted_tasks = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [task_id for task_id, _ in sorted_tasks[:limit]]
```

---

### 方案4：机器学习推荐（进阶）

**使用技术**：
- **矩阵分解**（Matrix Factorization）：SVD, NMF
- **深度学习**：神经网络推荐系统
- **强化学习**：多臂老虎机（Multi-Armed Bandit）

**实现示例（矩阵分解）**：

```python
from sklearn.decomposition import NMF
import numpy as np

def matrix_factorization_recommend(user_id, n_components=50):
    # 1. 构建用户-任务交互矩阵
    interaction_matrix = build_interaction_matrix()
    
    # 2. 矩阵分解
    model = NMF(n_components=n_components, random_state=42)
    W = model.fit_transform(interaction_matrix)  # 用户特征矩阵
    H = model.components_  # 任务特征矩阵
    
    # 3. 预测用户对未交互任务的评分
    user_idx = get_user_index(user_id)
    user_features = W[user_idx]
    predicted_scores = np.dot(user_features, H)
    
    # 4. 返回推荐任务
    recommended_task_indices = np.argsort(predicted_scores)[::-1][:20]
    return [get_task_by_index(idx) for idx in recommended_task_indices]
```

---

## 🚀 高效算法优化

### 1. 缓存策略

```python
# 使用Redis缓存推荐结果
@cache_result(ttl=3600, key_prefix="recommendations")
def get_user_recommendations(user_id):
    return hybrid_recommend(user_id)
```

### 2. 增量更新

```python
# 用户行为发生时，增量更新推荐分数
def update_recommendations_on_interaction(user_id, task_id, interaction_type):
    # 只更新相关任务的分数，而不是重新计算全部
    update_task_score(user_id, task_id, interaction_type)
    invalidate_user_recommendations_cache(user_id)
```

### 3. 预计算热门任务

```python
# 定时任务：每小时更新热门任务列表
@celery.task
def update_popular_tasks():
    # 计算过去24小时的热门任务
    popular_tasks = calculate_popular_tasks(time_window=24)
    redis_cache.set("popular_tasks", popular_tasks, ex=3600)
```

### 4. 向量化计算

```python
# 使用NumPy进行批量相似度计算
import numpy as np

def batch_calculate_similarity(user_vectors, task_vectors):
    # 向量化计算，比循环快100倍+
    similarity_matrix = np.dot(user_vectors, task_vectors.T)
    return similarity_matrix
```

---

## 📈 评分系统设计

### 综合评分公式

```python
def calculate_task_score(user, task, context=None):
    """
    计算任务对用户的综合评分
    
    评分维度：
    1. 内容匹配度（40%）
    2. 地理位置匹配度（20%）
    3. 价格吸引力（15%）
    4. 时间匹配度（10%）
    5. 任务质量（10%）
    6. 用户等级匹配（5%）
    """
    score = 0.0
    
    # 1. 内容匹配度
    content_score = calculate_content_match(user, task)
    score += content_score * 0.4
    
    # 2. 地理位置匹配度
    if user.residence_city and task.location:
        location_score = calculate_location_match(user, task)
        score += location_score * 0.2
    
    # 3. 价格吸引力
    price_score = calculate_price_attractiveness(user, task)
    score += price_score * 0.15
    
    # 4. 时间匹配度
    time_score = calculate_time_match(user, task)
    score += time_score * 0.1
    
    # 5. 任务质量（基于发布者评分、任务完成率等）
    quality_score = calculate_task_quality(task)
    score += quality_score * 0.1
    
    # 6. 用户等级匹配
    level_score = calculate_level_match(user, task)
    score += level_score * 0.05
    
    return min(score, 1.0)  # 归一化到[0, 1]
```

---

## 🔄 实时推荐流程

### 1. 用户行为追踪

```python
# 在任务详情页、列表页记录用户行为
@router.get("/tasks/{task_id}")
async def get_task_detail(task_id: int, current_user: User):
    task = get_task(task_id)
    
    # 记录浏览行为
    record_interaction(
        user_id=current_user.id,
        task_id=task_id,
        interaction_type="view",
        duration_seconds=None
    )
    
    return task
```

### 2. 推荐API

```python
@router.get("/recommendations")
async def get_recommendations(
    current_user: User = Depends(get_current_user),
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """获取个性化任务推荐"""
    recommendations = get_user_recommendations(current_user.id, limit, db)
    return {
        "recommendations": recommendations,
        "total": len(recommendations),
        "algorithm": "hybrid"
    }
```

### 3. 推送通知

```python
# 当有新任务匹配用户偏好时，发送推送
@celery.task
def check_and_notify_matching_tasks():
    users = get_active_users()
    new_tasks = get_recent_tasks(hours=1)
    
    for user in users:
        for task in new_tasks:
            score = calculate_task_score(user, task)
            if score > 0.7:  # 匹配度阈值
                send_push_notification(
                    user_id=user.id,
                    title="新任务推荐",
                    message=f"发现一个可能适合您的任务：{task.title}",
                    data={"task_id": task.id}
                )
```

---

## 📊 性能优化建议

### 1. 数据库优化

- **索引**：为常用查询字段建立索引
  ```sql
  CREATE INDEX idx_tasks_location_type ON tasks(location, task_type);
  CREATE INDEX idx_tasks_status_deadline ON tasks(status, deadline);
  CREATE INDEX idx_interactions_user_time ON user_task_interactions(user_id, interaction_time DESC);
  ```

### 2. 查询优化

- 使用**物化视图**预计算热门任务
- 使用**分页**避免一次性加载大量数据
- 使用**批量查询**减少数据库往返

### 3. 缓存策略

- **L1缓存**：用户推荐结果（TTL: 1小时）
- **L2缓存**：热门任务列表（TTL: 1小时）
- **L3缓存**：任务特征向量（TTL: 24小时）

### 4. 异步处理

- 使用**Celery**异步计算推荐分数
- 使用**消息队列**处理用户行为事件

---

## 🎯 实施优先级

### Phase 1: 基础推荐（1-2周）
1. ✅ 创建用户行为追踪表
2. ✅ 实现基于内容的推荐
3. ✅ 添加推荐API端点
4. ✅ 前端集成推荐功能

### Phase 2: 智能推荐（2-3周）
1. ✅ 实现协同过滤
2. ✅ 实现混合推荐算法
3. ✅ 添加实时推送通知
4. ✅ 性能优化和缓存

### Phase 3: 机器学习（可选，3-4周）
1. ✅ 实现矩阵分解
2. ✅ 模型训练和调优
3. ✅ A/B测试
4. ✅ 持续优化

---

## 📝 总结

**推荐使用的方案**：
1. **短期**：基于内容的推荐 + 地理位置匹配（快速实现，效果明显）
2. **中期**：混合推荐系统（结合多种算法，准确率高）
3. **长期**：机器学习推荐（持续优化，适应性强）

**关键成功因素**：
- ✅ 完善用户行为数据收集
- ✅ 建立有效的评分体系
- ✅ 持续监控和优化推荐效果
- ✅ 平衡推荐准确性和多样性
