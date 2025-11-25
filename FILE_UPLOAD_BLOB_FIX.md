# 文件上传 Blob 文件名问题修复

## 🔴 问题

当前端使用 Blob 对象上传文件时，`filename` 可能是 "blob"（没有扩展名），导致文件类型检测失败。

**错误信息：**
```
WARNING:app.routers:不支持的文件类型: , filename=blob, content_type=image/jpeg
```

## ✅ 解决方案

创建了通用的文件扩展名检测函数，支持从多个来源检测：
1. **filename**（优先）
2. **Content-Type**（如果 filename 无法获取扩展名）
3. **magic bytes**（如果前两者都失败）

## 📝 修复的文件

### 1. 创建了通用工具函数
- `backend/app/file_utils.py` - 新增文件
  - `detect_file_extension()` - 智能检测文件扩展名
  - `get_file_extension_from_upload()` - 从 UploadFile 检测扩展名

### 2. 修复了上传接口

#### `backend/app/routers.py`
- ✅ `/upload/public-image` - 已修复
- ✅ `/upload/image` - 已修复（通过 image_system）
- ✅ `/upload/file` - 已修复（通过 file_system）
- ✅ `/user/customer-service/chats/{chat_id}/files` - 已修复
- ✅ `/customer-service/chats/{chat_id}/files` - 已修复

#### `backend/app/flea_market_routes.py`
- ✅ `/upload-image` - 已修复

### 3. 修复了系统类

#### `backend/app/image_system.py`
- ✅ `get_file_extension()` - 现在支持从 Content-Type 和 magic bytes 检测
- ✅ `validate_image()` - 现在接受 content_type 参数
- ✅ `upload_image()` - 现在接受并传递 content_type 参数

#### `backend/app/file_system.py`
- ✅ `get_file_extension()` - 现在支持从 Content-Type 和 magic bytes 检测
- ✅ `validate_file()` - 现在接受 content_type 参数
- ✅ `upload_file()` - 现在接受并传递 content_type 参数

## 🔧 工作原理

### 检测优先级

1. **从 filename 获取扩展名**
   ```python
   Path("blob").suffix.lower()  # 返回 ""（空字符串）
   ```

2. **如果扩展名为空，从 Content-Type 检测**
   ```python
   content_type = "image/jpeg"  # → ".jpg"
   content_type = "image/png"   # → ".png"
   ```

3. **如果 Content-Type 也无法确定，从 magic bytes 检测**
   ```python
   content[:3] == b'\xff\xd8\xff'  # JPEG → ".jpg"
   content[:4] == b'\x89PNG'        # PNG → ".png"
   ```

## 📋 修复前后对比

### 修复前：
```python
file_extension = Path(image.filename).suffix.lower()  # "blob" → ""
if file_extension not in ALLOWED_EXTENSIONS:  # "" 不在列表中
    raise HTTPException(...)  # ❌ 报错
```

### 修复后：
```python
file_extension = get_file_extension_from_upload(image, content=content)
# "blob" + "image/jpeg" → ".jpg" ✅
if file_extension not in ALLOWED_EXTENSIONS:
    raise HTTPException(...)  # ✅ 正常工作
```

## ✅ 验证

修复后，即使 `filename=blob, content_type=image/jpeg` 也能正确识别为 JPEG 图片并上传成功。

## 🎯 支持的检测方式

### 图片格式：
- JPEG: `image/jpeg` 或 magic bytes `\xff\xd8\xff`
- PNG: `image/png` 或 magic bytes `\x89PNG`
- GIF: `image/gif` 或 magic bytes `GIF8`
- WEBP: `image/webp` 或 magic bytes `RIFF...WEBP`

### 文档格式：
- PDF: `application/pdf` 或 magic bytes `%PDF`
- DOC: `application/msword`
- DOCX: `application/vnd.openxmlformats-officedocument.wordprocessingml.document`
- TXT: `text/plain`

## ⚠️ 注意事项

1. **magic bytes 检测需要文件内容**
   - 确保在调用检测函数时已经读取了文件内容
   - 对于大文件，建议先读取前几个字节用于检测

2. **Content-Type 可能不准确**
   - 某些客户端可能发送错误的 Content-Type
   - 因此 magic bytes 检测作为最后的备用方案

3. **向后兼容**
   - 如果 filename 有正确的扩展名，仍然优先使用
   - 只有在无法从 filename 获取时才使用备用方法

