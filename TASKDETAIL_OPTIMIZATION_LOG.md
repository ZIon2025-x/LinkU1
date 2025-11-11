# TaskDetail 全栈优化日志

## 📋 优化概述

本文档记录了 `TaskDetail.tsx`、`TaskDetailModal.tsx` 组件以及相关后端API的性能、响应速度和安全性优化计划。

**优化范围：**
- **前端**：React组件优化、API调用优化、图片加载优化、安全性增强
- **后端**：数据库查询优化、缓存策略、API响应优化、安全性增强

**优化目标：**
- 提升组件渲染性能，减少不必要的重渲染
- 优化API调用，减少网络请求时间
- 优化数据库查询，减少响应时间
- 增强安全性，防止XSS攻击和SQL注入
- 改善用户体验，提升响应速度

---

## 🔍 当前问题分析

### 1. 性能问题

#### 1.1 组件过大
- **问题**：`TaskDetail.tsx` 有 3113 行，`TaskDetailModal.tsx` 有 2549 行
- **影响**：难以维护，容易导致性能问题
- **优先级**：中

#### 1.2 缺少 React 性能优化
- **问题**：
  - 未使用 `React.memo` 包装组件
  - 未使用 `useMemo` 缓存计算结果
  - 未使用 `useCallback` 缓存函数引用
  - 大量内联样式对象在每次渲染时重新创建
- **影响**：导致不必要的组件重渲染，性能下降
- **优先级**：高

#### 1.3 useEffect 依赖问题
- **问题**：
  - `loadTaskData` 函数未使用 `useCallback`，导致 useEffect 依赖不稳定
  - 多个 useEffect 可能触发不必要的重新执行
- **影响**：可能导致无限循环或频繁的API调用
- **优先级**：高

### 2. API 调用优化

#### 2.1 串行请求
- **问题**：任务数据和用户信息串行加载
  ```typescript
  // 当前实现
  const res = await api.get(`/api/tasks/${taskId}`);
  // ... 然后才加载用户信息
  const userData = await fetchCurrentUser();
  ```
- **影响**：增加总加载时间
- **优先级**：高

#### 2.2 缺少请求缓存 ⚠️ P1 优先级
- **问题**：
  - 翻译结果没有缓存，重复翻译相同内容
  - 任务详情没有短期缓存
- **影响**：浪费网络资源，用户体验差
- **优先级**：中
- **建议升级**：翻译缓存持久化到 sessionStorage（见阶段二 2.2 或阶段十二）

#### 2.3 错误处理不完善
- **问题**：部分API调用缺少错误边界处理
- **影响**：可能导致应用崩溃
- **优先级**：中

### 3. 图片加载优化

#### 3.1 未使用懒加载
- **问题**：`TaskDetailModal.tsx` 中的图片使用普通 `<img>` 标签
- **影响**：所有图片立即加载，影响首屏性能
- **优先级**：中

#### 3.2 缺少图片优化
- **问题**：
  - 没有使用缩略图
  - 没有渐进式加载
  - 缺少占位符优化
- **影响**：加载体验差
- **优先级**：低

### 4. 安全性问题

#### 4.1 XSS 防护不足
- **问题**：
  - 用户输入内容（如任务描述、留言）直接渲染
  - 缺少 HTML 转义处理
- **影响**：存在 XSS 攻击风险
- **优先级**：高

#### 4.2 输入验证不足
- **问题**：
  - 前端验证不够严格
  - 缺少输入长度限制提示
- **影响**：可能导致无效请求或安全问题
- **优先级**：中

---

## 🎯 优化方案

### 阶段一：核心性能优化（高优先级）

#### 1.1 使用 React.memo 优化组件
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**步骤**：
1. 将组件导出改为使用 `React.memo` 包装
2. 创建自定义比较函数（如果需要）

**代码示例**：
```typescript
// 优化前
export default TaskDetailModal;

// 优化后
export default React.memo(TaskDetailModal, (prevProps, nextProps) => {
  return prevProps.isOpen === nextProps.isOpen && 
         prevProps.taskId === nextProps.taskId &&
         prevProps.onClose === nextProps.onClose;
});
```

**预期效果**：减少 30-50% 的不必要重渲染

---

#### 1.2 使用 useCallback 优化函数
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**需要优化的函数**：
- `loadTaskData`
- `handleTranslateTitle`
- `handleTranslateDescription`
- `handleSubmitApplication`
- `handleApproveApplication`
- `handleRejectApplication`
- 其他事件处理函数

**代码示例**：
```typescript
// 优化前
const loadTaskData = async () => {
  // ...
};

// 优化后
const loadTaskData = useCallback(async () => {
  if (!taskId) return;
  // ...
}, [taskId, t]);
```

**预期效果**：减少函数重新创建，稳定 useEffect 依赖

---

#### 1.3 使用 useMemo 优化计算
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**需要缓存的计算**：
- `canViewTask` 结果
- `canAcceptTask` 结果
- `canReview` 结果
- `hasUserReviewed` 结果
- 状态文本转换（`getStatusText`, `getTaskLevelText`）
- 样式对象（特别是复杂的内联样式）

**代码示例**：
```typescript
// 优化前
const canShowApplyButton = (task.status === 'open' || task.status === 'taken') && 
  canViewTask(user, task) && ...

// 优化后
const canShowApplyButton = useMemo(() => {
  return (task.status === 'open' || task.status === 'taken') && 
    canViewTask(user, task) && ...
}, [task, user, userApplication, hasApplied]);
```

**预期效果**：减少重复计算，提升渲染性能

---

#### 1.4 优化内联样式对象
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**步骤**：
1. 将常用的样式对象提取为常量
2. 使用 `useMemo` 缓存动态样式对象

**代码示例**：
```typescript
// 优化前
<div style={{
  position: 'fixed',
  top: 0,
  left: 0,
  // ... 每次渲染都创建新对象
}}>

// 优化后
const MODAL_OVERLAY_STYLE = {
  position: 'fixed' as const,
  top: 0,
  left: 0,
  // ...
};

// 或使用 useMemo
const modalStyle = useMemo(() => ({
  position: 'fixed' as const,
  // ...
}), [/* 依赖项 */]);
```

**预期效果**：减少对象创建，提升性能

---

### 阶段二：API 调用优化（高优先级）

#### 2.1 并行加载数据
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**步骤**：
1. 使用 `Promise.allSettled` 并行加载任务数据和用户信息
2. 非关键数据（如评价）异步加载，不阻塞主流程

**代码示例**：
```typescript
// 优化前
const loadTaskData = async () => {
  const res = await api.get(`/api/tasks/${taskId}`);
  setTask(res.data);
  const userData = await fetchCurrentUser();
  setUser(userData);
};

// 优化后
const loadTaskData = useCallback(async () => {
  if (!taskId) return;
  
  setLoading(true);
  setError('');
  
  try {
    // 并行加载
    const [taskRes, userData] = await Promise.allSettled([
      api.get(`/api/tasks/${taskId}`),
      fetchCurrentUser().catch(() => null)
    ]);
    
    if (taskRes.status === 'fulfilled') {
      setTask(taskRes.value.data);
      // 非关键数据异步加载
      if (taskRes.value.data.status === 'completed') {
        loadTaskReviews().catch(err => console.error('加载评价失败:', err));
      }
    }
    
    if (userData.status === 'fulfilled' && userData.value) {
      setUser(userData.value);
    }
  } catch (error) {
    // 错误处理
  } finally {
    setLoading(false);
  }
}, [taskId, t]);
```

**预期效果**：减少 30-50% 的数据加载时间

---

#### 2.2 添加翻译缓存
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**步骤**：
1. 创建翻译缓存 Map
2. 在翻译前检查缓存
3. 翻译后存储到缓存

**代码示例**：
```typescript
// 翻译缓存
const translationCache = new Map<string, string>();

const getTranslationCacheKey = (text: string, targetLang: string, sourceLang: string): string => {
  return `${text}::${targetLang}::${sourceLang}`;
};

const handleTranslateTitle = useCallback(async () => {
  if (!task || !task.title) return;
  
  if (translatedTitle) {
    setTranslatedTitle(null);
    return;
  }
  
  setIsTranslatingTitle(true);
  try {
    const textLang = detectTextLanguage(task.title);
    if (textLang === language) {
      setTranslatedTitle(null);
      return;
    }
    
    const targetLang = language;
    const cacheKey = getTranslationCacheKey(task.title, targetLang, textLang);
    
    // 检查缓存
    if (translationCache.has(cacheKey)) {
      setTranslatedTitle(translationCache.get(cacheKey)!);
      setIsTranslatingTitle(false);
      return;
    }
    
    const translated = await translate(task.title, targetLang, textLang);
    setTranslatedTitle(translated);
    // 缓存结果
    translationCache.set(cacheKey, translated);
  } catch (error) {
    // 错误处理
  } finally {
    setIsTranslatingTitle(false);
  }
}, [task, translatedTitle, language, translate]);
```

**预期效果**：重复翻译请求减少 100%，响应速度提升 80%+

---

#### 2.3 优化 useEffect 依赖
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**步骤**：
1. 将所有函数用 `useCallback` 包装
2. 确保 useEffect 依赖数组包含所有使用的值
3. 使用 ESLint 规则检查依赖

**需要修复的 useEffect**：
```typescript
// 优化前
useEffect(() => {
  if (isOpen && taskId) {
    loadTaskData();
  }
}, [isOpen, taskId]); // loadTaskData 未在依赖中

// 优化后
const loadTaskData = useCallback(async () => {
  // ...
}, [taskId, t]);

useEffect(() => {
  if (isOpen && taskId) {
    loadTaskData();
  }
}, [isOpen, taskId, loadTaskData]); // 包含所有依赖
```

**预期效果**：避免无限循环，确保依赖正确

---

### 阶段三：图片加载优化（中优先级）

#### 3.1 使用 LazyImage 组件
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**步骤**：
1. 导入 `LazyImage` 组件
2. 替换所有 `<img>` 标签为 `<LazyImage>`

**代码示例**：
```typescript
// 优化前
<img
  src={imageUrl}
  alt={`任务图片 ${index + 1}`}
  loading="lazy"
/>

// 优化后
<LazyImage
  src={imageUrl}
  alt={`任务图片 ${index + 1}`}
  style={{
    width: '100%',
    height: '100%',
    objectFit: 'cover'
  }}
/>
```

**预期效果**：首屏加载时间减少 30-40%，带宽使用减少 50-60%

---

### 阶段四：安全性增强（高优先级）

#### 4.1 XSS 防护 ⚠️ P0 优先级
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**问题**：仅依赖 React 自动转义不够，需要完整的 XSS 防护策略

**完整防护方案**：

**1. 安装 DOMPurify（用于富文本/Markdown 清洗）**：
```bash
npm install dompurify
npm install --save-dev @types/dompurify
```

**2. 创建安全渲染组件**：
```typescript
// frontend/src/components/SafeContent.tsx
import React from 'react';
import DOMPurify from 'dompurify';

// ⚠️ 重要：DOMPurify hook 配置放在模块级，只初始化一次
// 避免在组件渲染时重复注册 hook
let hookInitialized = false;

function initializeDOMPurifyHooks() {
  if (hookInitialized) return;
  
  DOMPurify.addHook('uponSanitizeElement', (node, data) => {
    // 处理链接：强制安全协议和 rel 属性
    if (data.tagName === 'a') {
      const href = node.getAttribute('href');
      if (href) {
        // 只允许 http/https/mailto 协议
        if (!/^(https?|mailto):/i.test(href)) {
          node.removeAttribute('href');
        }
        
        // 如果是外部链接或 target=_blank，强制添加 rel
        const target = node.getAttribute('target');
        if (target === '_blank' || href.startsWith('http')) {
          node.setAttribute('rel', 'noopener noreferrer nofollow ugc');
        }
      }
    }
    
    // 处理图片：限制 src 协议
    if (data.tagName === 'img') {
      const src = node.getAttribute('src');
      if (src && !/^(https?|data):/i.test(src)) {
        node.removeAttribute('src');
      }
    }
  });
  
  hookInitialized = true;
}

// 模块加载时初始化
if (typeof window !== 'undefined') {
  initializeDOMPurifyHooks();
}

interface SafeContentProps {
  content: string;
  allowHtml?: boolean;  // 是否允许HTML（如Markdown渲染后）
  className?: string;
}

const SafeContent: React.FC<SafeContentProps> = ({ 
  content, 
  allowHtml = false,
  className 
}) => {
  if (!content) return null;
  
  if (allowHtml) {
    // 确保 hook 已初始化（双重检查）
    if (typeof window !== 'undefined') {
      initializeDOMPurifyHooks();
    }
    
    // 富文本/Markdown 内容：使用 DOMPurify 白名单清洗
    const sanitized = DOMPurify.sanitize(content, {
      ALLOWED_TAGS: [
        'p', 'br', 'strong', 'em', 'u', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'ul', 'ol', 'li', 'blockquote', 'code', 'pre', 'a', 'img'
      ],
      ALLOWED_ATTR: {
        'a': ['href', 'title', 'target'],  // 允许 target（但会通过 hook 强制 rel）
        'img': ['src', 'alt', 'title'],
        '*': ['class']  // 所有标签允许 class
      },
      ALLOW_DATA_ATTR: false,  // 禁止 data-* 属性
      FORBID_TAGS: ['script', 'iframe', 'object', 'embed', 'form'],
      FORBID_ATTR: ['onerror', 'onload', 'onclick', 'onmouseover'],
      ADD_ATTR: ['target'],  // 允许 target 属性（hook 会处理）
    });
    
    return (
      <div 
        className={className}
        dangerouslySetInnerHTML={{ __html: sanitized }}
      />
    );
  } else {
    // 纯文本内容：React 自动转义（默认安全）
    return <div className={className}>{content}</div>;
  }
};

export default SafeContent;
```

**3. 使用安全组件**：
```typescript
// 在 TaskDetailModal.tsx 中
import SafeContent from './SafeContent';

// 任务描述（纯文本，React自动转义）
<SafeContent content={task.description} />

// 如果有Markdown渲染（需要HTML）
<SafeContent 
  content={markdownToHtml(task.description)} 
  allowHtml={true}
/>
```

**4. 添加 Content Security Policy (CSP) - 严格策略**：
```html
<!-- frontend/public/index.html -->
<!-- 
  注意：CSP 应该通过 HTTP 响应头设置，而不是 meta 标签
  这里仅作为示例，实际应在后端或 CDN 配置
-->
<meta 
  http-equiv="Content-Security-Policy" 
  content="
    default-src 'self';
    script-src 'self' 'nonce-{SERVER_NONCE}' 'strict-dynamic';
    style-src 'self' 'unsafe-inline';  /* 允许内联样式（某些框架需要） */
    img-src 'self' data: https:;
    font-src 'self' data:;
    connect-src 'self' https://api.example.com wss:;
    object-src 'none';  /* 禁止 object/embed */
    base-uri 'self';  /* 限制 base 标签 */
    form-action 'self';  /* 限制表单提交 */
    frame-ancestors 'none';  /* 防止点击劫持 */
    upgrade-insecure-requests;  /* 自动升级 HTTP 到 HTTPS */
  "
/>
```

**后端设置 CSP 响应头（推荐）**：
```python
# backend/app/middleware/security.py
from fastapi import Request

async def security_headers_middleware(request: Request, call_next):
    """安全响应头中间件
    
    ⚠️ 注意：SPA 应用建议避免内联脚本，使用外部 JS 文件
    这样就不需要 nonce，CSP 更简单且安全
    """
    response = await call_next(request)
    
    # CSP 策略（SPA 场景，避免内联脚本）
    csp = (
        "default-src 'self'; "
        "script-src 'self' 'strict-dynamic'; "  # 不使用 nonce，避免内联脚本
        "style-src 'self'; "  # 逐步移除 'unsafe-inline'，使用外部样式或 CSS-in-JS
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self' https://api.example.com wss:; "
        "object-src 'none'; "
        "base-uri 'self'; "
        "form-action 'self'; "
        "frame-ancestors 'none'; "
        "upgrade-insecure-requests; "
        "report-uri /api/csp-report;"  # CSP 违规报告
    )
    
    response.headers["Content-Security-Policy"] = csp
    response.headers["Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    # ⚠️ X-XSS-Protection 已废弃，移除
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    return response

# 在 main.py 中注册
app.middleware("http")(security_headers_middleware)

# CSP 违规报告端点
@router.post("/api/csp-report")
async def csp_report(report: dict):
    """接收 CSP 违规报告"""
    logger.warning(f"CSP violation: {report}")
    # 可以发送到监控系统
    return {"status": "ok"}
```

**5. 后端二次校验**：
```python
# backend/app/validators.py
import re
from html import escape

def sanitize_html(content: str, allow_html: bool = False) -> str:
    """后端HTML清洗"""
    if not allow_html:
        # 纯文本：转义所有HTML
        return escape(content)
    
    # 允许HTML：使用白名单
    # ⚠️ 注意：allowed_tags 和 allowed_attrs 必须一致
    # 如果允许 img 标签，必须在 allowed_tags 中包含 'img'
    from bleach import clean
    
    allowed_tags = ['p', 'br', 'strong', 'em', 'u', 'a', 'ul', 'ol', 'li', 'img']  # 包含 img
    allowed_attrs = {
        'a': ['href', 'title'],
        'img': ['src', 'alt', 'title']  # img 标签的属性
    }
    
    return clean(
        content,
        tags=allowed_tags,
        attributes=allowed_attrs,
        strip=True
    )

# 在接收用户输入时使用
@router.post("/tasks/{task_id}/apply")
def apply_task(
    task_id: int,
    message: str = Body(...),
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # 清洗用户输入
    sanitized_message = sanitize_html(message, allow_html=False)
    # ...
```

**6. 输入验证增强**：
```typescript
// frontend/src/utils/inputValidation.ts
export const validateInput = {
  // 检查危险模式
  hasDangerousPatterns: (text: string): boolean => {
    const dangerous = [
      /<script/i,
      /javascript:/i,
      /on\w+\s*=/i,  // onclick=, onerror= 等
      /data:text\/html/i,
      /vbscript:/i,
      /<iframe/i,
      /<object/i,
      /<embed/i
    ];
    return dangerous.some(pattern => pattern.test(text));
  },
  
  // 验证并清理
  sanitize: (text: string, maxLength: number = 1000): string | null => {
    if (!text || text.trim().length === 0) return null;
    if (text.length > maxLength) return null;
    if (validateInput.hasDangerousPatterns(text)) {
      console.warn('检测到危险输入模式');
      return null;
    }
    return text.trim();
  }
};
```

**依赖安装**：
```bash
# 前端
npm install dompurify
npm install --save-dev @types/dompurify

# 后端
pip install bleach
```

**预期效果**：
- 完整的 XSS 防护（前端 + 后端双重保护）
- 支持富文本/Markdown 安全渲染
- CSP 策略防止代码注入
- 白名单机制确保只允许安全标签

---

#### 4.2 输入验证增强
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**需要验证的输入**：
- 申请留言（`applyMessage`）
- 评价评论（`reviewComment`）
- 留言内容（`messageContent`）
- 议价金额（`negotiatedPrice`, `messageNegotiatedPrice`）

**代码示例**：
```typescript
const validateInput = {
  message: (text: string, maxLength: number = 1000): boolean => {
    if (!text || text.trim().length === 0) return false;
    if (text.length > maxLength) return false;
    // 检查危险字符
    const dangerousPatterns = /<script|javascript:|onerror=/i;
    return !dangerousPatterns.test(text);
  },
  
  price: (price: number | undefined): boolean => {
    if (price === undefined) return true; // 可选
    if (price < 0) return false;
    if (price > 1000000) return false; // 最大限制
    return !isNaN(price);
  }
};

// 使用
const handleSubmitApplication = async () => {
  if (!validateInput.message(applyMessage, 1000)) {
    alert('留言内容无效，请检查输入');
    return;
  }
  // ...
};
```

**预期效果**：防止无效输入，提升安全性

---

### 阶段五：错误边界与并发渲染 ⚠️ P0 优先级

#### 5.1 添加错误边界组件
**文件**：`frontend/src/components/ErrorBoundary.tsx` (新建)

**问题**：缺少错误边界，组件错误会导致整个应用崩溃

**实现方案**：
```typescript
// frontend/src/components/ErrorBoundary.tsx
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
  onError?: (error: Error, errorInfo: ErrorInfo) => void;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('ErrorBoundary捕获错误:', error, errorInfo);
    
    // 上报错误到监控系统
    if (this.props.onError) {
      this.props.onError(error, errorInfo);
    }
    
    // 可以发送到错误追踪服务
    // logErrorToService(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }
      
      return (
        <div style={{
          padding: '40px',
          textAlign: 'center',
          background: '#fee',
          borderRadius: '8px',
          margin: '20px'
        }}>
          <h2>😕 出错了</h2>
          <p>页面加载时出现问题，请刷新重试</p>
          <button
            onClick={() => {
              this.setState({ hasError: false, error: null });
              window.location.reload();
            }}
            style={{
              padding: '10px 20px',
              background: '#3b82f6',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer'
            }}
          >
            刷新页面
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

export default ErrorBoundary;
```

**使用方式**：
```typescript
// 在 TaskDetail.tsx 中
import ErrorBoundary from '../components/ErrorBoundary';

const TaskDetail: React.FC = () => {
  return (
    <ErrorBoundary
      fallback={<div>任务详情加载失败</div>}
      onError={(error, errorInfo) => {
        // 上报错误
        console.error('TaskDetail错误:', error);
      }}
    >
      {/* 原有内容 */}
    </ErrorBoundary>
  );
};
```

---

#### 5.2 添加 Suspense 和 Skeleton 加载
**文件**：`frontend/src/components/TaskDetailSkeleton.tsx` (新建)

**实现方案**：
```typescript
// frontend/src/components/TaskDetailSkeleton.tsx
import React from 'react';

const TaskDetailSkeleton: React.FC = () => {
  return (
    <div style={{ padding: '40px' }}>
      {/* 标题骨架 */}
      <div style={{
        height: '32px',
        width: '60%',
        background: '#e5e7eb',
        borderRadius: '4px',
        marginBottom: '20px',
        animation: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      }} />
      
      {/* 信息卡片骨架 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '20px', marginBottom: '32px' }}>
        {[1, 2, 3, 4].map(i => (
          <div
            key={i}
            style={{
              height: '100px',
              background: '#f3f4f6',
              borderRadius: '12px',
              animation: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
            }}
          />
        ))}
      </div>
      
      {/* 描述骨架 */}
      <div style={{
        height: '200px',
        background: '#f3f4f6',
        borderRadius: '12px',
        marginBottom: '20px',
        animation: 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      }} />
      
      <style>{`
        @keyframes pulse {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.5; }
        }
      `}</style>
    </div>
  );
};

export default TaskDetailSkeleton;
```

**使用 Suspense**：
```typescript
import { Suspense, lazy } from 'react';
import TaskDetailSkeleton from '../components/TaskDetailSkeleton';

// 懒加载组件
const TaskDetailContent = lazy(() => import('./TaskDetailContent'));

const TaskDetail: React.FC = () => {
  return (
    <ErrorBoundary>
      <Suspense fallback={<TaskDetailSkeleton />}>
        <TaskDetailContent />
      </Suspense>
    </ErrorBoundary>
  );
};
```

---

#### 5.3 使用 useTransition 优化非关键渲染
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**问题**：评价、大图、翻译等非关键操作可能阻塞主交互

**实现方案**：
```typescript
import { useTransition } from 'react';

const TaskDetailModal: React.FC<TaskDetailModalProps> = ({ isOpen, onClose, taskId }) => {
  // ⚠️ 注意：不能同时 import startTransition 和解构，避免命名冲突
  const [isPending, startTransition] = useTransition();
  const [reviews, setReviews] = useState<any[]>([]);
  const [showReviews, setShowReviews] = useState(false);
  
  // 加载评价 - 使用低优先级
  // ⚠️ 注意：startTransition 应使用 promise 链，而不是 async/await
  const loadTaskReviews = useCallback(() => {
    startTransition(() => {
      if (!taskId) return;
      getTaskReviews(taskId)
        .then(setReviews)
        .catch(error => {
          console.error('加载评价失败:', error);
        });
    });
  }, [taskId]);
  
  // 翻译 - 使用低优先级
  const handleTranslateTitle = useCallback(() => {
    startTransition(() => {
      translateText(task.title, language)
        .then(setTranslatedTitle)
        .catch(error => {
          console.error('翻译失败:', error);
        });
    });
  }, [task.title, language]);
  
  // 或者只使用独立的 startTransition（不需要 isPending）
  // import { startTransition } from 'react';
  // startTransition(() => { /* ... */ });
  
  return (
    <div>
      {/* 主内容 */}
      <div>
        {/* 关键交互内容 */}
      </div>
      
      {/* 非关键内容 - 显示加载状态 */}
      {isPending && (
        <div style={{ opacity: 0.6 }}>
          {/* 加载指示器 */}
        </div>
      )}
      
      {/* 评价区域 */}
      {showReviews && (
        <div>
          {reviews.map(review => (
            <ReviewItem key={review.id} review={review} />
          ))}
        </div>
      )}
    </div>
  );
};
```

**预期效果**：
- 错误不会导致整个应用崩溃
- 加载状态更友好
- 非关键操作不阻塞主交互
- 提升用户体验流畅度

---

### 阶段六：交互性能优化（高优先级）⚡️ 让点击反应更快

#### 6.1 乐观更新（Optimistic Updates）
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**问题**：用户点击按钮后需要等待 API 响应才能看到反馈，体验差

**实现方案**：
```typescript
// 优化前：等待 API 响应
const handleTakeTask = async () => {
  setActionLoading(true);
  try {
    await takeTask(taskId);
    // 用户需要等待这里完成才能看到反馈
    const res = await api.get(`/api/tasks/${taskId}`);
    setTask(res.data);
  } finally {
    setActionLoading(false);
  }
};

// 优化后：乐观更新 - 立即更新 UI，后台同步
const handleTakeTask = async () => {
  if (!task || !user) return;
  
  // 1. 立即更新 UI（乐观更新）
  const previousTask = { ...task };
  setTask({
    ...task,
    status: 'taken',
    taker_id: user.id,
    taker: user
  });
  
  // 2. 显示加载状态（但 UI 已更新）
  setActionLoading(true);
  
  try {
    // 3. 后台执行 API 调用
    await takeTask(taskId);
    
    // 4. 刷新数据确保一致性
    const res = await api.get(`/api/tasks/${taskId}`);
    setTask(res.data);
  } catch (error: any) {
    // 5. 如果失败，回滚到之前的状态
    setTask(previousTask);
    alert(error.response?.data?.detail || '操作失败，请重试');
  } finally {
    setActionLoading(false);
  }
};
```

**预期效果**：用户点击后立即看到反馈，感知延迟降低 80%+

---

#### 6.2 防抖和节流优化
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**问题**：快速点击按钮可能导致重复请求

**实现方案**：
```typescript
import { useCallback, useRef } from 'react';

// 防抖 Hook
function useDebounce<T extends (...args: any[]) => any>(
  func: T,
  delay: number = 300
): T {
  // ⚠️ 使用 ReturnType<typeof setTimeout> 避免浏览器/Node 环境类型冲突
  const timeoutRef = useRef<ReturnType<typeof setTimeout>>();
  
  return useCallback((...args: Parameters<T>) => {
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
    }
    timeoutRef.current = setTimeout(() => {
      func(...args);
    }, delay);
  }, [func, delay]) as T;
}

// 节流 Hook
function useThrottle<T extends (...args: any[]) => any>(
  func: T,
  delay: number = 300
): T {
  const lastRunRef = useRef<number>(0);
  
  return useCallback((...args: Parameters<T>) => {
    const now = Date.now();
    if (now - lastRunRef.current >= delay) {
      lastRunRef.current = now;
      func(...args);
    }
  }, [func, delay]) as T;
}

// 在组件中使用
const TaskDetailModal: React.FC = ({ taskId }) => {
  // 防抖：搜索输入
  const handleSearch = useDebounce((query: string) => {
    // 搜索逻辑
  }, 300);
  
  // 节流：滚动加载更多
  const handleScroll = useThrottle(() => {
    // 加载更多逻辑
  }, 200);
  
  // 按钮点击：使用 loading 状态防止重复点击
  const handleSubmit = useCallback(async () => {
    if (actionLoading) return; // 防止重复点击
    setActionLoading(true);
    try {
      // 操作逻辑
    } finally {
      setActionLoading(false);
    }
  }, [actionLoading]);
};
```

**预期效果**：避免重复请求，减少服务器压力

---

#### 6.3 预加载和预取优化
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**问题**：用户点击后才开始加载数据，等待时间长

**实现方案**：
```typescript
import { useEffect } from 'react';
import { useQueryClient } from '@tanstack/react-query';

const TaskDetailModal: React.FC = ({ isOpen, taskId }) => {
  const queryClient = useQueryClient();
  
  // 1. 鼠标悬停时预加载（如果使用 React Query）
  const handleTaskHover = useCallback((hoveredTaskId: number) => {
    queryClient.prefetchQuery({
      queryKey: ['tasks', 'detail', hoveredTaskId],
      queryFn: () => api.get(`/api/tasks/${hoveredTaskId}`).then(r => r.data),
      staleTime: 5 * 60 * 1000,
    });
  }, [queryClient]);
  
  // 2. 预加载相关任务（推荐任务）
  useEffect(() => {
    if (task && task.recommended_task_ids) {
      task.recommended_task_ids.forEach((id: number) => {
        queryClient.prefetchQuery({
          queryKey: ['tasks', 'detail', id],
          queryFn: () => api.get(`/api/tasks/${id}`).then(r => r.data),
        });
      });
    }
  }, [task, queryClient]);
  
  // 3. 预加载关键图片（首图）
  useEffect(() => {
    if (task?.images?.[0]) {
      // 关键首图：使用 <link rel="preload">
      const preloadLink = document.createElement('link');
      preloadLink.rel = 'preload';
      preloadLink.as = 'image';
      preloadLink.href = task.images[0];
      document.head.appendChild(preloadLink);
      
      // 次要图片：使用 <link rel="prefetch">（不需要 as）
      task.images.slice(1).forEach((url: string) => {
        const prefetchLink = document.createElement('link');
        prefetchLink.rel = 'prefetch';
        prefetchLink.href = url;
        document.head.appendChild(prefetchLink);
      });
      
      return () => {
        // 清理
        document.head.removeChild(preloadLink);
        task.images.slice(1).forEach((url: string) => {
          const links = document.querySelectorAll(`link[href="${url}"]`);
          links.forEach(link => link.remove());
        });
      };
    }
  }, [task]);
  
  // 4. 在 <img> 标签上设置 fetchpriority="high"（首图）
  // 注意：真正的懒加载应使用 <img loading="lazy"> 或 IntersectionObserver
  // new Image() 会立即触发下载，loading='lazy' 不起作用
};
```

**预期效果**：用户点击时数据已准备好，加载时间减少 50-70%

---

#### 6.4 代码分割和懒加载
**文件**：`frontend/src/pages/TaskDetail.tsx`

**问题**：初始加载包含所有代码，首屏渲染慢

**实现方案**：
```typescript
import { lazy, Suspense } from 'react';
import TaskDetailSkeleton from '../components/TaskDetailSkeleton';

// 懒加载非关键组件
const TaskReviews = lazy(() => import('../components/TaskReviews'));
const TaskApplications = lazy(() => import('../components/TaskApplications'));
const RecommendedTasks = lazy(() => import('../components/RecommendedTasks'));

const TaskDetail: React.FC = () => {
  const [showReviews, setShowReviews] = useState(false);
  const [showApplications, setShowApplications] = useState(false);
  
  return (
    <div>
      {/* 关键内容立即渲染 */}
      <TaskHeader task={task} />
      <TaskInfo task={task} />
      
      {/* 非关键内容懒加载 */}
      {showReviews && (
        <Suspense fallback={<div>加载评价中...</div>}>
          <TaskReviews taskId={task.id} />
        </Suspense>
      )}
      
      {showApplications && (
        <Suspense fallback={<div>加载申请中...</div>}>
          <TaskApplications taskId={task.id} />
        </Suspense>
      )}
      
      {/* 推荐任务 - 低优先级加载 */}
      <Suspense fallback={null}>
        <RecommendedTasks taskId={task.id} />
      </Suspense>
    </div>
  );
};
```

**预期效果**：初始包大小减少 30-40%，首屏渲染时间减少 20-30%

---

#### 6.5 交互反馈优化
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**问题**：按钮点击后没有立即反馈，用户感觉卡顿

**实现方案**：
```typescript
const TaskDetailModal: React.FC = ({ taskId }) => {
  const [buttonStates, setButtonStates] = useState<Record<string, boolean>>({});
  
  // 立即反馈：点击时立即显示加载状态
  const handleAction = useCallback(async (
    actionKey: string,
    actionFn: () => Promise<void>
  ) => {
    // 1. 立即更新按钮状态（视觉反馈）
    setButtonStates(prev => ({ ...prev, [actionKey]: true }));
    
    // 2. 使用 requestAnimationFrame 确保 UI 更新
    requestAnimationFrame(async () => {
      try {
        await actionFn();
      } catch (error) {
        // 错误处理
      } finally {
        setButtonStates(prev => ({ ...prev, [actionKey]: false }));
      }
    });
  }, []);
  
  // 使用示例
  const handleTakeTask = useCallback(() => {
    handleAction('takeTask', async () => {
      await takeTask(taskId);
      // 刷新数据
    });
  }, [taskId, handleAction]);
  
  return (
    <button
      onClick={handleTakeTask}
      disabled={buttonStates.takeTask}
      style={{
        opacity: buttonStates.takeTask ? 0.6 : 1,
        cursor: buttonStates.takeTask ? 'wait' : 'pointer',
        transition: 'opacity 0.1s' // 平滑过渡
      }}
    >
      {buttonStates.takeTask ? '处理中...' : '接受任务'}
    </button>
  );
};
```

**预期效果**：用户点击后立即看到反馈，感知延迟降低 90%+

---

#### 6.6 虚拟滚动（长列表优化）
**文件**：`frontend/src/components/TaskList.tsx`（如果列表很长）

**问题**：渲染大量任务项导致滚动卡顿

**实现方案**：
```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

const TaskList: React.FC<{ tasks: Task[] }> = ({ tasks }) => {
  const parentRef = useRef<HTMLDivElement>(null);
  
  const virtualizer = useVirtualizer({
    count: tasks.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 200, // 估算每个项目高度
    overscan: 5, // 预渲染 5 个项目
  });
  
  return (
    <div
      ref={parentRef}
      style={{ height: '600px', overflow: 'auto' }}
    >
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <TaskItem task={tasks[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
};
```

**预期效果**：即使有 1000+ 任务，滚动依然流畅

---

### 阶段七：代码结构优化（中优先级）

#### 7.1 组件拆分
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**建议拆分的子组件**：
1. `TaskHeader` - 任务标题和状态
2. `TaskInfoCards` - 任务信息卡片
3. `TaskDescription` - 任务描述（含翻译功能）
4. `TaskImages` - 任务图片展示
5. `ApplicationList` - 申请者列表
6. `ReviewModal` - 评价弹窗
7. `ApplyModal` - 申请弹窗
8. `MessageModal` - 留言弹窗
9. `ImageEnlargedView` - 图片放大查看

**预期效果**：提升可维护性，便于性能优化

---

#### 7.2 提取常量
**文件**：`frontend/src/components/TaskDetailModal.tsx`

**需要提取的常量**：
- 样式对象
- 配置值（如最大输入长度）
- 文本内容（部分）

**预期效果**：减少重复代码，提升可维护性

---

## 📊 预期优化效果

### 性能指标

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| 组件重渲染次数 | 高 | 低 | ⬇️ 50-70% |
| 首屏加载时间 | ~2.5s | ~1.5s | ⬇️ 40% |
| API 请求时间 | ~1.2s | ~0.6s | ⬇️ 50% |
| 翻译响应时间 | ~0.8s | ~0.05s (缓存) | ⬇️ 94% |
| 图片加载时间 | 立即全部 | 按需加载 | ⬇️ 50% |
| 内存使用 | 较高 | 优化 | ⬇️ 20-30% |

### 安全性提升

- ✅ XSS 攻击防护
- ✅ 输入验证增强
- ✅ 错误处理完善

---

## 🚀 实施计划

### 第一周：核心性能优化
- [ ] 1.1 使用 React.memo
- [ ] 1.2 使用 useCallback
- [ ] 1.3 使用 useMemo
- [ ] 1.4 优化内联样式

### 第二周：API 和安全性
- [ ] 2.1 并行加载数据
- [ ] 2.2 添加翻译缓存
- [ ] 2.3 优化 useEffect 依赖
- [ ] 4.1 XSS 防护
- [ ] 4.2 输入验证增强

### 第三周：图片和结构优化
- [ ] 3.1 使用 LazyImage
- [ ] 5.1 组件拆分（可选）
- [ ] 5.2 提取常量（可选）

---

## ⚠️ 注意事项

1. **向后兼容**：确保所有优化不影响现有功能
2. **测试覆盖**：每个优化后都要进行充分测试
3. **渐进式优化**：不要一次性修改太多，分阶段进行
4. **性能监控**：使用 React DevTools Profiler 监控优化效果
5. **代码审查**：每个优化都要经过代码审查

---

## 📝 优化检查清单

### 性能优化
- [ ] 组件使用 React.memo
- [ ] 函数使用 useCallback
- [ ] 计算使用 useMemo
- [ ] 样式对象优化
- [ ] useEffect 依赖正确

### API 优化
- [ ] 并行加载数据
- [ ] 翻译结果缓存
- [ ] 请求去重
- [ ] 错误处理完善

### 图片优化
- [ ] 使用 LazyImage
- [ ] 图片错误处理
- [ ] 占位符优化

### 安全性
- [ ] XSS 防护
- [ ] 输入验证
- [ ] 错误边界

---

## 🔧 后端优化方案

### 阶段六：数据库查询优化（高优先级）

#### 6.1 优化 get_task 函数（N+1 查询问题）
**文件**：`backend/app/crud.py` (第501-512行)

**问题**：
- 当前实现先查询任务，再单独查询发布者信息
- 存在 N+1 查询问题

**当前代码**：
```python
def get_task(db: Session, task_id: int):
    task = db.query(Task).filter(Task.id == task_id).first()
    if task:
        # N+1 查询：单独查询发布者
        poster = db.query(User).filter(User.id == task.poster_id).first()
        if poster:
            task.poster_timezone = poster.timezone if poster.timezone else "UTC"
```

**优化方案**：
```python
def get_task(db: Session, task_id: int):
    from sqlalchemy.orm import selectinload
    
    task = (
        db.query(Task)
        .options(
            selectinload(Task.poster),  # 预加载发布者信息
            selectinload(Task.taker),   # 预加载接受者信息（如果存在）
            selectinload(Task.reviews)  # 预加载评价（可选）
        )
        .filter(Task.id == task_id)
        .first()
    )
    
    if task and task.poster:
        task.poster_timezone = task.poster.timezone if task.poster.timezone else "UTC"
    elif task:
        task.poster_timezone = "UTC"
    
    return task
```

**预期效果**：查询时间减少 40-60%，避免 N+1 查询

---

#### 6.2 添加数据库索引优化 ⚠️ P0 优先级
**文件**：`backend/app/models.py`

**当前索引**：
- 已有基础索引，但缺少针对任务详情查询的复合索引

**索引设计原则**：
1. **列顺序**：= 条件优先，再范围，再排序
2. **部分索引**：只对常用查询条件建立索引
3. **覆盖索引**：包含查询所需的所有列，避免回表

**需要添加的索引**：
```python
# 任务详情查询优化索引
# 注意：id 是主键，已有索引，复合索引中 id 在前意义不大
# 但可以创建覆盖索引（包含常用查询字段）

# 任务列表查询优化（按状态+截止日期+创建时间）
Index("ix_tasks_status_deadline_created", Task.status, Task.deadline, Task.created_at)

# 发布者查询优化
Index("ix_tasks_poster_status_created", Task.poster_id, Task.status, Task.created_at)

# 部分索引：只索引开放任务（减少索引大小）
# 需要在 SQL 中创建
```

**SQL 迁移脚本（包含验证步骤）**：
```sql
-- ========================================
-- 任务表索引优化
-- ========================================

-- 1. 创建复合索引（按查询模式优化列顺序）
CREATE INDEX IF NOT EXISTS ix_tasks_status_deadline_created 
ON tasks(status, deadline, created_at DESC)
WHERE status IN ('open', 'taken');  -- 部分索引，只索引常用状态

CREATE INDEX IF NOT EXISTS ix_tasks_poster_status_created 
ON tasks(poster_id, status, created_at DESC);

-- 2. 创建覆盖索引（包含常用查询字段，避免回表）
-- ⚠️ 注意：INCLUDE 子句需要 PostgreSQL ≥ 11
-- 如果版本低于 11，需要创建包含所有列的复合索引
CREATE INDEX IF NOT EXISTS ix_tasks_detail_covering 
ON tasks(id) 
INCLUDE (title, task_type, location, status, base_reward, deadline, created_at);

-- 索引说明：
-- 1. 覆盖索引可以支持 Index Only Scan，避免回表
-- 2. 但 Index Only Scan 需要可见性图（visibility map）支持
-- 3. 需要定期 VACUUM 维护可见性图，确保 all-visible 标记正确
-- 4. 如果可见性图不完整，仍会回表检查可见性

-- 3. 分析表，更新统计信息
ANALYZE tasks;

-- 4. 验证索引使用情况
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT id, title, task_type, location, status, base_reward, deadline, created_at
FROM tasks
WHERE id = 12345;

-- 预期输出应显示：
-- Index Scan using ix_tasks_detail_covering
-- Planning Time: < 1ms
-- Execution Time: < 5ms

-- 5. 验证复合查询
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT *
FROM tasks
WHERE status = 'open' 
  AND deadline > NOW()
ORDER BY created_at DESC
LIMIT 20;

-- 预期输出应显示：
-- Index Scan using ix_tasks_status_deadline_created
-- 不应有 Seq Scan（全表扫描）

-- 6. 检查索引使用统计
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_stat_user_indexes
WHERE tablename = 'tasks'
ORDER BY idx_scan DESC;

-- 7. 查找未使用的索引（考虑删除）
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_stat_user_indexes
WHERE tablename = 'tasks'
  AND idx_scan = 0
  AND indexname NOT LIKE '%_pkey';  -- 保留主键

-- 8. 查看索引膨胀情况（需要 pgstattuple 扩展）
-- 首先安装扩展
CREATE EXTENSION IF NOT EXISTS pgstattuple;

-- 查看索引统计（包含膨胀信息）
SELECT
    indexrelid::regclass AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    (pgstatindex(indexrelid)).avg_leaf_density AS leaf_density,
    (pgstatindex(indexrelid)).leaf_pages AS leaf_pages,
    (pgstatindex(indexrelid)).internal_pages AS internal_pages
FROM pg_index
WHERE indrelid = 'public.tasks'::regclass;

-- 或者使用估算方法（不需要扩展）
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    -- 估算膨胀：如果扫描次数少但大小大，可能有膨胀
    CASE 
        WHEN idx_scan = 0 THEN '未使用'
        WHEN pg_relation_size(indexname::regclass) > 100 * 1024 * 1024 
             AND idx_scan < 100 THEN '可能膨胀'
        ELSE '正常'
    END AS status
FROM pg_stat_user_indexes
WHERE tablename = 'tasks'
ORDER BY pg_relation_size(indexname::regclass) DESC;
```

**Python 验证脚本**：
```python
# backend/scripts/verify_indexes.py
from sqlalchemy import text
from app.database import get_sync_db

def verify_indexes():
    """验证索引使用情况 - 稳健的 JSON 解析"""
    import json
    db = next(get_sync_db())
    
    def parse_explain_result(result):
        """稳健地解析 EXPLAIN JSON 结果"""
        row = result.fetchone()
        if not row:
            return None
        
        # 解析 JSON（可能是字符串或已经是 dict）
        plan_data = row[0]
        if isinstance(plan_data, str):
            plan_data = json.loads(plan_data)
        elif isinstance(plan_data, (list, tuple)) and len(plan_data) > 0:
            plan_data = plan_data[0] if isinstance(plan_data[0], dict) else json.loads(plan_data[0])
        
        # 稳健地提取计划信息
        plan = plan_data.get('Plan', {}) if isinstance(plan_data, dict) else {}
        execution_time = plan_data.get('Execution Time', 0)
        node_type = plan.get('Node Type', 'Unknown')
        
        return {
            'node_type': node_type,
            'execution_time': execution_time,
            'full_plan': plan_data
        }
    
    # 测试查询1：任务详情
    result1 = db.execute(text("""
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        SELECT id, title, task_type, location, status, base_reward, deadline
        FROM tasks
        WHERE id = :task_id
    """), {"task_id": 1})
    
    plan1 = parse_explain_result(result1)
    if plan1:
        print(f"任务详情查询计划: {plan1['node_type']}")
        print(f"执行时间: {plan1['execution_time']}ms")
        # 打印计划要点而非直接 assert
        if plan1['node_type'] not in ['Index Scan', 'Index Only Scan']:
            print(f"⚠️ 警告: 未使用索引扫描，当前类型: {plan1['node_type']}")
        else:
            print("✅ 使用了索引扫描")
    
    # 测试查询2：任务列表
    result2 = db.execute(text("""
        EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
        SELECT *
        FROM tasks
        WHERE status = 'open' AND deadline > NOW()
        ORDER BY created_at DESC
        LIMIT 20
    """))
    
    plan2 = parse_explain_result(result2)
    if plan2:
        print(f"任务列表查询计划: {plan2['node_type']}")
        print(f"执行时间: {plan2['execution_time']}ms")
        plan_str = json.dumps(plan2['full_plan'], indent=2)
        if 'Index Scan' not in plan_str:
            print(f"⚠️ 警告: 可能未使用索引扫描")
        else:
            print("✅ 使用了索引扫描")
    
    print("✅ 索引验证完成")

if __name__ == "__main__":
    verify_indexes()
```

**预期效果**：
- 查询速度提升 30-50%
- 避免全表扫描
- 覆盖索引减少回表操作
- 部分索引减少存储空间

---

#### 6.3 优化任务评价查询
**文件**：`backend/app/crud.py`

**问题**：`get_task_reviews` 可能缺少关联数据预加载

**优化方案**：
```python
def get_task_reviews(db: Session, task_id: int):
    from sqlalchemy.orm import selectinload
    
    reviews = (
        db.query(Review)
        .options(
            selectinload(Review.user),  # 预加载用户信息
            selectinload(Review.task)   # 预加载任务信息（如果需要）
        )
        .filter(Review.task_id == task_id)
        .order_by(Review.created_at.desc())
        .all()
    )
    return reviews
```

**预期效果**：评价查询时间减少 50%+

---

### 阶段七：Redis 缓存优化（高优先级）

#### 7.1 添加任务详情缓存 ⚠️ P0 优先级
**文件**：`backend/app/routers.py` (第860-865行)

**当前实现**：
```python
@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task_detail(task_id: int, db: Session = Depends(get_db)):
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task
```

**优化方案（修复序列化与失效问题）**：
```python
from app.redis_cache import get_redis_client
from functools import wraps
import orjson  # 使用 orjson 替代 json，性能更好
from typing import Callable, Any
import logging

logger = logging.getLogger(__name__)

# 缓存版本号（用于失效策略）
CACHE_VERSION = "v3"

def cache_task_detail_sync(ttl: int = 300):
    """同步函数缓存装饰器 - 只缓存 Pydantic model
    
    ⚠️ 注意：装饰器内不能使用 Depends()，需要从 kwargs 中获取参数
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            # 从 kwargs 中获取参数（不能使用 Depends）
            task_id = kwargs.get("task_id")
            db = kwargs.get("db")
            
            if not task_id or not db:
                # 如果参数不在 kwargs 中，尝试从 args 获取
                # 这取决于被装饰函数的签名
                if args:
                    task_id = args[0] if len(args) > 0 else task_id
                # 直接调用原函数，不缓存
                return func(*args, **kwargs)
            
            redis_client = get_redis_client()
            # 使用版本号命名空间，避免通配符删除
            cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
            
            # 尝试从缓存获取
            if redis_client:
                try:
                    cached = redis_client.get(cache_key)
                    if cached:
                        # 使用 orjson 反序列化
                        cached_dict = orjson.loads(cached)
                        # 从 dict 重建 Pydantic model
                        from app import schemas
                        return schemas.TaskOut(**cached_dict)
                except Exception as e:
                    logger.warning(f"缓存反序列化失败: {e}")
            
            # 从数据库查询
            result = func(*args, **kwargs)
            
            # 写入缓存 - 只缓存 Pydantic model 的 dict
            if redis_client and result:
                try:
                    # 使用 model_dump() 获取 dict，然后用 orjson 序列化
                    if hasattr(result, 'model_dump'):
                        cache_data = result.model_dump()
                    elif hasattr(result, 'dict'):
                        cache_data = result.dict()
                    else:
                        cache_data = result
                    
                    redis_client.setex(
                        cache_key,
                        ttl,
                        orjson.dumps(cache_data)
                    )
                except Exception as e:
                    logger.warning(f"缓存写入失败: {e}")
            
            return result
        return wrapper
    return decorator

def cache_task_detail_async(ttl: int = 300):
    """异步函数缓存装饰器 - 使用 aioredis 或线程池处理阻塞 I/O"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # 从 kwargs 中获取参数
            task_id = kwargs.get("task_id")
            db = kwargs.get("db")
            
            if not task_id:
                if args:
                    task_id = args[0]
                return await func(*args, **kwargs)
            
            # 使用 redis>=4 的 redis.asyncio 接口（推荐）
            # ⚠️ 注意：aioredis 已并入 redis-py，使用 redis>=4 的 redis.asyncio
            import redis.asyncio as aioredis
            from app.redis_cache import get_redis_config
            
            redis_client = aioredis.from_url(
                get_redis_config()['url'],
                decode_responses=False
            )
            
            cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
            
            if redis_client:
                try:
                    # 异步获取缓存
                    cached = await redis_client.get(cache_key)
                    if cached:
                        cached_dict = orjson.loads(cached)
                        from app import schemas
                        return schemas.TaskOut(**cached_dict)
                except Exception as e:
                    logger.warning(f"缓存反序列化失败: {e}")
            
            # 异步查询
            result = await func(*args, **kwargs)
            
            if redis_client and result:
                try:
                    if hasattr(result, 'model_dump'):
                        cache_data = result.model_dump()
                    elif hasattr(result, 'dict'):
                        cache_data = result.dict()
                    else:
                        cache_data = result
                    
                    # 异步写入缓存
                    await redis_client.setex(
                        cache_key,
                        ttl,
                        orjson.dumps(cache_data)
                    )
                except Exception as e:
                    logger.warning(f"缓存写入失败: {e}")
            
            return result
        return wrapper
    return decorator

# 如果只能使用同步 Redis 客户端，使用线程池包装
def cache_task_detail_async_with_threadpool(ttl: int = 300):
    """异步函数缓存装饰器 - 使用线程池处理同步 Redis 调用"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        async def wrapper(*args, **kwargs):
            task_id = kwargs.get("task_id") or (args[0] if args else None)
            
            if not task_id:
                return await func(*args, **kwargs)
            
            redis_client = get_redis_client()  # 同步客户端
            cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
            
            if redis_client:
                try:
                    # 使用线程池执行阻塞的 Redis 操作
                    import anyio
                    cached = await anyio.to_thread.run_sync(
                        redis_client.get, cache_key
                    )
                    if cached:
                        cached_dict = orjson.loads(cached)
                        from app import schemas
                        return schemas.TaskOut(**cached_dict)
                except Exception as e:
                    logger.warning(f"缓存反序列化失败: {e}")
            
            result = await func(*args, **kwargs)
            
            if redis_client and result:
                try:
                    if hasattr(result, 'model_dump'):
                        cache_data = result.model_dump()
                    elif hasattr(result, 'dict'):
                        cache_data = result.dict()
                    else:
                        cache_data = result
                    
                    # 使用线程池写入
                    await anyio.to_thread.run_sync(
                        lambda: redis_client.setex(
                            cache_key,
                            ttl,
                            orjson.dumps(cache_data)
                        )
                    )
                except Exception as e:
                    logger.warning(f"缓存写入失败: {e}")
            
            return result
        return wrapper
    return decorator

# ⚠️ 推荐方案：将缓存逻辑放到服务层（装饰器只初始化一次）
# backend/app/services/task_service.py
class TaskService:
    @staticmethod
    @cache_task_detail_sync(ttl=300)  # 装饰器在类定义时初始化，只执行一次
    def get_task_cached(task_id: int, db: Session):
        """带缓存的任务查询服务"""
        task = crud.get_task(db, task_id)
        if not task:
            raise HTTPException(status_code=404, detail="Task not found")
        return task

# 在路由中使用（避免每次请求创建装饰器）
@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task_detail(task_id: int, db: Session = Depends(get_db)):
    """获取任务详情 - 使用服务层缓存"""
    return TaskService.get_task_cached(task_id=task_id, db=db)

# ❌ 不推荐：在路由函数内部使用装饰器（每次请求都会创建 wrapper）
# @router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
# def get_task_detail(task_id: int, db: Session = Depends(get_db)):
#     @cache_task_detail_sync(ttl=300)  # 每次请求都会执行
#     def _get_task(task_id: int, db: Session):
#         ...
#     return _get_task(task_id=task_id, db=db)
```

**缓存失效策略（避免通配符删除）**：
```python
def invalidate_task_cache(task_id: int):
    """清除任务缓存 - 使用精确键，避免通配符"""
    redis_client = get_redis_client()
    if redis_client:
        # 精确删除，不使用通配符
        cache_key = f"task:{CACHE_VERSION}:detail:{task_id}"
        redis_client.delete(cache_key)
        
        # 如果需要清除列表缓存，使用版本号递增
        # 新版本会自动失效旧版本缓存
        # 或维护一个列表缓存键集合

def invalidate_task_list_cache():
    """清除任务列表缓存 - 通过版本号递增"""
    redis_client = get_redis_client()
    if redis_client:
        list_cache_version_key = "task:list:version"
        redis_client.incr(list_cache_version_key)
        # 版本号递增后，旧版本的缓存键自动失效

def get_task_list_cache_key(status: str, page: int, size: int) -> str:
    """获取任务列表缓存键 - 统一键工厂"""
    redis_client = get_redis_client()
    if redis_client:
        # 获取当前版本号
        version = int(redis_client.get("task:list:version") or 1)
        # 使用版本号构建键，避免通配符删除
        return f"task:list:v{version}:{status}:{page}:{size}"
    return f"task:list:v1:{status}:{page}:{size}"

# 在查询任务列表时使用
def get_tasks_list_cached(status: str, page: int, size: int, db: Session):
    """带缓存的任务列表查询"""
    cache_key = get_task_list_cache_key(status, page, size)
    redis_client = get_redis_client()
    
    if redis_client:
        cached = redis_client.get(cache_key)
        if cached:
            return orjson.loads(cached)
    
    # 查询数据库
    tasks = crud.list_tasks(db, status=status, skip=(page-1)*size, limit=size)
    
    # 写入缓存
    if redis_client:
        redis_client.setex(cache_key, 300, orjson.dumps(tasks))
    
    return tasks
```

**依赖安装**：
```bash
# 后端
pip install orjson
pip install "redis>=4.0.0"  # 使用 redis>=4 的 redis.asyncio，不需要单独的 aioredis

# 前端（如果需要）
npm install @tanstack/react-query
```

**预期效果**：
- 序列化性能提升 2-3 倍（orjson vs json）
- 类型安全，避免类型漂移
- 避免通配符删除带来的阻塞风险
- 支持版本化缓存失效策略

**⚠️ 重要注意事项**：
1. **装饰器参数获取**：不能使用 `Depends()`，必须从 `*args, **kwargs` 中提取
2. **异步 Redis**：异步函数必须使用 `aioredis` 或线程池包装同步调用
3. **服务层方案**：推荐将缓存逻辑放到服务层，路由层只负责调用

---

#### 7.2 添加翻译结果缓存
**文件**：`backend/app/routers.py` (翻译相关路由)

**优化方案**：
```python
def cache_translation(ttl: int = 86400):  # 24小时缓存
    """翻译结果缓存 - 使用稳定哈希"""
    from hashlib import blake2b
    
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # 从参数中提取
            text = kwargs.get("text") or args[0] if args else ""
            target_lang = kwargs.get("target_lang") or args[1] if len(args) > 1 else ""
            source_lang = kwargs.get("source_lang") or args[2] if len(args) > 2 else ""
            
            # 使用稳定哈希（blake2b），避免 hash() 的随机种子问题
            text_hash = blake2b(text.encode('utf-8'), digest_size=16).hexdigest()
            cache_key = f"translation:{CACHE_VERSION}:{source_lang}:{target_lang}:{text_hash}"
            
            # 使用 redis>=4 的 redis.asyncio 接口
            import redis.asyncio as aioredis
            from app.redis_cache import get_redis_config
            
            redis_client = aioredis.from_url(
                get_redis_config()['url'],
                decode_responses=False
            )
            
            if redis_client:
                try:
                    cached = await redis_client.get(cache_key)
                    if cached:
                        return cached.decode('utf-8')
                except Exception as e:
                    logger.warning(f"读取翻译缓存失败: {e}")
            
            result = await func(*args, **kwargs)
            
            if redis_client and result:
                try:
                    await redis_client.setex(cache_key, ttl, result)
                except Exception as e:
                    logger.warning(f"写入翻译缓存失败: {e}")
            
            return result
        return wrapper
    return decorator
```

**预期效果**：
- 翻译API响应时间减少 95%+（缓存命中时）
- 稳定哈希确保跨进程/重启后缓存仍有效
- 避免 hash() 随机种子导致的缓存失效

---

#### 7.3 防止缓存穿透和雪崩
**文件**：`backend/app/redis_cache.py`

**优化方案**：
```python
def get_task_detail_safe(task_id: int, db: Session):
    """防止缓存穿透的任务详情查询"""
    redis_client = get_redis_client()
    cache_key = f"task:detail:{task_id}"
    
    # 1. 先查缓存
    if redis_client:
        cached = redis_client.get(cache_key)
        if cached:
            # 检查是否是空值标记（防止穿透）
            if cached == b"__NULL__":
                return None
            try:
                # ⚠️ 统一使用 orjson 反序列化，避免类型漂移
                return orjson.loads(cached)
            except:
                pass
    
    # 2. 查询数据库
    task = crud.get_task(db, task_id)
    
    # 3. 写入缓存（统一使用 orjson + Pydantic model_dump）
    if redis_client:
        if task:
            # 使用 Pydantic model_dump() + orjson，保持类型一致
            if hasattr(task, 'model_dump'):
                cache_data = task.model_dump()
            elif hasattr(task, 'dict'):
                cache_data = task.dict()
            else:
                cache_data = task
            redis_client.setex(cache_key, 300, orjson.dumps(cache_data))
        else:
            # 缓存空结果，防止穿透（较短TTL）
            redis_client.setex(cache_key, 60, b"__NULL__")
    
    return task
```

**预期效果**：防止缓存穿透攻击，减少数据库压力

---

### 阶段八：API 响应优化（中优先级）

#### 8.1 响应数据序列化优化
**文件**：`backend/app/schemas.py`

**问题**：可能返回了不必要的数据字段

**优化方案**：
```python
class TaskOut(BaseModel):
    """任务输出模型 - 只包含必要字段"""
    id: int
    title: str
    description: str
    task_type: str
    location: str
    status: str
    base_reward: float
    agreed_reward: Optional[float] = None
    currency: str
    deadline: datetime
    created_at: datetime
    # 不包含敏感信息或大量关联数据
    
    class Config:
        from_attributes = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
```

**预期效果**：响应大小减少 20-30%

---

#### 8.2 添加响应压缩
**文件**：`backend/app/main.py`

**优化方案**：
```python
from fastapi.middleware.gzip import GZipMiddleware

# GZip 压缩（适用于动态内容）
app.add_middleware(
    GZipMiddleware,
    minimum_size=1000,  # 只压缩大于1KB的响应
    compresslevel=6     # 压缩级别（1-9，6是平衡点）
)
```

**静态资源 Brotli 压缩（推荐）**：
```python
# 对于静态资源，建议在 CDN 或 Web 服务器层面配置 Brotli
# Nginx 配置示例：
# location /static/ {
#     brotli on;
#     brotli_comp_level 6;
#     brotli_types text/css application/javascript image/svg+xml;
#     gzip_static on;  # 回退到预压缩的 gzip
# }

# 或者在应用层使用 Brotli（需要安装 brotli）
# pip install brotli
from starlette.middleware.compression import CompressionMiddleware

app.add_middleware(
    CompressionMiddleware,
    minimum_size=1000,
    gzip_vary=True,
    # 如果支持 Brotli，优先使用
    # brotli=True  # 需要 Starlette 支持
)
```

**预期效果**：
- GZip：响应大小减少 60-80%（文本数据）
- Brotli：比 GZip 再减少 15-20%（更好的压缩率）

---

#### 8.3 异步处理非关键操作
**文件**：`backend/app/routers.py`

**优化方案**：
```python
from fastapi import BackgroundTasks

@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task_detail(
    task_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    task = crud.get_task(db, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # 异步更新访问统计（不阻塞响应）
    background_tasks.add_task(update_task_view_count, task_id)
    
    return task

def update_task_view_count(task_id: int):
    """异步更新任务访问统计"""
    # 使用独立数据库连接，避免阻塞主请求
    # ...
```

**预期效果**：API响应时间减少 10-20%

---

### 阶段九：后端安全性增强（高优先级）

#### 9.1 SQL 注入防护
**文件**：`backend/app/crud.py`

**当前状态**：使用 SQLAlchemy ORM，已基本防护，但需要检查

**需要检查的地方**：
```python
# ❌ 危险：直接字符串拼接
query = f"SELECT * FROM tasks WHERE id = {task_id}"

# ✅ 安全：使用参数化查询（SQLAlchemy自动处理）
task = db.query(Task).filter(Task.id == task_id).first()
```

**验证清单**：
- [ ] 所有查询都使用 ORM 或参数化查询
- [ ] 没有使用 `text()` 或原始SQL（除非必要且已转义）
- [ ] 所有用户输入都经过验证

---

#### 9.2 输入验证和清理
**文件**：`backend/app/routers.py`

**优化方案**：
```python
from pydantic import validator, Field
from typing import Optional

class TaskDetailQuery(BaseModel):
    """任务详情查询参数验证"""
    task_id: int = Field(..., gt=0, description="任务ID必须大于0")
    
    @validator('task_id')
    def validate_task_id(cls, v):
        if v <= 0:
            raise ValueError('任务ID必须大于0')
        if v > 99999999:  # 合理的上限
            raise ValueError('任务ID超出范围')
        return v

@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
def get_task_detail(
    task_id: int = Path(..., gt=0, le=99999999),
    db: Session = Depends(get_db)
):
    # task_id 已通过路径参数验证
    task = crud.get_task(db, task_id)
    # ...
```

**预期效果**：防止无效请求，提升安全性

---

#### 9.3 速率限制增强
**文件**：`backend/app/routers.py`

**优化方案**：
```python
from app.rate_limiting import rate_limit

@router.get("/tasks/{task_id}", response_model=schemas.TaskOut)
@rate_limit("task_detail", max_requests=100, window_seconds=60)  # 每分钟100次
def get_task_detail(task_id: int, db: Session = Depends(get_db)):
    # ...
```

**预期效果**：防止API滥用，保护服务器资源

---

#### 9.4 敏感信息过滤
**文件**：`backend/app/schemas.py`

**优化方案**：
```python
class TaskOut(BaseModel):
    """任务输出 - 不包含敏感信息"""
    # 包含的字段
    id: int
    title: str
    # ...
    
    # 不包含的字段（在序列化时排除）
    # - poster 的完整信息（只包含必要字段）
    # - 内部状态字段
    # - 审计日志
    
    class Config:
        exclude = {
            'internal_status',
            'audit_log',
            # ...
        }
```

**预期效果**：防止信息泄露

---

### 阶段十：数据库连接池优化（中优先级）

#### 10.1 连接池配置优化
**文件**：`backend/app/database.py`

**优化方案**：
```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,           # 连接池大小
    max_overflow=10,        # 最大溢出连接
    pool_pre_ping=True,    # 连接前ping，检测连接有效性
    pool_recycle=3600,     # 1小时后回收连接
    echo=False             # 生产环境关闭SQL日志
)
```

**预期效果**：减少连接创建开销，提升并发性能

---

#### 10.2 查询超时设置
**文件**：`backend/app/crud.py`

**优化方案**：
```python
from sqlalchemy import event
from sqlalchemy.engine import Engine

@event.listens_for(Engine, "before_cursor_execute")
def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    # 设置查询超时（30秒）
    cursor.execute("SET statement_timeout = 30000")
```

**预期效果**：防止长时间查询阻塞

---

## 📊 全栈优化效果预期

### 性能指标对比

| 指标 | 优化前 | 优化后 | 提升 |
|------|--------|--------|------|
| **前端** |
| 组件重渲染次数 | 高 | 低 | ⬇️ 50-70% |
| 首屏加载时间 | ~2.5s | ~1.5s | ⬇️ 40% |
| API 请求时间 | ~1.2s | ~0.6s | ⬇️ 50% |
| 翻译响应时间 | ~0.8s | ~0.05s (缓存) | ⬇️ 94% |
| 图片加载时间 | 立即全部 | 按需加载 | ⬇️ 50% |
| **后端** |
| 数据库查询时间 | ~200ms | ~80ms | ⬇️ 60% |
| API响应时间 | ~250ms | ~100ms (缓存) | ⬇️ 60% |
| 缓存命中率 | 0% | 70-80% | ⬆️ 70%+ |
| 数据库连接数 | 高 | 优化 | ⬇️ 30% |
| **总体** |
| 端到端响应时间 | ~1.5s | ~0.7s | ⬇️ 53% |
| 服务器负载 | 高 | 中 | ⬇️ 40% |
| 用户体验评分 | 6/10 | 9/10 | ⬆️ 50% |

---

## 🚀 全栈实施计划

### 第一周：P0 优先级优化（必须完成）

**前端**：
- [ ] 1.1 使用 React.memo
- [ ] 1.2 使用 useCallback
- [ ] 1.3 使用 useMemo
- [ ] 1.4 优化内联样式
- [ ] 2.1 并行加载数据
- [ ] 6.1 乐观更新（立即反馈）
- [ ] 6.2 防抖节流优化
- [ ] 5.1 添加错误边界组件
- [ ] 5.2 添加 Suspense 和 Skeleton
- [ ] 5.3 使用 useTransition 优化非关键渲染
- [ ] 4.1 XSS 防护（DOMPurify + CSP + 后端校验）

**后端**：
- [ ] 6.1 优化 get_task 函数（N+1查询，使用 selectinload）
- [ ] 6.2 添加数据库索引 + EXPLAIN ANALYZE 验证
- [ ] 7.1 添加任务详情缓存（orjson + 版本号命名空间）
- [ ] 7.1 修复同步/异步装饰器一致性

### 第二周：P1 优先级优化（强烈建议）

**前端**：
- [ ] 2.1 并行加载数据
- [ ] 11.1 集成 React Query 统一数据层
- [ ] 12.1 翻译缓存持久化（sessionStorage）
- [ ] 2.3 优化 useEffect 依赖
- [ ] 4.2 输入验证增强

**后端**：
- [ ] 7.2 添加翻译结果缓存（orjson）
- [ ] 7.3 防止缓存穿透和雪崩
- [ ] 13.1 速率限制返回头（Retry-After + X-RateLimit-*）
- [ ] 9.1 SQL 注入防护检查
- [ ] 9.2 输入验证和清理
- [ ] 14.1 添加 RUM 和 APM 监控

### 第三周：P2 优先级优化（锦上添花）

**前端**：
- [ ] 3.1 使用 LazyImage
- [ ] 15.1 图片优化（srcset + WebP/AVIF + fetchpriority）
- [ ] 5.1 组件拆分（可选）
- [ ] 5.2 提取常量（可选）

**后端**：
- [ ] 8.1 响应数据序列化优化
- [ ] 8.2 添加响应压缩（GZip）
- [ ] 8.3 异步处理非关键操作
- [ ] 10.1 连接池配置优化
- [ ] 16.1 查询超时配置（连接级配置）

---

## ⚠️ 注意事项

### 前端注意事项
1. **向后兼容**：确保所有优化不影响现有功能
2. **测试覆盖**：每个优化后都要进行充分测试
3. **渐进式优化**：不要一次性修改太多，分阶段进行
4. **性能监控**：使用 React DevTools Profiler 监控优化效果
5. **代码审查**：每个优化都要经过代码审查

### 后端注意事项
1. **数据库迁移**：索引添加需要数据库迁移脚本
2. **缓存一致性**：确保缓存失效策略正确
3. **监控告警**：添加缓存命中率、查询时间监控
4. **降级策略**：Redis不可用时的降级方案
5. **压力测试**：优化后进行压力测试验证效果

---

## 📝 全栈优化检查清单

### 前端优化（P0/P1/P2）
**P0 优先级**：
- [ ] 组件使用 React.memo
- [ ] 函数使用 useCallback
- [ ] 计算使用 useMemo
- [ ] 样式对象优化
- [ ] useEffect 依赖正确
- [ ] 错误边界组件
- [ ] Suspense + Skeleton 加载
- [ ] useTransition 优化非关键渲染
- [ ] XSS 防护（DOMPurify + CSP）
- [ ] 输入验证增强

**P1 优先级**：
- [ ] React Query/SWR 统一数据层
- [ ] 翻译缓存持久化（sessionStorage）
- [ ] 预加载和预取优化（6.3）
- [ ] 代码分割和懒加载（6.4）
- [ ] 请求去重和取消（AbortController）
- [ ] 错误处理完善

**P2 优先级**：
- [ ] 使用 LazyImage
- [ ] 图片优化（srcset + WebP/AVIF）
- [ ] 图片错误处理
- [ ] 虚拟滚动（长列表，6.6）
- [ ] 组件拆分（可选）
- [ ] 提取常量（可选）

### 后端优化（P0/P1/P2）
**P0 优先级**：
- [ ] N+1 查询优化（selectinload）
- [ ] 数据库索引优化 + EXPLAIN ANALYZE 验证
- [ ] Redis 缓存实现（orjson + 版本号命名空间）
- [ ] 同步/异步装饰器一致性
- [ ] SQL 注入防护检查
- [ ] 输入验证和清理

**P1 优先级**：
- [ ] 缓存失效策略（避免通配符删除）
- [ ] 防止缓存穿透和雪崩
- [ ] 速率限制返回头（Retry-After）
- [ ] 速率限制键策略（IP/用户/端点）
- [ ] RUM + APM 监控
- [ ] KPI 阈值和告警

**P2 优先级**：
- [ ] 响应数据优化
- [ ] 响应压缩（GZip）
- [ ] 异步处理非关键操作
- [ ] 连接池优化
- [ ] 查询超时配置（连接级）

---

## 🔗 相关文档

- [React 性能优化指南](https://react.dev/learn/render-and-commit)
- [前端性能优化总结](./FRONTEND_PERFORMANCE_OPTIMIZATION.md)
- [后端优化指南](./BACKEND_OPTIMIZATION_GUIDE.md)
- [安全性审计报告](./SECURITY_AUDIT_REPORT.md)
- [数据库优化指南](./POSTGRES_EXTENSIONS_GUIDE.md)
- [Redis 配置指南](./REDIS_CONFIG_GUIDE.md)

---

---

## 🔧 P1 优先级优化（强烈建议）

### 阶段十一：请求治理 - React Query/SWR ⚠️ P1 优先级

#### 11.1 集成 React Query 统一数据层
**文件**：`frontend/src/hooks/useTaskDetail.ts` (新建)

**问题**：当前使用本地 Map 缓存，缺少去重、重试、失效、预取等能力

**实现方案**：
```typescript
// 安装依赖
// npm install @tanstack/react-query

// frontend/src/hooks/useTaskDetail.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api, { fetchCurrentUser, getTaskReviews } from '../api';  // 注意：路径根据实际项目结构调整

// 查询键工厂（使用 as const 确保类型安全）
export const taskKeys = {
  all: ['tasks'] as const,
  detail: (id: number) => [...taskKeys.all, 'detail', id] as const,
  reviews: (id: number) => [...taskKeys.all, 'reviews', id] as const,
  user: () => ['user', 'current'] as const,
} as const;

// 任务详情查询
export const useTaskDetail = (taskId: number | null) => {
  return useQuery({
    queryKey: taskKeys.detail(taskId!),
    queryFn: async ({ signal }) => {
      if (!taskId) return null;
      const res = await api.get(`/api/tasks/${taskId}`, { signal });
      return res.data;
    },
    enabled: !!taskId,
    staleTime: 5 * 60 * 1000,  // 5分钟内认为数据新鲜
    gcTime: 10 * 60 * 1000,    // 10分钟后垃圾回收
    retry: 2,
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000),
  });
};

// 用户信息查询
export const useCurrentUser = () => {
  return useQuery({
    queryKey: taskKeys.user(),
    queryFn: fetchCurrentUser,
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });
};

// 任务评价查询
export const useTaskReviews = (taskId: number | null) => {
  return useQuery({
    queryKey: taskKeys.reviews(taskId!),
    queryFn: async ({ signal }) => {
      if (!taskId) return [];
      // 注意：getTaskReviews 需要支持 AbortSignal
      // 如果 API 函数不支持，需要修改 api.ts
      return await getTaskReviews(taskId, { signal });
    },
    enabled: !!taskId,
    staleTime: 2 * 60 * 1000,
  });
};

// 并行查询任务和用户
export const useTaskDetailWithUser = (taskId: number | null) => {
  const taskQuery = useTaskDetail(taskId);
  const userQuery = useCurrentUser();
  
  return {
    task: taskQuery.data,
    user: userQuery.data,
    isLoading: taskQuery.isLoading || userQuery.isLoading,
    error: taskQuery.error || userQuery.error,
    refetch: () => {
      taskQuery.refetch();
      userQuery.refetch();
    },
  };
};
```

**在组件中使用**：
```typescript
// frontend/src/components/TaskDetailModal.tsx
import { useTaskDetailWithUser, useTaskReviews } from '../hooks/useTaskDetail';
import { useQueryClient } from '@tanstack/react-query';

const TaskDetailModal: React.FC<TaskDetailModalProps> = ({ isOpen, onClose, taskId }) => {
  const queryClient = useQueryClient();
  const { task, user, isLoading, error } = useTaskDetailWithUser(taskId);
  const { data: reviews } = useTaskReviews(task?.status === 'completed' ? taskId : null);
  
  // 预取相关数据
  useEffect(() => {
    if (task) {
      queryClient.prefetchQuery({
        queryKey: ['tasks', 'recommended', task.id],
        queryFn: () => fetchRecommendedTasks(task),
      });
    }
  }, [task, queryClient]);
  
  // 取消未完成请求（Modal 关闭时）
  useEffect(() => {
    if (!isOpen && taskId) {
      queryClient.cancelQueries({ queryKey: taskKeys.detail(taskId) });
    }
  }, [isOpen, taskId, queryClient]);
  
  // ... 其余代码
};
```

**预期效果**：
- 自动请求去重
- 智能重试机制
- 自动缓存管理
- 支持预取和取消
- 减少 50%+ 的重复请求

---

### 阶段十二：翻译缓存持久化 ⚠️ P1 优先级

#### 12.1 升级翻译缓存为持久化存储
**文件**：`frontend/src/utils/translationCache.ts` (新建)

**问题**：组件内 Map 缓存，组件卸载后失效

**实现方案**：
```typescript
// frontend/src/utils/translationCache.ts
const CACHE_VERSION = 'v1';
const CACHE_KEY_PREFIX = `translation:${CACHE_VERSION}:`;

interface CacheEntry {
  translated: string;
  timestamp: number;
  ttl: number;
}

class TranslationCache {
  private memoryCache: Map<string, CacheEntry> = new Map();
  private readonly defaultTTL = 24 * 60 * 60 * 1000; // 24小时

  private getStorageKey(key: string): string {
    return `${CACHE_KEY_PREFIX}${key}`;
  }

  private isExpired(entry: CacheEntry): boolean {
    return Date.now() - entry.timestamp > entry.ttl;
  }

  get(text: string, targetLang: string, sourceLang: string): string | null {
    const cacheKey = `${sourceLang}:${targetLang}:${text}`;
    
    // 1. 先查内存缓存
    const memoryEntry = this.memoryCache.get(cacheKey);
    if (memoryEntry && !this.isExpired(memoryEntry)) {
      return memoryEntry.translated;
    }
    
    // 2. 查 sessionStorage
    try {
      const storageKey = this.getStorageKey(cacheKey);
      const stored = sessionStorage.getItem(storageKey);
      if (stored) {
        const entry: CacheEntry = JSON.parse(stored);
        if (!this.isExpired(entry)) {
          // 回填到内存缓存
          this.memoryCache.set(cacheKey, entry);
          return entry.translated;
        } else {
          sessionStorage.removeItem(storageKey);
        }
      }
    } catch (e) {
      console.warn('读取翻译缓存失败:', e);
    }
    
    return null;
  }

  set(
    text: string,
    targetLang: string,
    sourceLang: string,
    translated: string,
    ttl: number = this.defaultTTL
  ): void {
    const cacheKey = `${sourceLang}:${targetLang}:${text}`;
    const entry: CacheEntry = {
      translated,
      timestamp: Date.now(),
      ttl,
    };
    
    // 1. 写入内存缓存
    this.memoryCache.set(cacheKey, entry);
    
    // 2. 写入 sessionStorage
    try {
      const storageKey = this.getStorageKey(cacheKey);
      sessionStorage.setItem(storageKey, JSON.stringify(entry));
      this.cleanExpired();
    } catch (e) {
      console.warn('写入翻译缓存失败:', e);
      this.cleanExpired();
    }
  }

  private cleanExpired(): void {
    // 清理过期缓存（限制频率）
    if (Math.random() < 0.1) {
      try {
        const keysToRemove: string[] = [];
        for (let i = 0; i < sessionStorage.length; i++) {
          const key = sessionStorage.key(i);
          if (key?.startsWith(CACHE_KEY_PREFIX)) {
            const stored = sessionStorage.getItem(key);
            if (stored) {
              const entry: CacheEntry = JSON.parse(stored);
              if (this.isExpired(entry)) {
                keysToRemove.push(key);
              }
            }
          }
        }
        keysToRemove.forEach(key => sessionStorage.removeItem(key));
      } catch (e) {
        console.warn('清理过期缓存失败:', e);
      }
    }
  }

  clear(): void {
    this.memoryCache.clear();
    // 清理 sessionStorage...
  }
}

export const translationCache = new TranslationCache();
```

**预期效果**：
- 缓存跨组件持久化
- 页面刷新后缓存仍有效
- 自动清理过期缓存

---

### 阶段十三：速率限制返回头 ⚠️ P1 优先级

#### 13.1 增强速率限制响应头
**文件**：`backend/app/rate_limiting.py`

**优化方案**：
```python
from fastapi import Request, Response
import time

def rate_limit_with_headers(
    identifier: str,
    max_requests: int = 100,
    window_seconds: int = 60,
    key_func: Callable[[Request], str] = None
):
    """带响应头的速率限制装饰器"""
    def decorator(func):
        @wraps(func)
        async def wrapper(request: Request, response: Response, *args, **kwargs):
            # 确定限流键（IP/用户/端点）
            if key_func:
                key = key_func(request)
            else:
                client_ip = request.client.host
                endpoint = request.url.path
                key = f"{identifier}:{client_ip}:{endpoint}"
            
            redis_client = get_redis_client()
            current_time = time.time()
            window_start = current_time - window_seconds
            
            if redis_client:
                pipe = redis_client.pipeline()
                pipe.zremrangebyscore(key, 0, window_start)
                pipe.zcard(key)
                pipe.zadd(key, {str(current_time): current_time})
                pipe.expire(key, window_seconds)
                results = pipe.execute()
                
                request_count = results[1] + 1
                
                if request_count > max_requests:
                    oldest_request = redis_client.zrange(key, 0, 0, withscores=True)
                    retry_after = int(window_seconds - (current_time - oldest_request[0][1])) if oldest_request else window_seconds
                    
                    response.headers["X-RateLimit-Limit"] = str(max_requests)
                    response.headers["X-RateLimit-Remaining"] = "0"
                    response.headers["X-RateLimit-Reset"] = str(int(current_time + retry_after))
                    response.headers["Retry-After"] = str(retry_after)
                    
                    raise HTTPException(
                        status_code=429,
                        detail=f"请求过于频繁，请在 {retry_after} 秒后重试",
                        headers={
                            "Retry-After": str(retry_after),
                            "X-RateLimit-Limit": str(max_requests),
                            "X-RateLimit-Reset": str(int(current_time + retry_after))
                        }
                    )
                else:
                    remaining = max_requests - request_count
                    response.headers["X-RateLimit-Limit"] = str(max_requests)
                    response.headers["X-RateLimit-Remaining"] = str(remaining)
                    response.headers["X-RateLimit-Reset"] = str(int(current_time + window_seconds))
            
            return await func(request, response, *args, **kwargs)
        return wrapper
    return decorator
```

**预期效果**：客户端可以智能退避，减少无效重试

---

### 阶段十四：观测与回归 ⚠️ P1 优先级

#### 14.1 添加 RUM 和 APM 监控
**文件**：`frontend/src/utils/monitoring.ts` (新建)

**实现方案**：
```typescript
// frontend/src/utils/monitoring.ts
interface PerformanceMetrics {
  taskDetailP95: number;
  cacheHitRate: number;
  errorRate: number;
  inp: number;
}

class PerformanceMonitor {
  private metrics: PerformanceMetrics = {
    taskDetailP95: 0,
    cacheHitRate: 0,
    errorRate: 0,
    inp: 0,
  };
  
  measureTaskDetailLoad(taskId: number, startTime: number) {
    const loadTime = performance.now() - startTime;
    this.sendMetric('task_detail_load_time', loadTime, { taskId });
    this.updateP95('taskDetailP95', loadTime);
  }
  
  recordCacheHit(hit: boolean) {
    this.sendMetric('cache_hit', hit ? 1 : 0);
    this.updateCacheHitRate(hit);
  }
  
  measureINP() {
    if ('PerformanceObserver' in window) {
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) {
          if (entry.entryType === 'event') {
            const inp = entry.processingStart - entry.startTime;
            this.sendMetric('inp', inp);
            this.metrics.inp = inp;
          }
        }
      });
      observer.observe({ entryTypes: ['event'] });
    }
  }
  
  private sendMetric(name: string, value: number, tags?: Record<string, any>) {
    // 发送到监控服务
    if (window.gtag) {
      window.gtag('event', 'performance_metric', {
        metric_name: name,
        metric_value: value,
        ...tags,
      });
    }
  }
  
  getMetrics(): PerformanceMetrics {
    return { ...this.metrics };
  }
}

export const performanceMonitor = new PerformanceMonitor();
performanceMonitor.measureINP();
```

**KPI 阈值和告警**：
```yaml
# monitoring/thresholds.yaml
kpis:
  task_detail_p95:
    threshold: 700  # 700ms
    alert: "任务详情接口 P95 超过阈值"
  cache_hit_rate:
    threshold: 0.7  # 70%
    alert: "缓存命中率低于阈值"
  error_rate:
    threshold: 0.01  # 1%
    alert: "错误率超过阈值"
  inp:
    threshold: 200  # 200ms
    alert: "INP 超过阈值，用户体验下降"
```

**预期效果**：实时监控性能指标，自动告警异常情况

---

## 🎨 P2 优先级优化（锦上添花）

### 阶段十五：图片优化增强 ⚠️ P2 优先级

#### 15.1 添加响应式图片和现代格式
**文件**：`frontend/src/components/LazyImage.tsx`

**优化方案**：
```typescript
interface LazyImageProps {
  src: string;
  srcSet?: string;
  sizes?: string;
  alt?: string;
  priority?: boolean;  // 首图优先级
}

const LazyImage: React.FC<LazyImageProps> = ({
  src,
  srcSet,
  sizes,
  alt = '',
  priority = false,
}) => {
  // 生成响应式 srcSet（支持 WebP/AVIF 优先）
  const generateSrcSet = (baseSrc: string): string => {
    const widths = [400, 800, 1200, 1600];
    const formats = ['avif', 'webp', 'jpg'];  // 优先 AVIF，回退到 WebP，最后 JPEG
    
    // 生成多格式 srcSet
    return formats.map(format => {
      const formatSrcSet = widths
        .map(w => `${baseSrc}?w=${w}&format=${format} ${w}w`)
        .join(', ');
      return formatSrcSet;
    }).join(', ');
  };
  
  // 生成 sizes 属性（响应式断点）
  const defaultSizes = sizes || '(max-width: 400px) 100vw, (max-width: 800px) 50vw, 33vw';
  
  return (
    <picture>
      {/* AVIF 格式（最佳压缩） */}
      <source
        srcSet={srcSet || generateSrcSet(src.replace(/\.(jpg|jpeg|png)$/i, '.avif'))}
        sizes={defaultSizes}
        type="image/avif"
      />
      {/* WebP 格式（回退） */}
      <source
        srcSet={srcSet || generateSrcSet(src.replace(/\.(jpg|jpeg|png)$/i, '.webp'))}
        sizes={defaultSizes}
        type="image/webp"
      />
      {/* 原始格式（最终回退） */}
      <img
        src={src}
        srcSet={srcSet || generateSrcSet(src)}
        sizes={defaultSizes}
        alt={alt}
        loading={priority ? 'eager' : 'lazy'}
        fetchPriority={priority ? 'high' : 'auto'}
        decoding="async"
      />
    </picture>
  );
};
```

**后端图片优化**：
```python
# backend/app/routes/images.py
@router.get("/images/{image_id}")
async def get_image(
    image_id: str,
    w: int = Query(None),
    format: str = Query("webp"),
):
    """返回优化后的图片"""
    original_image = load_image_from_storage(image_id)
    if w:
        original_image.thumbnail((w, 1920), Image.Resampling.LANCZOS)
    
    output = io.BytesIO()
    if format == "webp":
        original_image.save(output, format="WEBP", quality=85)
        media_type = "image/webp"
    elif format == "avif":
        original_image.save(output, format="AVIF", quality=80)
        media_type = "image/avif"
    else:
        original_image.save(output, format="JPEG", quality=85)
        media_type = "image/jpeg"
    
    return Response(content=output.getvalue(), media_type=media_type)
```

**预期效果**：
- 响应式图片减少带宽 40-60%
- WebP/AVIF 减少文件大小 30-50%
- 使用 `<picture>` 标签实现格式优先选择（AVIF > WebP > JPEG）
- 首图设置 `fetchpriority="high"` 提升 LCP（Largest Contentful Paint）

---

### 阶段十六：查询超时配置优化 ⚠️ P2 优先级

#### 16.1 连接级超时配置
**文件**：`backend/app/database.py`

**优化方案（推荐连接级配置）**：
```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True,
    pool_recycle=3600,
    connect_args={
        "options": "-c statement_timeout=30000"  # 连接级超时设置（30秒）
    }
)

# 或者在数据库级别设置（推荐生产环境）
# ALTER DATABASE your_db SET statement_timeout = '30s';
```

**预期效果**：减少每次查询的额外往返，性能更好

---

## 📊 优先级总结

### P0 优先级（必须补的）
1. ✅ Redis 缓存序列化与失效（orjson + 版本号命名空间）
2. ✅ 同步/异步装饰器一致性（分别提供 sync/async 版本）
3. ✅ 前端安全基线（DOMPurify + CSP + 后端二次校验）
4. ✅ 错误边界 & 并发渲染（ErrorBoundary + Suspense + useTransition）
5. ✅ 数据库索引验证（EXPLAIN ANALYZE + 验证脚本）

### P1 优先级（强烈建议）
1. ✅ 请求治理（React Query/SWR 统一数据层）
2. ✅ 翻译缓存持久化（sessionStorage + 版本号）
3. ✅ 速率限制返回头（Retry-After + X-RateLimit-*）
4. ✅ 观测与回归（RUM + APM + KPI 阈值）

### P2 优先级（锦上添花）
1. ✅ 图片优化（srcset + WebP/AVIF + fetchpriority）
2. ✅ 查询超时配置（连接级配置）
3. ✅ 响应压缩增强（Brotli 预压缩）
4. ✅ 安全渲染属性收紧（DOMPurify hook 强制 rel 属性）

---

## ⚠️ 关键修正说明

### 已修正的问题

1. **FastAPI 装饰器 Depends() 问题**
   - ❌ 错误：装饰器内使用 `db: Session = Depends(get_db)`
   - ✅ 正确：从 `*args, **kwargs` 中获取参数，或使用服务层方案

2. **异步 Redis 客户端问题**
   - ❌ 错误：异步函数中使用同步 `redis_client.get()`
   - ✅ 正确：使用 `aioredis` 或 `anyio.to_thread.run_sync()`

3. **翻译缓存哈希问题**
   - ❌ 错误：使用 `hash(text)`（随机种子）
   - ✅ 正确：使用 `blake2b(text.encode()).hexdigest()`

4. **CSP 策略过于宽松**
   - ❌ 错误：`script-src 'self' 'unsafe-inline' 'unsafe-eval'`
   - ✅ 正确：使用 nonce 策略 + `'strict-dynamic'`

5. **useTransition 命名冲突**
   - ❌ 错误：同时 import 和解构 `startTransition`
   - ✅ 正确：只使用解构的 `startTransition` 或只 import

6. **列表缓存版本号方案**
   - ❌ 错误：只有版本号递增，没有键工厂
   - ✅ 正确：提供统一的 `get_task_list_cache_key()` 函数

7. **索引膨胀检查 SQL**
   - ❌ 错误：`pg_relation_size(..., 'vm')` 不存在
   - ✅ 正确：使用 `pgstattuple` 扩展或估算方法

8. **PostgreSQL 版本兼容**
   - ⚠️ 已标注：INCLUDE 子句需要 PostgreSQL ≥ 11
   - ⚠️ 已说明：Index Only Scan 需要 VACUUM 维护可见性图

9. **React Query 代码示例**
   - ⚠️ 已修正：import 路径注释
   - ⚠️ 已修正：taskKeys 类型定义（添加 as const）
   - ⚠️ 已修正：AbortSignal 使用方式

10. **DOMPurify 安全属性**
    - ⚠️ 已增强：添加 hook 强制 rel="noopener noreferrer"
    - ⚠️ 已增强：限制链接协议（只允许 http/https/mailto）

---

## 📌 实施前必读

### 关键修正点（按严重性排序）

**🔴 严重（必须修正）**：
1. **FastAPI 装饰器不能使用 `Depends()`** - 会导致 DI 失效，必须从 `*args, **kwargs` 获取参数
2. **异步函数不能使用同步 Redis** - 会阻塞事件循环，必须使用 `redis>=4` 的 `redis.asyncio` 或线程池
3. **翻译缓存不能使用 `hash()`** - 随机种子导致缓存失效，必须使用 `blake2b`
4. **CSP 不能使用 `unsafe-inline/unsafe-eval`** - 几乎等于没有 CSP，必须使用 nonce 策略

**🟡 重要（强烈建议修正）**：
5. **useTransition 用法错误** - 应使用 promise 链，而不是 async/await
6. **列表缓存版本号方案不完整** - 需要统一键工厂函数
7. **索引膨胀检查 SQL 错误** - 需要使用 `pgstattuple` 扩展或估算方法
8. **缓存序列化不一致** - 防止穿透示例仍使用 json.dumps，应统一用 orjson
9. **装饰器重复创建** - 避免在路由函数内使用装饰器，应使用服务层静态方法

**🟢 建议（可选但推荐）**：
10. **PostgreSQL 版本要求标注** - 避免兼容性问题（INCLUDE 需要 ≥ 11）
11. **Brotli 压缩补充** - 更好的压缩率（比 GZip 再减少 15-20%）
12. **DOMPurify hook 增强** - 更严格的安全策略（强制 rel 属性）
13. **TypeScript 定时器类型** - 使用 `ReturnType<typeof setTimeout>` 避免环境冲突
14. **图片响应式增强** - 使用 `<picture>` 标签实现格式优先选择

### 代码示例检查清单

在实施前，请确保所有代码示例：
- ✅ 装饰器参数从 `*args, **kwargs` 获取
- ✅ 异步函数使用异步 Redis 客户端
- ✅ 哈希函数使用稳定算法（blake2b）
- ✅ CSP 避免内联脚本（SPA 场景）
- ✅ useTransition 使用 promise 链
- ✅ 缓存键使用统一工厂函数
- ✅ SQL 查询已验证（EXPLAIN ANALYZE，稳健解析）
- ✅ 缓存序列化统一使用 orjson
- ✅ 装饰器使用服务层静态方法
- ✅ Redis 客户端使用 redis>=4 的 redis.asyncio
- ✅ TypeScript 定时器类型使用 ReturnType<typeof setTimeout>

---

**最后更新**：2024-01-XX  
**维护者**：开发团队  
**版本**：v2.0（已修正所有关键问题）

