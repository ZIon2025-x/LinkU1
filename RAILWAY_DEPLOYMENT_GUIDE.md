# Railway部署指南 - 私密图片系统

## 部署步骤

### 1. 数据库迁移
Railway部署时会自动运行数据库迁移，添加`image_id`字段到`messages`表。

### 2. 环境变量配置
在Railway项目设置中添加以下环境变量：

```bash
# 图片访问密钥（必须更改）
IMAGE_ACCESS_SECRET=your-secure-image-secret-key-here

# 其他现有环境变量保持不变
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
```

### 3. 部署文件
确保以下文件已添加到项目中：
- `backend/auto_migrate.py` - 自动数据库迁移
- `backend/app/image_system.py` - 私密图片系统
- `backend/add_image_id_column.sql` - SQL迁移脚本（备用）

### 4. 目录权限
Railway会自动创建必要的目录：
- `/data/uploads/private_images/` - 私密图片存储

## 验证部署

### 1. 检查日志
部署后查看Railway日志，应该看到：
```
🚀 开始自动数据库迁移...
📊 连接到数据库: ...
🔍 检查image_id字段...
➕ 添加image_id字段到messages表...
📈 添加索引...
🎉 数据库迁移完成！
```

### 2. 测试图片上传
1. 登录应用
2. 进入消息页面
3. 点击图片按钮上传图片
4. 检查图片是否正常显示

### 3. 验证私密性
1. 复制图片URL
2. 在无痕窗口中打开
3. 应该显示403错误或需要登录

## 故障排除

### 如果迁移失败
1. 检查Railway日志中的错误信息
2. 手动运行SQL迁移：
   ```sql
   ALTER TABLE messages ADD COLUMN image_id VARCHAR(100) NULL;
   CREATE INDEX idx_messages_image_id ON messages(image_id);
   ```

### 如果图片上传失败
1. 检查`IMAGE_ACCESS_SECRET`环境变量是否设置
2. 检查目录权限
3. 查看应用日志

### 如果图片显示失败
1. 检查访问令牌生成
2. 验证用户权限
3. 检查图片文件是否存在

## 监控和维护

### 日志监控
- 图片上传成功/失败
- 访问令牌验证
- 数据库迁移状态

### 性能优化
- 定期清理过期图片（可选）
- 监控存储空间使用
- 优化图片压缩

## 安全注意事项

1. **更改默认密钥**：必须更改`IMAGE_ACCESS_SECRET`
2. **定期轮换密钥**：建议定期更新访问密钥
3. **监控访问日志**：检查异常访问模式
4. **备份重要数据**：定期备份图片和数据库

## 回滚方案

如果需要回滚到旧版本：
1. 在Railway中回滚到之前的部署
2. 或者手动删除`image_id`字段：
   ```sql
   ALTER TABLE messages DROP COLUMN image_id;
   ```

---

**注意**：此系统确保图片完全私密，只有聊天参与者才能访问，同时保证图片永久可见。
