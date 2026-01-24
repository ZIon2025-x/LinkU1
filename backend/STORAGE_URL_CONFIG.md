# 图片存储 URL 配置指南

## 问题说明

如果图片 URL 在 1 小时后失效，通常是因为使用了 S3/R2 存储但没有配置 `public_url`，导致系统生成预签名 URL（有效期仅 1 小时）。

## 配置方法

### 方案 1：使用本地存储（默认，推荐）

本地存储使用 `FRONTEND_URL` 来生成图片 URL，URL 永久有效。

**配置步骤：**

1. 确保 `FRONTEND_URL` 环境变量已正确配置：
   ```bash
   FRONTEND_URL=https://www.link2ur.com
   ```

2. 确保前端服务器可以代理 `/uploads/` 请求到后端，或者后端直接提供静态文件服务。

3. 图片 URL 格式：`{FRONTEND_URL}/uploads/{path}`

**优点：**
- URL 永久有效
- 无需额外配置
- 适合中小型应用

**缺点：**
- 需要服务器存储空间
- 不适合大规模应用

---

### 方案 2：使用 AWS S3 存储

如果使用 AWS S3 存储，需要配置 `S3_PUBLIC_URL` 以生成永久 URL。

**配置步骤：**

1. 在 AWS S3 中创建存储桶并配置为公开访问（或使用 CloudFront CDN）

2. 配置环境变量：
   ```bash
   # 使用 S3 存储
   STORAGE_BACKEND=s3
   
   # S3 存储桶名称
   S3_BUCKET_NAME=your-bucket-name
   
   # ⚠️ 重要：配置公开访问 URL（永久 URL）
   # 方式 1：直接使用 S3 公开 URL
   S3_PUBLIC_URL=https://your-bucket-name.s3.amazonaws.com
   
   # 方式 2：使用 CloudFront CDN（推荐，更快）
   S3_PUBLIC_URL=https://your-cloudfront-domain.cloudfront.net
   
   # AWS 凭证
   AWS_ACCESS_KEY_ID=your-access-key-id
   AWS_SECRET_ACCESS_KEY=your-secret-access-key
   ```

3. 图片 URL 格式：`{S3_PUBLIC_URL}/{path}`

**S3 存储桶公开访问配置：**

1. 在 S3 控制台中，选择存储桶
2. 进入 "Permissions"（权限）标签
3. 编辑 "Bucket policy"（存储桶策略），添加：
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "PublicReadGetObject",
         "Effect": "Allow",
         "Principal": "*",
         "Action": "s3:GetObject",
         "Resource": "arn:aws:s3:::your-bucket-name/*"
       }
     ]
   }
   ```

**使用 CloudFront CDN（推荐）：**

1. 在 AWS CloudFront 中创建分发
2. 源设置为 S3 存储桶
3. 将 `S3_PUBLIC_URL` 设置为 CloudFront 域名
4. 优点：更快的访问速度，全球 CDN 加速

---

### 方案 3：使用 Cloudflare R2 存储

Cloudflare R2 兼容 S3 API，配置方式类似。

**配置步骤：**

1. 在 Cloudflare 中创建 R2 存储桶

2. 配置环境变量：
   ```bash
   # 使用 R2 存储
   STORAGE_BACKEND=r2
   
   # R2 存储桶名称
   R2_BUCKET_NAME=your-bucket-name
   
   # ⚠️ 重要：配置公开访问 URL（永久 URL）
   # R2 公开 URL 格式：https://pub-{account-id}.r2.dev/{bucket-name}
   # 或者使用自定义域名
   R2_PUBLIC_URL=https://pub-xxxxx.r2.dev/your-bucket-name
   # 或
   R2_PUBLIC_URL=https://your-custom-domain.com
   
   # R2 端点 URL（通常不需要修改）
   R2_ENDPOINT_URL=https://xxxxx.r2.cloudflarestorage.com
   
   # R2 凭证
   R2_ACCESS_KEY_ID=your-r2-access-key-id
   R2_SECRET_ACCESS_KEY=your-r2-secret-access-key
   ```

3. 在 Cloudflare 中配置 R2 存储桶的公开访问：
   - 进入 R2 存储桶设置
   - 启用 "Public Access"（公开访问）
   - 配置自定义域名（可选，推荐）

4. 图片 URL 格式：`{R2_PUBLIC_URL}/{path}`

---

## 检查当前配置

### 1. 检查存储后端类型

```bash
# 在服务器上运行
echo $STORAGE_BACKEND
# 如果为空，则使用默认的本地存储
```

### 2. 检查 FRONTEND_URL 配置

```bash
echo $FRONTEND_URL
# 应该输出：https://www.link2ur.com
```

### 3. 检查 S3/R2 配置

```bash
# S3 配置
echo $S3_PUBLIC_URL
echo $S3_BUCKET_NAME

# R2 配置
echo $R2_PUBLIC_URL
echo $R2_BUCKET_NAME
```

### 4. 查看后端日志

如果使用 S3/R2 但没有配置 `public_url`，后端会记录警告日志：
```
S3 存储未配置 public_url，生成的预签名 URL 将在 1 小时后过期。
建议配置 S3_PUBLIC_URL 或 R2_PUBLIC_URL 环境变量以生成永久 URL。
```

---

## 推荐配置（根据你的情况）

根据你的代码，当前默认使用**本地存储**，建议：

1. **确保 `FRONTEND_URL` 正确配置**：
   ```bash
   FRONTEND_URL=https://www.link2ur.com
   ```

2. **确保前端可以访问 `/uploads/` 路径**：
   - 如果使用 Vercel，需要在 `vercel.json` 中配置代理
   - 或者后端直接提供静态文件服务

3. **如果图片 URL 仍然失效，检查**：
   - 数据库中存储的 URL 是否包含正确的域名
   - 文件是否真的存在于服务器上
   - 使用 `backend/scripts/cleanup_invalid_image_urls.py` 检查无效 URL

---

## 迁移现有 URL

如果之前使用了错误的 URL，可以使用脚本批量更新：

```bash
cd backend
python scripts/cleanup_invalid_image_urls.py --verbose --fix
```

---

## 环境变量配置示例

### Railway 部署（本地存储）

```bash
FRONTEND_URL=https://www.link2ur.com
STORAGE_BACKEND=local  # 或不设置（默认）
```

### Railway 部署（S3 存储）

```bash
STORAGE_BACKEND=s3
S3_BUCKET_NAME=linku-uploads
S3_PUBLIC_URL=https://linku-uploads.s3.amazonaws.com
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
```

### Railway 部署（R2 存储）

```bash
STORAGE_BACKEND=r2
R2_BUCKET_NAME=linku-uploads
R2_PUBLIC_URL=https://pub-xxxxx.r2.dev/linku-uploads
R2_ENDPOINT_URL=https://xxxxx.r2.cloudflarestorage.com
R2_ACCESS_KEY_ID=your-key
R2_SECRET_ACCESS_KEY=your-secret
```

---

## 注意事项

1. **不要同时配置多个存储后端**，只设置一个
2. **`public_url` 必须以 `https://` 开头**，不要以斜杠结尾
3. **配置后需要重启后端服务**才能生效
4. **如果使用 CDN**，确保 CDN 正确配置了缓存策略
