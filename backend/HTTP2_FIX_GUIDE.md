# HTTP/2协议错误修复指南

## 问题描述
出现 `ERR_HTTP2_PROTOCOL_ERROR` 错误，导致图片加载失败和API请求失败。

## 问题原因
1. **HTTP/2协议问题**：某些情况下HTTP/2连接不稳定
2. **网络环境**：代理服务器或CDN可能不支持HTTP/2
3. **浏览器兼容性**：某些浏览器对HTTP/2支持不完善
4. **服务器配置**：后端服务器HTTP/2配置问题

## 修复方案

### 1. 前端修复（已实施）

#### API请求配置：
```javascript
const api = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  timeout: 10000,
  headers: {
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache'
  },
  // 强制使用HTTP/1.1避免HTTP/2问题
  httpVersion: '1.1'
});
```

#### 图片加载优化：
```javascript
// 使用fetch + XMLHttpRequest双重备用
const loadImageWithFallback = async (src: string) => {
  try {
    // 首先尝试fetch
    const response = await fetch(src, {
      method: 'GET',
      credentials: 'include',
      headers: {
        'Accept': 'image/*',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Connection': 'keep-alive'  // 强制HTTP/1.1
      },
      signal: AbortSignal.timeout(10000)
    });
    
    if (response.ok) {
      const blob = await response.blob();
      return URL.createObjectURL(blob);
    }
  } catch (error) {
    // 如果fetch失败，使用XMLHttpRequest
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();
      xhr.open('GET', src, true);
      xhr.withCredentials = true;
      xhr.responseType = 'blob';
      xhr.timeout = 10000;
      // ... 处理逻辑
    });
  }
};
```

### 2. 后端修复建议

#### Nginx配置（如果使用）：
```nginx
# 禁用HTTP/2，强制使用HTTP/1.1
listen 443 ssl http2;
# 改为：
listen 443 ssl;

# 或者添加HTTP/2优化配置
http2_max_field_size 4k;
http2_max_header_size 16k;
http2_max_requests 1000;
```

#### FastAPI配置：
```python
# 在main.py中添加
from fastapi import FastAPI
import uvicorn

app = FastAPI()

# 启动时指定HTTP版本
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        http="h11",  # 强制使用HTTP/1.1
        reload=True
    )
```

### 3. Railway部署配置

#### 环境变量：
```bash
# 禁用HTTP/2
DISABLE_HTTP2=true

# 强制HTTP/1.1
FORCE_HTTP1=true

# 连接池配置
MAX_CONNECTIONS=100
KEEP_ALIVE_TIMEOUT=30
```

#### Railway配置：
```json
{
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "uvicorn main:app --host 0.0.0.0 --port $PORT --http h11",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 30
  }
}
```

### 4. 监控和诊断

#### 检查HTTP版本：
```bash
# 使用curl检查
curl -I -v https://your-app.railway.app/health

# 查看响应头
# 应该看到：HTTP/1.1 200 OK
```

#### 浏览器开发者工具：
1. 打开Network标签
2. 查看请求的Protocol列
3. 确认使用HTTP/1.1而不是h2

#### 日志监控：
```javascript
// 添加网络请求监控
const monitorNetwork = () => {
  const originalFetch = window.fetch;
  window.fetch = async (...args) => {
    try {
      const response = await originalFetch(...args);
      console.log('请求成功:', args[0], response.status);
      return response;
    } catch (error) {
      console.error('请求失败:', args[0], error);
      throw error;
    }
  };
};
```

### 5. 测试验证

#### 功能测试：
1. 发送图片消息
2. 查看图片是否正常显示
3. 检查控制台是否有HTTP/2错误

#### 性能测试：
1. 连续发送多条消息
2. 检查网络请求稳定性
3. 监控错误率

#### 兼容性测试：
1. 不同浏览器测试
2. 不同网络环境测试
3. 移动端测试

### 6. 回滚方案

如果修复导致问题：

1. **回滚前端代码**：
   ```bash
   git revert [commit-hash]
   ```

2. **恢复HTTP/2**：
   ```javascript
   // 移除httpVersion配置
   const api = axios.create({
     baseURL: API_BASE_URL,
     withCredentials: true
   });
   ```

3. **临时禁用图片加载**：
   ```javascript
   // 暂时使用普通img标签
   <img src={src} alt={alt} style={style} />
   ```

### 7. 长期解决方案

#### 选项1：修复HTTP/2配置
- 优化服务器HTTP/2设置
- 更新Nginx/代理配置
- 使用CDN支持HTTP/2

#### 选项2：混合协议
- 图片使用HTTP/1.1
- API使用HTTP/2
- 根据内容类型选择协议

#### 选项3：协议检测
- 自动检测HTTP版本支持
- 动态选择最佳协议
- 降级到HTTP/1.1

## 监控指标

### 关键指标
- HTTP/2错误率：< 1%
- 图片加载成功率：> 99%
- 网络请求成功率：> 99%

### 告警设置
- HTTP/2错误 > 10次/分钟
- 图片加载失败率 > 5%
- 网络超时率 > 2%

## 联系支持

如果问题持续存在：
1. 提供浏览器控制台错误截图
2. 提供网络请求详情
3. 提供服务器日志
4. 联系技术支持团队

---

**注意**：修复后请持续监控网络请求稳定性，确保问题得到彻底解决。

