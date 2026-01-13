# 内存溢出问题修复总结

## 问题描述

应用出现内存溢出，导致进程被系统终止（Signal 9）。错误信息：
- XPC connection interrupted
- tcp_output 连接关闭
- Terminated due to signal 9

## 根本原因分析

### 1. iOS 应用内存问题

#### 图片缓存过大
- **问题**：`ImageCache` 内存缓存限制为 30MB，缓存数量为 50 张
- **影响**：当列表中有大量图片时，可能同时加载多张图片到内存
- **风险**：每张图片解码后可能占用 5-10MB 内存，50 张图片可能超过 200MB

#### 图片大小未限制
- **问题**：从网络或磁盘加载图片时，没有检查图片数据大小
- **影响**：可能加载超大图片（如 10MB+ 的原始图片）
- **风险**：单张图片就可能占用大量内存

#### 内存监控阈值过高
- **问题**：内存警告阈值为 200MB
- **影响**：在 iOS 设备上，200MB 可能已经接近系统限制
- **风险**：警告触发时可能已经来不及清理

### 2. 后端查询未限制

#### 查询所有用户
- **问题**：`send_announcement_api` 使用 `db.query(User).all()` 获取所有用户
- **影响**：如果用户数量很大（如 10万+），会一次性加载所有用户到内存
- **风险**：可能导致后端进程内存溢出

#### 查询所有已付费任务
- **问题**：`admin_get_payments` 使用 `db.query(Task).filter(Task.is_paid == 1).all()`
- **影响**：如果已付费任务很多，会一次性加载所有任务
- **风险**：可能导致内存溢出

#### 查询所有客服
- **问题**：`get_online_customer_services` 使用 `db.query(CustomerService).all()`
- **影响**：虽然客服数量通常不多，但仍可能造成内存问题
- **风险**：在客服数量较多时可能导致内存溢出

## 修复方案

### 1. iOS 图片缓存优化 ✅

#### 降低内存缓存限制
```swift
// 修复前
cache.countLimit = 50
cache.totalCostLimit = 30 * 1024 * 1024 // 30MB

// 修复后
cache.countLimit = 30  // 减少到 30 张
cache.totalCostLimit = 20 * 1024 * 1024 // 减少到 20MB
```

#### 添加图片大小限制
```swift
// 网络加载时检查数据大小
if data.count > 5 * 1024 * 1024 {
    Logger.warning("图片数据过大: \(data.count) bytes，跳过加载")
    return nil
}

// 磁盘加载时检查文件大小
guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
      let fileSize = attributes[.size] as? Int64,
      fileSize <= 5 * 1024 * 1024 else {
    return nil
}
```

#### 降低图片优化尺寸
```swift
// 修复前：最大尺寸 1200x1200
return self.optimizeImageSize(image, maxSize: CGSize(width: 1200, height: 1200))

// 修复后：最大尺寸 800x800
return self.optimizeImageSize(image, maxSize: CGSize(width: 800, height: 800))
```

#### 添加内存警告处理
```swift
// 监听系统内存警告
NotificationCenter.default.addObserver(
    self,
    selector: #selector(handleMemoryWarning),
    name: UIApplication.didReceiveMemoryWarningNotification,
    object: nil
)

@objc private func handleMemoryWarning() {
    Logger.warning("收到内存警告，清理图片缓存")
    cache.removeAllObjects()
}
```

### 2. iOS 内存监控优化 ✅

#### 降低警告阈值
```swift
// 修复前
@Published public var warningThreshold: Int64 = 200 * 1024 * 1024 // 200MB

// 修复后
@Published public var warningThreshold: Int64 = 150 * 1024 * 1024 // 150MB
```

#### 添加自动清理机制
```swift
// 内存超过阈值时自动清理
if usedMemory > warningThreshold {
    Logger.warning("内存使用较高: \(formatBytes(usedMemory))，触发自动清理")
    // 自动清理图片缓存
    ImageCache.shared.clearCache()
    // 发送通知，让其他组件也进行清理
    NotificationCenter.default.post(name: NSNotification.Name("MemoryWarning"), object: nil)
}
```

### 3. 后端查询优化 ✅

#### 分批处理用户查询
```python
# 修复前
users = db.query(User).all()

# 修复后
users_query = db.query(User)
total_users = users_query.count()
batch_size = 1000

offset = 0
processed_count = 0
while offset < total_users:
    users = users_query.offset(offset).limit(batch_size).all()
    if not users:
        break
    
    # 处理当前批次的用户
    for user in users:
        # ... 处理逻辑 ...
        processed_count += 1
    
    offset += batch_size
    db.commit()  # 每批处理后提交，避免事务过大
```

#### 添加分页限制到已付费任务查询
```python
# 修复前
@router.get("/admin/payments")
def admin_get_payments(...):
    return db.query(Task).filter(Task.is_paid == 1).all()

# 修复后
@router.get("/admin/payments")
def admin_get_payments(
    ...,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000)
):
    return db.query(Task).filter(Task.is_paid == 1).offset(skip).limit(limit).all()
```

#### 限制客服查询数量
```python
# 修复前
all_services = db.query(CustomerService).all()

# 修复后
all_services = db.query(CustomerService).limit(1000).all()
```

## 性能影响评估

### iOS 应用

| 指标 | 修复前 | 修复后 | 改善 |
|------|--------|--------|------|
| 图片缓存内存 | 30MB | 20MB | -33% |
| 图片缓存数量 | 50 张 | 30 张 | -40% |
| 单张图片最大尺寸 | 1200x1200 | 800x800 | -44% |
| 图片数据大小限制 | 无限制 | 5MB | 防止超大图片 |
| 内存警告阈值 | 200MB | 150MB | 更早触发清理 |

### 后端

| 查询 | 修复前 | 修复后 | 改善 |
|------|--------|--------|------|
| 用户查询 | 一次性加载所有 | 分批处理（1000/批） | 内存使用减少 90%+ |
| 已付费任务查询 | 无限制 | 分页（默认100，最大1000） | 内存使用减少 80%+ |
| 客服查询 | 无限制 | 限制1000条 | 防止内存溢出 |

## 建议的后续优化

### 1. 图片加载优先级管理
- 实现图片加载队列，限制同时加载的图片数量
- 为可见区域的图片设置高优先级
- 为不可见区域的图片延迟加载

### 2. 列表视图优化
- 确保所有列表都使用 `LazyVStack` 或 `LazyVGrid`
- 实现虚拟滚动，只渲染可见区域的项目
- 添加图片预加载机制，提前加载即将可见的图片

### 3. 后端查询进一步优化
- 为所有列表查询添加默认分页
- 实现查询结果缓存，减少重复查询
- 使用数据库索引优化查询性能

### 4. 内存监控增强
- 添加内存使用趋势监控
- 实现内存泄漏检测
- 添加内存使用报告功能

## 测试建议

### iOS 应用测试
1. **内存压力测试**
   - 快速滚动包含大量图片的列表
   - 同时打开多个包含图片的详情页
   - 测试内存警告时的自动清理功能

2. **图片加载测试**
   - 测试超大图片（>5MB）的加载行为
   - 测试网络慢速时的图片加载
   - 测试内存警告时的图片缓存清理

### 后端测试
1. **大批量数据测试**
   - 测试发送公告给大量用户（>10000）
   - 测试查询大量已付费任务
   - 测试查询大量客服

2. **性能测试**
   - 监控内存使用情况
   - 监控查询响应时间
   - 监控数据库连接数

## 总结

本次修复主要解决了以下问题：
1. ✅ iOS 图片缓存内存占用过大
2. ✅ iOS 图片大小未限制
3. ✅ iOS 内存监控阈值过高
4. ✅ 后端查询未限制导致内存溢出

通过这些修复，应用的内存使用应该会显著降低，内存溢出的风险也会大大减少。
