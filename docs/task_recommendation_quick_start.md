# 任务推荐系统 - 快速开始指南

## 🚀 快速部署

### 1. 数据库迁移

```bash
# 执行迁移脚本创建用户行为追踪表
psql -d linku_db -f backend/migrations/048_add_user_task_interactions.sql
```

### 2. 验证安装

```bash
# 检查模型是否正确导入
python -c "from app.models import UserTaskInteraction; print('✓ 模型导入成功')"

# 检查推荐引擎
python -c "from app.task_recommendation import TaskRecommendationEngine; print('✓ 推荐引擎导入成功')"
```

### 3. 运行测试

```bash
# 运行推荐系统测试
pytest backend/tests/test_task_recommendation.py -v
```

---

## 📱 前端集成

### 1. 在任务列表页添加推荐区域

在 `frontend/src/pages/Tasks.tsx` 中添加：

```tsx
import RecommendedTasks from '../components/RecommendedTasks';

// 在组件中添加
<RecommendedTasks 
  limit={10} 
  algorithm="hybrid"
  showTitle={true}
/>
```

### 2. 在任务详情页显示匹配分数

在 `frontend/src/pages/TaskDetail.tsx` 中添加：

```tsx
import { useEffect, useState } from 'react';
import { getTaskMatchScore } from '../api';

// 在组件中添加状态
const [matchScore, setMatchScore] = useState<number | null>(null);

// 在useEffect中获取匹配分数
useEffect(() => {
  if (task && user) {
    getTaskMatchScore(task.id)
      .then(data => setMatchScore(data.match_score))
      .catch(err => console.error('获取匹配分数失败:', err));
  }
}, [task, user]);

// 在UI中显示
{matchScore !== null && (
  <div className="match-score-badge">
    匹配度: {Math.round(matchScore * 100)}%
  </div>
)}
```

### 3. 记录用户行为

在任务详情页加载时自动记录浏览：

```tsx
import { recordTaskInteraction } from '../api';

useEffect(() => {
  if (task && user) {
    const startTime = Date.now();
    
    // 页面卸载时记录浏览时长
    return () => {
      const duration = Math.floor((Date.now() - startTime) / 1000);
      const deviceType = /Mobile|Android|iPhone/i.test(navigator.userAgent) 
        ? 'mobile' 
        : 'desktop';
      
      recordTaskInteraction(task.id, 'view', duration, deviceType);
    };
  }
}, [task, user]);
```

---

## 🔧 配置调整

### 推荐算法权重调整

在 `backend/app/task_recommendation.py` 的 `_hybrid_recommend` 方法中：

```python
# 当前权重配置
content_based: 0.4      # 基于内容
collaborative: 0.3      # 协同过滤
location_based: 0.15    # 地理位置
popular: 0.1           # 热门任务
time_based: 0.05        # 时间匹配

# 可以根据实际效果调整这些权重
```

### 缓存时间调整

在 `backend/app/task_recommendation.py` 中：

```python
# 当前缓存时间：1小时
redis_cache.setex(cache_key, 3600, json.dumps(recommendations))

# 可以调整为更短或更长的时间
# 更短（30分钟）：1800
# 更长（2小时）：7200
```

---

## 📊 监控和优化

### 1. 查看推荐指标

```bash
# 通过API获取推荐系统指标
curl -X GET "http://localhost:8000/api/admin/recommendation-metrics?days=7" \
  -H "Authorization: Bearer YOUR_ADMIN_TOKEN"
```

### 2. 查看用户推荐统计

```bash
# 获取当前用户的推荐统计
curl -X GET "http://localhost:8000/api/user/recommendation-stats" \
  -H "Authorization: Bearer USER_TOKEN"
```

### 3. 性能监控

推荐系统会自动记录以下指标：
- 推荐任务总数
- 点击率（CTR）
- 接受率
- 平均匹配分数
- 用户参与度

---

## 🎯 使用示例

### 获取推荐任务

```javascript
import { getTaskRecommendations } from '../api';

// 获取混合推荐
const recommendations = await getTaskRecommendations(20, 'hybrid');

// 获取基于内容的推荐
const contentBased = await getTaskRecommendations(20, 'content_based');

// 获取协同过滤推荐
const collaborative = await getTaskRecommendations(20, 'collaborative');
```

### 记录用户行为

```javascript
import { recordTaskInteraction } from '../api';

// 记录浏览
await recordTaskInteraction(taskId, 'view', 30, 'mobile');

// 记录点击
await recordTaskInteraction(taskId, 'click', undefined, 'mobile');

// 记录申请
await recordTaskInteraction(taskId, 'apply', undefined, 'desktop');

// 记录跳过
await recordTaskInteraction(taskId, 'skip', undefined, 'mobile');
```

---

## 🔍 故障排查

### 问题1：推荐结果为空

**可能原因**：
- 用户没有历史行为数据
- 没有符合条件的开放任务

**解决方案**：
- 检查数据库中是否有开放任务
- 检查用户是否有任务历史记录
- 尝试使用 `content_based` 算法（对数据要求较低）

### 问题2：推荐结果不准确

**可能原因**：
- 用户偏好设置不完整
- 历史行为数据不足

**解决方案**：
- 引导用户完善偏好设置
- 收集更多用户行为数据
- 调整推荐算法权重

### 问题3：性能问题

**可能原因**：
- 缓存未生效
- 数据库查询未优化

**解决方案**：
- 检查Redis连接
- 查看数据库索引
- 增加缓存时间

---

## 📈 优化建议

### 短期（1-2周）

1. **完善用户行为追踪**
   - 在所有任务相关页面添加追踪
   - 记录更详细的行为数据

2. **调整权重参数**
   - 根据实际效果调整各维度权重
   - A/B测试不同权重组合

### 中期（1-2个月）

1. **引入机器学习**
   - 使用矩阵分解优化推荐
   - 训练个性化推荐模型

2. **实时推荐**
   - 新任务发布时实时匹配用户
   - 发送推送通知

### 长期（3-6个月）

1. **深度学习模型**
   - 使用神经网络学习复杂特征
   - 提升推荐准确率

2. **强化学习**
   - 使用多臂老虎机算法
   - 动态调整推荐策略

---

## 📚 相关文档

- [详细设计文档](./task_recommendation_system.md)
- [中文实施总结](./task_recommendation_summary_cn.md)

---

## 💡 最佳实践

1. **数据收集**
   - 确保所有用户行为都被记录
   - 定期检查数据质量

2. **算法选择**
   - 新用户：使用 `content_based`
   - 老用户：使用 `hybrid`
   - 数据充足：使用 `collaborative`

3. **性能优化**
   - 使用缓存减少计算
   - 异步处理推荐计算
   - 定期清理过期数据

4. **用户体验**
   - 显示推荐理由
   - 提供匹配分数
   - 允许用户反馈

---

## 🎉 完成！

现在您的任务推荐系统已经可以投入使用了！

**下一步**：
1. 在前端集成推荐组件
2. 开始收集用户行为数据
3. 根据实际效果调整参数
4. 持续监控和优化

如有问题，请查看详细文档或联系开发团队。
