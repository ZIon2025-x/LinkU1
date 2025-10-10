# Base64图片数据清理指南

## 问题说明

旧系统将图片数据以base64格式直接存储在消息内容中，导致：
- 数据库体积膨胀
- 查询性能下降
- 图片无法通过新的私密图片系统访问
- 前端显示出现500错误

## 识别旧格式图片

旧格式图片消息的特征：
- 消息内容以 `data:image/` 开头
- 包含大量base64编码数据
- 例如: `data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA...`

## 解决方案

### 1. 自动清理（推荐）

运行清理脚本删除旧格式图片消息：

```bash
# 在本地环境
python cleanup_base64_images.py

# 在Railway环境
railway run python cleanup_base64_images.py
```

### 2. 手动清理

如果需要手动清理，可以使用以下SQL：

```sql
-- 查询base64图片消息数量
SELECT COUNT(*) FROM messages WHERE content LIKE 'data:image/%';
SELECT COUNT(*) FROM customer_service_messages WHERE content LIKE 'data:image/%';

-- 删除base64图片消息
DELETE FROM messages WHERE content LIKE 'data:image/%';
DELETE FROM customer_service_messages WHERE content LIKE 'data:image/%';
```

## 用户通知

清理后，受影响的用户需要：
1. 重新发送图片
2. 新图片将使用私密图片系统存储
3. 旧图片无法恢复（因为base64数据已从数据库删除）

## 预防措施

系统已更新，现在会：
1. 拒绝显示base64格式的旧图片
2. 提示用户"此图片使用旧格式存储，请重新发送图片"
3. 所有新图片自动使用私密图片系统

## 新系统优势

✅ **私密图片系统**
- 图片存储在私有目录
- 只有聊天参与者可访问
- 图片永久有效
- 性能优化

✅ **数据库优化**
- 消息表只存储图片ID（约50字节）
- 而非整个base64数据（可能数KB到数MB）
- 查询速度显著提升

## 迁移统计

运行清理脚本后，您将看到：
- 删除的消息数量
- 释放的数据库空间
- 受影响的用户数量

## 常见问题

**Q: 删除后能恢复吗？**
A: 不能。建议在生产环境运行前先备份数据库。

**Q: 会影响新消息吗？**
A: 不会。只删除旧格式的图片消息。

**Q: 用户会收到通知吗？**
A: 系统会在用户尝试查看旧图片时提示重新发送。

## 执行清理

1. **备份数据库**（重要！）
2. 运行清理脚本
3. 验证结果
4. 通知用户（如需要）

