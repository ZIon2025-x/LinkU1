# 私密图片系统设计文档

## 系统概述

全新的私密图片系统确保图片在发送者和接收者的聊天框中永久可见，但完全私密，外人无法通过URL直接访问。

## 核心特性

### ✅ 完全私密
- 图片存储在私有目录，不通过公开URL访问
- 需要访问令牌才能查看图片
- 只有聊天参与者才能获取访问令牌

### ✅ 永久可见
- 图片永不过期，聊天参与者随时可查看
- 访问令牌24小时有效，自动续期
- 支持图片重新生成访问URL

### ✅ 安全可靠
- 基于HMAC-SHA256的访问令牌验证
- 图片ID包含用户ID和时间戳，确保唯一性
- 文件内容验证，防止恶意文件上传

## 系统架构

### 后端组件

#### 1. PrivateImageSystem (`backend/app/image_system.py`)
```python
class PrivateImageSystem:
    - generate_image_id()      # 生成唯一图片ID
    - validate_image()         # 验证图片文件
    - save_image()            # 保存图片到私有目录
    - generate_access_token()  # 生成访问令牌
    - verify_access_token()    # 验证访问令牌
    - upload_image()          # 上传图片
    - get_image()             # 获取图片
    - generate_image_url()    # 生成访问URL
```

#### 2. 数据库模型更新
```sql
ALTER TABLE messages ADD COLUMN image_id VARCHAR(100) NULL;
```

#### 3. API端点
- `POST /api/upload/image` - 上传私密图片
- `GET /api/private-image/{image_id}` - 获取私密图片
- `POST /api/messages/generate-image-url` - 生成图片访问URL

### 前端组件

#### 1. PrivateImageDisplay (`frontend/src/components/Message/PrivateImageDisplay.tsx`)
- 专门用于显示私密图片
- 自动生成访问URL
- 支持错误重试和加载状态

#### 2. MessageInput 更新
- 支持图片文件选择
- 自动上传到私密图片系统
- 发送图片消息

#### 3. MessageList 更新
- 识别图片消息
- 使用PrivateImageDisplay显示图片

## 工作流程

### 图片上传流程
1. 用户选择图片文件
2. 前端验证文件类型和大小
3. 上传到 `/api/upload/image`
4. 后端生成唯一图片ID
5. 保存到私有目录
6. 返回图片ID给前端
7. 前端发送包含图片ID的消息

### 图片显示流程
1. 消息列表检测到图片消息
2. 调用 `/api/messages/generate-image-url`
3. 后端验证用户权限
4. 生成访问令牌和URL
5. 前端使用URL加载图片
6. 显示图片内容

### 访问控制流程
1. 用户请求图片访问
2. 验证访问令牌签名
3. 检查用户是否在聊天参与者列表中
4. 验证令牌时间戳（24小时有效期）
5. 返回图片文件

## 安全机制

### 1. 访问令牌设计
```
数据格式: image_id:user_id:participant1:participant2:timestamp:signature
签名算法: HMAC-SHA256(secret_key, data_string)
```

### 2. 权限验证
- 用户必须在聊天参与者列表中
- 访问令牌必须有效且未过期
- 图片ID必须存在且匹配

### 3. 文件安全
- 文件类型白名单验证
- 文件大小限制（5MB）
- 文件内容头验证
- 存储在私有目录

## 配置说明

### 环境变量
```bash
# 图片访问密钥（生产环境必须更改）
IMAGE_ACCESS_SECRET=your-image-secret-key-change-in-production

# 部署环境检测
RAILWAY_ENVIRONMENT=true
```

### 目录结构
```
uploads/private_images/          # 私密图片存储目录
├── user1_timestamp_random.jpg  # 图片文件
├── user2_timestamp_random.png
└── ...
```

## 使用示例

### 后端API使用
```python
from app.image_system import private_image_system

# 上传图片
result = private_image_system.upload_image(content, filename, user_id, db)

# 生成访问URL
url = private_image_system.generate_image_url(image_id, user_id, participants)

# 获取图片
response = private_image_system.get_image(image_id, user_id, token, db)
```

### 前端组件使用
```tsx
// 显示私密图片
<PrivateImageDisplay
  imageId="user1_1234567890_abc12345"
  currentUserId="user1"
  style={{ maxWidth: '200px' }}
/>

// 发送图片消息
const handleImageUpload = async (file: File) => {
  const formData = new FormData();
  formData.append('image', file);
  const response = await api.post('/api/upload/image', formData);
  const { image_id } = response.data;
  onSendImage(image_id);
};
```

## 部署步骤

### 1. 数据库迁移
```bash
cd backend
python migrations/add_image_id_to_messages.py
```

### 2. 环境变量配置
```bash
# 在Railway或.env文件中设置
IMAGE_ACCESS_SECRET=your-secure-secret-key
```

### 3. 目录权限
```bash
# 确保应用有写入权限
chmod 755 uploads/private_images/
```

### 4. 重启服务
```bash
# 重启后端服务使配置生效
```

## 监控和维护

### 日志监控
- 图片上传成功/失败
- 访问令牌验证结果
- 权限检查结果
- 文件操作错误

### 性能优化
- 图片文件定期清理（可选）
- 访问令牌缓存
- 图片压缩（可选）

### 安全审计
- 定期检查访问日志
- 监控异常访问模式
- 更新访问密钥

## 故障排除

### 常见问题

1. **图片上传失败**
   - 检查文件类型和大小
   - 验证目录权限
   - 查看服务器日志

2. **图片显示失败**
   - 检查访问令牌有效性
   - 验证用户权限
   - 确认图片文件存在

3. **权限错误**
   - 确认用户在聊天参与者列表中
   - 检查访问令牌签名
   - 验证时间戳

### 调试工具
```python
# 检查图片是否存在
from app.image_system import private_image_system
image_files = list(private_image_system.base_dir.glob(f"{image_id}.*"))

# 验证访问令牌
is_valid = private_image_system.verify_access_token(token, image_id, user_id)
```

## 未来扩展

### 功能增强
- 图片压缩和优化
- 多尺寸图片生成
- 图片水印
- 批量图片上传

### 安全增强
- 图片加密存储
- 更复杂的访问控制
- 审计日志记录
- 自动清理机制

---

**注意**：此系统设计确保了图片的完全私密性，只有聊天参与者才能访问，同时保证了图片的永久可见性。
