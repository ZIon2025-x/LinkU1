# Railway文件存储配置指南

## 🚨 问题说明

在Railway上部署时，默认的文件存储方式存在问题：

1. **文件丢失**: Railway容器重启后，`uploads/` 目录中的所有文件都会丢失
2. **多实例问题**: 如果有多个Railway实例，文件不会在实例间同步
3. **临时存储**: Railway的文件系统是临时的，不适合持久化存储

## ✅ 解决方案

### 方案1: Railway Volume（推荐用于开发/测试）

#### 1. 在Railway控制台添加Volume
```bash
# 在Railway项目设置中添加Volume
Volume Name: uploads
Mount Path: /data/uploads
```

#### 2. 设置环境变量
```bash
# 在Railway环境变量中设置
RAILWAY_ENVIRONMENT=true
USE_CLOUD_STORAGE=false
BASE_URL=https://your-app.railway.app
```

#### 3. 重启应用
文件将保存在持久化卷中，重启后不会丢失。

### 方案2: AWS S3云存储（推荐用于生产环境）

#### 1. 创建AWS S3存储桶
```bash
# 在AWS控制台创建S3存储桶
Bucket Name: your-app-uploads
Region: us-east-1
```

#### 2. 设置AWS环境变量
```bash
# 在Railway环境变量中设置
USE_CLOUD_STORAGE=true
AWS_S3_BUCKET=your-app-uploads
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1
```

#### 3. 安装AWS SDK依赖
```bash
# 在requirements.txt中添加
boto3==1.26.137
```

### 方案3: 其他云存储服务

#### Cloudinary（图片专用）
```bash
# 环境变量
USE_CLOUD_STORAGE=true
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
```

#### Google Cloud Storage
```bash
# 环境变量
USE_CLOUD_STORAGE=true
GCS_BUCKET_NAME=your-bucket-name
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

## 🔧 当前配置状态

### 已修复的问题：
- ✅ 使用环境变量动态配置存储路径
- ✅ 支持Railway Volume挂载点
- ✅ 使用Config.BASE_URL生成正确的访问URL
- ✅ 添加云存储开关配置

### 当前文件存储位置：
- **本地开发**: `uploads/images/` 和 `uploads/files/`
- **Railway环境**: `/data/uploads/images/` 和 `/data/uploads/files/`

### 访问URL格式：
- **图片**: `https://api.link2ur.com/uploads/images/{filename}`
- **文件**: `https://api.link2ur.com/uploads/files/{filename}`

## 🚀 部署步骤

### 1. 使用Railway Volume（简单方案）
```bash
# 1. 在Railway控制台添加Volume
# 2. 设置环境变量
RAILWAY_ENVIRONMENT=true
USE_CLOUD_STORAGE=false
BASE_URL=https://api.link2ur.com

# 3. 重启应用
```

### 2. 使用AWS S3（生产推荐）
```bash
# 1. 创建AWS S3存储桶
# 2. 设置环境变量
USE_CLOUD_STORAGE=true
AWS_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1

# 3. 添加boto3依赖
# 4. 重启应用
```

## ⚠️ 注意事项

1. **文件大小限制**: 图片5MB，文件10MB
2. **安全限制**: 禁止上传危险文件类型
3. **访问权限**: 上传的文件是公开访问的
4. **成本考虑**: 云存储会产生费用

## 🔍 测试方法

### 1. 测试图片上传
```bash
curl -X POST https://api.link2ur.com/api/upload/image \
  -H "Content-Type: multipart/form-data" \
  -F "image=@test.jpg"
```

### 2. 测试文件上传
```bash
curl -X POST https://api.link2ur.com/api/upload/file \
  -H "Content-Type: multipart/form-data" \
  -F "file=@test.pdf"
```

### 3. 验证文件访问
```bash
curl https://api.link2ur.com/uploads/images/{filename}
curl https://api.link2ur.com/uploads/files/{filename}
```

## 📝 下一步计划

1. **实现AWS S3集成**（如果需要生产级存储）
2. **添加文件清理任务**（定期清理过期文件）
3. **实现文件访问权限控制**（私有文件支持）
4. **添加文件压缩和优化**（图片自动压缩）

## 🆘 故障排除

### 问题1: 文件上传失败
- 检查目录权限
- 确认环境变量设置正确
- 查看Railway日志

### 问题2: 文件访问404
- 确认BASE_URL设置正确
- 检查文件是否实际保存
- 验证静态文件服务配置

### 问题3: 文件丢失
- 确认使用了持久化存储
- 检查Volume挂载是否正确
- 考虑迁移到云存储
