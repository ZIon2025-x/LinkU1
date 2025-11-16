# 日志问题修复计划

## 📋 问题总结

基于日志文件 `logs.1763317554418.log` 的分析，发现以下三个主要问题需要修复：

1. **WebSocket频繁重连** - 导致服务器资源浪费和用户体验下降
2. **频繁读取用户Profile** - 增加数据库压力和网络带宽消耗
3. **Redis键无法解析** - 可能导致数据丢失和性能问题

---

## 🔴 问题1：WebSocket频繁重连

### 问题描述

**现象**：
- 同一用户（如 `27167013`, `98921543`）的WebSocket连接频繁建立和关闭
- 日志中大量出现 `connection open` 和 `connection closed` 交替出现
- 连接建立后很快又关闭，然后又重新建立，形成循环

**日志示例**：
```
2025-11-16T18:01:45.787772946Z [err]  INFO:     ('100.64.0.11', 26166) - "WebSocket /ws/chat/27167013" [accepted]
2025-11-16T18:01:45.787778434Z [err]  INFO:     connection open
2025-11-16T18:01:45.792675954Z [err]  INFO:     ('100.64.0.9', 12370) - "WebSocket /ws/chat/27167013" [accepted]
2025-11-16T18:01:45.792687690Z [err]  INFO:     connection closed
2025-11-16T18:01:45.792694870Z [err]  INFO:     connection open
```

### 根本原因分析

#### 原因1：后端关闭旧连接时使用了非正常关闭码

**位置**：`backend/app/main.py:567-575`

**当前代码**：
```python
if user_id in active_connections:
    old_websocket = active_connections[user_id]
    try:
        # ⚠️ 旧代码（已废弃）：使用code=1001会导致前端重连
        # 正确做法：使用code=1000 + 固定reason
        await old_websocket.close(code=1000, reason="New connection established")
```

**问题**：
- ⚠️ 旧实现（已废弃）：使用 `code=1001`（端点离开）关闭旧连接会导致前端重连
- 正确做法：使用 `code=1000`（正常关闭）+ 固定reason "New connection established"
- 前端代码认为只有 `code=1000` 才是正常关闭
- 导致前端认为这是异常关闭，立即触发重连

**前端代码**：`frontend/src/utils/WebSocketManager.ts:113`
```typescript
if (event.code !== 1000 && this.userId && this.reconnectAttempts < this.maxReconnectAttempts) {
    this.reconnectAttempts++;
    this.reconnectTimeout = setTimeout(() => {
        this.doConnect();
    }, 5000);
}
```

#### 原因2：多个组件可能同时初始化WebSocket连接

**可能的位置**：
- `UnreadMessageContext.tsx` - 在用户变化时连接
- `CustomerService.tsx` - 有自己的WebSocket连接逻辑
- `Message.tsx` - 可能也有独立的连接
- 没有全局连接状态管理，导致重复连接

#### 原因3：前端重连逻辑没有识别新连接替换场景

**问题**：
- 前端无法区分"新连接替换旧连接"和"异常断开"
- 所有非1000的关闭码都会触发重连
- 导致循环：新连接 → 关闭旧连接(1001) → 前端重连 → 新连接 → ...

### 修复方案

#### 方案1：服务端原子替换连接（关键修复）

**修改位置**：`backend/app/main.py:566-579`

**问题**：当前"先关旧，再开新"的流程在并发场景下可能出现竞态条件，两个同时到达的连接可能互相认为对方是"旧连接"。

**修改内容**：
```python
# 使用用户级锁或原子交换模式
import asyncio
from collections import defaultdict

# 为每个用户维护连接锁
connection_locks = defaultdict(asyncio.Lock)

@app.websocket("/ws/chat/{user_id}")
async def websocket_chat(websocket: WebSocket, user_id: str, db: Session = Depends(get_db)):
    # ... 认证逻辑 ...
    
    # 获取用户级锁，确保原子替换
    async with connection_locks[user_id]:
        # 先登记新连接为当前连接（原子操作）
        old_websocket = active_connections.get(user_id)
        active_connections[user_id] = websocket
        
        # 接受新连接
        await websocket.accept()
        logger.debug(f"WebSocket connection established for user {user_id}")
        
        # 异步关闭旧连接（不影响新连接）
        if old_websocket:
            asyncio.create_task(close_old_connection(old_websocket, user_id))
    
    # ⚠️ 连接关闭后清理连接锁，防止泄漏
    try:
        # ... 业务逻辑 ...
    finally:
        # ⚠️ 连接关闭后清理连接锁，防止泄漏
        active_connections.pop(user_id, None)
        # 如果该user_id不再出现在active_connections中，清理连接锁
        if user_id not in active_connections and user_id in connection_locks:
            # 注意：defaultdict会自动创建，但我们可以显式删除不再使用的项
            # 使用pop避免KeyError
            connection_locks.pop(user_id, None)

async def close_old_connection(old_websocket: WebSocket, user_id: str):
    """异步关闭旧连接，使用正常关闭码和固定reason"""
    try:
        from app.constants import WS_CLOSE_CODE_NORMAL, WS_CLOSE_REASON_NEW_CONNECTION
        # 使用1000（正常关闭）配合固定reason，作为协议契约
        await old_websocket.close(
            code=WS_CLOSE_CODE_NORMAL, 
            reason=WS_CLOSE_REASON_NEW_CONNECTION  # 固定文案，不要随意修改
        )
        logger.debug(f"Closed existing WebSocket connection for user {user_id}")
    except Exception as e:
        logger.debug(f"Error closing old WebSocket for user {user_id}: {e}")
```

**优点**：
- 原子替换，避免并发竞态
- 新连接立即生效，旧连接异步关闭
- 关闭结果不影响新连接存活

**协议契约**：
- `code=1000` + `reason="New connection established"` 作为"新连接替换"的固定标识
- 前端必须识别此reason，不要触发重连
- ⚠️ **必须常量化并添加单测**：避免文案漂移（i18n、同事改文案）导致误重连

**实现要求**：

**后端常量**：`backend/app/constants.py`
```python
# WebSocket关闭码协议契约
WS_CLOSE_CODE_NORMAL = 1000  # 正常关闭（仅用于"新连接替换"场景）
WS_CLOSE_CODE_HEARTBEAT_TIMEOUT = 4001  # 心跳超时（应用自定义，需要重连）
WS_CLOSE_CODE_AUTH_FAILED = 1008  # 认证失败（协议错误）

# 关闭原因（固定文案，禁止修改）
WS_CLOSE_REASON_NEW_CONNECTION = "New connection established"  # 新连接替换，前端不重连
WS_CLOSE_REASON_HEARTBEAT_TIMEOUT = "Heartbeat timeout"  # 心跳超时，前端需要重连
WS_CLOSE_REASON_AUTH_FAILED = "Authentication failed"  # 认证失败统一文案
WS_CLOSE_REASON_TOKEN_EXPIRED = "Token expired"  # Token过期，可恢复
WS_CLOSE_REASON_TOKEN_INVALID = "Token invalid"  # Token无效，不可恢复
```

**前端常量**：`frontend/src/constants/websocket.ts`
```typescript
// WebSocket关闭码协议契约（必须与后端一致）
export const WS_CLOSE_CODE_NORMAL = 1000;  // 正常关闭（仅用于"新连接替换"）
export const WS_CLOSE_CODE_HEARTBEAT_TIMEOUT = 4001;  // 心跳超时（需要重连）
export const WS_CLOSE_CODE_AUTH_FAILED = 1008;  // 认证失败

// 关闭原因（固定文案，禁止修改）
export const WS_CLOSE_REASON_NEW_CONNECTION = "New connection established"; // 新连接替换，前端不重连
export const WS_CLOSE_REASON_HEARTBEAT_TIMEOUT = "Heartbeat timeout"; // 心跳超时，前端需要重连
export const WS_CLOSE_REASON_AUTH_FAILED = "Authentication failed";
export const WS_CLOSE_REASON_TOKEN_EXPIRED = "Token expired";
export const WS_CLOSE_REASON_TOKEN_INVALID = "Token invalid";

// 单测覆盖
describe('WebSocket close reason', () => {
  it('should not reconnect on new connection replacement', () => {
    const event = { code: WS_CLOSE_CODE_NORMAL, reason: WS_CLOSE_REASON_NEW_CONNECTION };
    // 验证不触发重连
  });
  
  it('should reconnect on heartbeat timeout', () => {
    const event = { code: WS_CLOSE_CODE_HEARTBEAT_TIMEOUT, reason: WS_CLOSE_REASON_HEARTBEAT_TIMEOUT };
    // 验证触发重连
  });
});
```

**后端单测**：`backend/tests/test_websocket.py`
```python
def test_close_old_connection_with_fixed_reason():
    """测试关闭旧连接使用固定reason"""
    reason = close_old_connection(old_ws, user_id)
    assert reason == WS_CLOSE_REASON_NEW_CONNECTION
```

#### 方案2：修改后端关闭码（⚠️ 已整合到方案1，此处仅作历史参考）

**修改位置**：`backend/app/main.py:570`

**⚠️ 注意**：此方案已整合到方案1（原子替换）中，实际实现请参考方案1的`close_old_connection()`函数。

**历史修改内容**（已整合到方案1）：
```python
# ⚠️ 旧代码（已废弃）：使用code=1001会导致前端重连
# await old_websocket.close(code=1001, reason="New connection established")

# ✅ 正确做法（已在方案1中实现）：使用code=1000 + 固定reason
# from app.constants import WS_CLOSE_CODE_NORMAL, WS_CLOSE_REASON_NEW_CONNECTION
# await old_websocket.close(
#     code=WS_CLOSE_CODE_NORMAL, 
#     reason=WS_CLOSE_REASON_NEW_CONNECTION
# )
```

**注意**：必须保证reason文案固定，作为协议契约。实际实现请使用方案1。

#### 方案3：前端识别新连接替换场景（必须实现）

**修改位置**：`frontend/src/utils/WebSocketManager.ts:109-119`

**修改内容**：
```typescript
// 协议契约：后端使用 code=1000 + reason="New connection established" 表示新连接替换
import { 
  WS_CLOSE_CODE_NORMAL,
  WS_CLOSE_CODE_HEARTBEAT_TIMEOUT,
  WS_CLOSE_REASON_NEW_CONNECTION,
  WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
} from '../constants/websocket';

this.ws.onclose = (event) => {
  this.cleanup();

  // ⚠️ 先清理旧的定时器，防止多定时器并存
  if (this.reconnectTimeout) {
    clearTimeout(this.reconnectTimeout);
    this.reconnectTimeout = null;
  }
  
  // 检查是否是"新连接替换"场景（协议契约）
  // ⚠️ 统一：只在 code===1000 && reason===NEW_CONNECTION 时不重连
  const isNewConnectionReplacement = event.code === WS_CLOSE_CODE_NORMAL && 
    event.reason === WS_CLOSE_REASON_NEW_CONNECTION;
  
  // 如果是新连接替换，不触发重连
  if (isNewConnectionReplacement) {
    console.debug('WebSocket closed due to new connection replacement, no reconnect');
    return;
  }
  
  // 检查是否是心跳超时（需要重连）
  const isHeartbeatTimeout = event.code === WS_CLOSE_CODE_HEARTBEAT_TIMEOUT;
  
  // 只在异常关闭或心跳超时时重连（排除正常关闭且不是新连接替换的情况）
  if ((event.code !== WS_CLOSE_CODE_NORMAL || isHeartbeatTimeout) && 
      this.userId && 
      this.reconnectAttempts < this.maxReconnectAttempts) {
    this.reconnectAttempts++;
    
    // 指数回退 + 抖动（jitter），避免同步风暴
    const baseDelay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
    const jitter = Math.random() * 1000; // 0-1秒随机抖动
    const delay = baseDelay + jitter;
    
    // ⚠️ 检查窗口可见性和网络状态
    if (document.hidden || !navigator.onLine) {
      // 窗口隐藏或离线，延迟重连
      this.reconnectTimeout = setTimeout(() => {
        if (!document.hidden && navigator.onLine) {
          this.doConnect();
        }
      }, delay);
      return;
    }
    
    this.reconnectTimeout = setTimeout(() => {
      this.doConnect();
    }, delay);
  }
};
```

**关键点**：
- reason必须精确匹配，作为协议契约
- 使用指数回退 + 抖动，避免重连风暴
- 最大延迟限制在30秒

#### 方案4：添加连接状态检查（防止重复连接）

**修改位置**：`frontend/src/utils/WebSocketManager.ts:40-60`

**修改内容**：
```typescript
public connect(userId: string): void {
  // ⚠️ 先清理旧的定时器，防止多条计时器并发
  if (this.reconnectTimeout) {
    clearTimeout(this.reconnectTimeout);
    this.reconnectTimeout = null;
  }
  
  // 如果已经连接到同一个用户且连接正常，不需要重新连接
  if (this.ws && 
      this.userId === userId && 
      this.ws.readyState === WebSocket.OPEN) {
    console.debug('WebSocket already connected to user', userId);
    return;
  }

  // 如果正在连接中，等待完成
  if (this.ws && this.ws.readyState === WebSocket.CONNECTING) {
    console.debug('WebSocket connection in progress, waiting...');
    return;
  }

  // 如果连接到不同用户，先断开旧连接
  if (this.ws && this.userId !== userId) {
    this.disconnect();
  }

  // 如果已有连接但未打开，先清理
  if (this.ws) {
    this.cleanup();
  }

  this.userId = userId;
  this.reconnectAttempts = 0;

  this.doConnect();
}
```

#### 方案5：服务端心跳与超时机制（⚠️ 避免与业务receive竞争）

**修改位置**：`backend/app/main.py`（心跳循环）

**⚠️ 关键问题**：心跳不能与业务receive竞争同一条连接，否则会出现"心跳协程把业务消息读走"的竞态。

**方案A：使用底层ping/pong帧（推荐）**

```python
async def heartbeat_loop(websocket: WebSocket, user_id: str):
    """心跳循环，使用底层ping/pong帧，不与业务消息竞争"""
    ping_interval = 20  # 20秒发送一次ping
    max_missing_pongs = 3  # 连续3次未收到pong才断开
    
    missing_pongs = 0
    last_pong_time = time.time()
    
    try:
        while True:
            await asyncio.sleep(ping_interval)
            
            try:
                # ⚠️ 使用框架自带的ping方法（不是send_text("")，空文本是业务帧不是ping帧）
                # FastAPI/Starlette的WebSocket支持ping/pong帧
                try:
                    # 如果框架支持ping方法
                    await websocket.ping()
                except AttributeError:
                    # 如果框架不支持，使用方案B（在业务循环中统一处理）
                    logger.warning("WebSocket框架不支持ping方法，请使用方案B（业务循环统一处理）")
                    break
                
                # 检查上次pong时间（由框架自动处理pong响应）
                current_time = time.time()
                if current_time - last_pong_time > ping_interval * max_missing_pongs:
                    missing_pongs += 1
                    logger.warning(f"Missing pong for user {user_id}, count: {missing_pongs}")
                    
                    if missing_pongs >= max_missing_pongs:
                        logger.warning(f"Too many missing pongs for user {user_id}, closing connection")
                        # ⚠️ 使用非1000的关闭码，前端需要重连
                        from app.constants import WS_CLOSE_CODE_HEARTBEAT_TIMEOUT, WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                        await websocket.close(
                            code=WS_CLOSE_CODE_HEARTBEAT_TIMEOUT, 
                            reason=WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                        )
                        break
                else:
                    missing_pongs = 0  # 重置计数
                    last_pong_time = current_time
                    
            except Exception as e:
                logger.error(f"Heartbeat error for user {user_id}: {e}")
                break
    except asyncio.CancelledError:
        logger.debug(f"Heartbeat cancelled for user {user_id}")
    except Exception as e:
        logger.error(f"Heartbeat loop error for user {user_id}: {e}")
```

**方案B：业务循环统一处理（⚠️ 仅在框架不支持ping/pong帧时使用）**

```python
# ⚠️ 仅在框架不支持websocket.ping()时使用此方案
# ⚠️ 严禁与方案A同时使用，避免并发两条循环竞争receive
# 在业务消息循环中统一处理心跳和业务消息
async def websocket_chat(websocket: WebSocket, user_id: str, db: Session = Depends(get_db)):
    # ... 认证逻辑 ...
    
    await websocket.accept()
    active_connections[user_id] = websocket
    
    last_ping_time = time.time()
    ping_interval = 20
    missing_pongs = 0
    max_missing_pongs = 3
    
    try:
        while True:
            # 检查是否需要发送ping（使用业务帧，仅在框架不支持ping时）
            current_time = time.time()
            if current_time - last_ping_time >= ping_interval:
                # ⚠️ 仅在框架不支持websocket.ping()时使用send_json
                await websocket.send_json({"type": "ping"})
                last_ping_time = current_time
            
            # 统一接收消息（心跳和业务消息都在这里处理，避免竞争）
            try:
                data = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=5.0
                )
                
                msg = json.loads(data)
                
                # 处理pong响应
                if msg.get("type") == "pong":
                    missing_pongs = 0
                    continue
                
                # 处理业务消息
                # ... 业务逻辑 ...
                
            except asyncio.TimeoutError:
                # 超时检查pong
                missing_pongs += 1
                if missing_pongs >= max_missing_pongs:
                    # ⚠️ 使用非1000的关闭码（4001），前端需要重连
                    from app.constants import WS_CLOSE_CODE_HEARTBEAT_TIMEOUT, WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                    await websocket.close(
                        code=WS_CLOSE_CODE_HEARTBEAT_TIMEOUT,
                        reason=WS_CLOSE_REASON_HEARTBEAT_TIMEOUT
                    )
                    break
            except Exception as e:
                logger.error(f"Error receiving message: {e}")
                break
    finally:
        active_connections.pop(user_id, None)
```

**关键点**：
- ⚠️ **心跳不能与业务receive竞争**：要么用底层ping/pong帧，要么在业务循环中统一处理
- 避免心跳协程把业务消息读走
- 提高连接稳定性

#### 方案6：多标签页协调（⚠️ 下阶段实现，第一阶段不实施）

**实现方式**：使用 BroadcastChannel API

**修改位置**：`frontend/src/utils/WebSocketManager.ts`

**⚠️ 状态**：此方案包含TODO（tryBecomeMaster未完成），第一阶段不实施，避免误入未完成策略。

**⚠️ 产品决策要求**：必须在第一阶段明确决策：
- **选项A**：每用户仅需一条实时链路 → 下阶段实现"主标签"模式
- **选项B**：允许多标签共存 → 隔离主题（如客服页与聊天页分频道）

**下阶段实现示例**（仅供参考，第一阶段不实施）：
```typescript
// ⚠️ 下阶段实现：如果产品要求每用户只需一条连接，使用BroadcastChannel协调
class WebSocketManager {
  private broadcastChannel: BroadcastChannel | null = null;
  private isMasterTab: boolean = false;
  
  private constructor() {
    if (typeof BroadcastChannel !== 'undefined') {
      this.broadcastChannel = new BroadcastChannel('websocket-coordination');
      this.broadcastChannel.onmessage = (event) => {
        if (event.data.type === 'ws_message') {
          // 从主标签接收消息
          this.messageHandlers.forEach(handler => handler(event.data.message));
        }
      };
      
      // ⚠️ TODO: 实现主标签选举逻辑
      // this.tryBecomeMaster();
    }
  }
  
  // ⚠️ TODO: 实现主标签选举
  // private tryBecomeMaster(): void {
  //   // 发送"我想成为主标签"消息
  //   // 如果没有其他标签响应，成为主标签
  //   // 实现细节...
  // }
  
  public connect(userId: string): void {
    // ⚠️ 下阶段：如果不是主标签，不建立连接，通过BroadcastChannel接收消息
    // if (!this.isMasterTab && this.broadcastChannel) {
    //   return;
    // }
    
    // 主标签建立连接
    // ... 原有逻辑 ...
  }
}
```

**建议**：在第一阶段结尾明确此项决策，下阶段再实施。

#### 方案7：Token过期处理（固化码→动作映射）

**修改位置**：`frontend/src/utils/WebSocketManager.ts` 和认证相关代码

**要求**：服务端对鉴权失败统一返回相同关闭码/文案，前端固化码→动作映射。

**后端统一关闭码**：已在上面常量定义中统一

**前端码→动作映射**：`frontend/src/utils/WebSocketManager.ts`
```typescript
import { 
  WS_CLOSE_CODE_NORMAL,
  WS_CLOSE_CODE_HEARTBEAT_TIMEOUT,
  WS_CLOSE_CODE_AUTH_FAILED,
  WS_CLOSE_REASON_NEW_CONNECTION,
  WS_CLOSE_REASON_HEARTBEAT_TIMEOUT,
  WS_CLOSE_REASON_AUTH_FAILED,
  WS_CLOSE_REASON_TOKEN_EXPIRED 
} from '../constants/websocket';

// 关闭码→动作映射（固化常量）
const CLOSE_CODE_ACTIONS: Record<number, {
  recoverable: string[];
  action: (reason: string) => Promise<void>;
}> = {
  [WS_CLOSE_CODE_AUTH_FAILED]: {
    recoverable: [WS_CLOSE_REASON_TOKEN_EXPIRED],  // 可恢复：刷新token
    action: async (reason: string) => {
      if (CLOSE_CODE_ACTIONS[WS_CLOSE_CODE_AUTH_FAILED].recoverable.includes(reason)) {
        try {
          await refreshToken();
          if (this.userId) {
            this.doConnect();
          }
        } catch (error) {
          // 刷新失败，不可恢复
          window.location.href = '/login';
        }
      } else {
        // 不可恢复：直接跳转登录
        window.location.href = '/login';
      }
    }
  },
  [WS_CLOSE_CODE_HEARTBEAT_TIMEOUT]: {
    recoverable: [],
    action: async () => {
      // 心跳超时，直接重连（已在主逻辑中处理）
    }
  }
};

this.ws.onclose = async (event) => {
  this.cleanup();
  
  // 检查是否是"新连接替换"（不重连）
  if (event.code === WS_CLOSE_CODE_NORMAL && 
      event.reason === WS_CLOSE_REASON_NEW_CONNECTION) {
    return;
  }
  
  // 检查是否是认证失败
  if (event.code === WS_CLOSE_CODE_AUTH_FAILED) {
    const action = CLOSE_CODE_ACTIONS[event.code];
    if (action) {
      await action.action(event.reason);
    }
    return;
  }
  
  // 心跳超时和其他异常关闭，触发重连（在主逻辑中处理）
  // ... 其他关闭处理 ...
};
```

### 推荐修复步骤

1. **立即修复（关键）**：
   - 采用方案1（服务端原子替换）+ 方案2（修改关闭码为1000，删除旧1001代码）
   - 采用方案3（前端识别新连接替换场景）
   - 必须保证reason文案固定，作为协议契约
   - ⚠️ 统一使用WS_CLOSE_CODE_NORMAL=1000，删除重复常量定义

2. **短期优化（1-2周）**：
   - 采用方案4（连接状态检查）
   - 采用方案5（服务端心跳机制）
   - 采用方案7（Token过期处理）

3. **长期优化（根据需求）**：
   - 考虑方案6（多标签页协调），如果产品要求每用户单连接

---

## 🔴 问题2：频繁读取用户Profile

### 问题描述

**现象**：
- 日志中大量出现 `GET /api/users/profile/me` 请求
- 几乎每30-60秒就有一次请求
- 多个不同的IP地址（100.64.0.x）同时请求

**日志示例**：
```
2025-11-16T18:02:46.091910485Z [inf]  INFO:     100.64.0.6:45220 - "GET /api/users/profile/me HTTP/1.1" 200 OK
2025-11-16T18:02:46.091918445Z [inf]  INFO:     100.64.0.6:45238 - "GET /api/users/profile/me HTTP/1.1" 200 OK
2025-11-16T18:02:46.091925989Z [inf]  INFO:     100.64.0.6:45242 - "GET /api/users/profile/me HTTP/1.1" 200 OK
2025-11-16T18:03:46.203630150Z [inf]  INFO:     100.64.0.6:32124 - "GET /api/users/profile/me HTTP/1.1" 200 OK
```

### 根本原因分析

#### 原因1：多个组件独立轮询用户信息

**位置1**：`frontend/src/contexts/UnreadMessageContext.tsx:58-62`
```typescript
// 每60秒检查一次用户登录状态
const interval = setInterval(() => {
  if (!isAdminOrServicePage()) {
    loadUser(); // 调用 fetchCurrentUser()
  }
}, 60000);
```

**位置2**：`frontend/src/components/ProtectedRoute.tsx:30-33`
```typescript
// 每个受保护的路由都会调用
const response = await Promise.race([
  api.get('/api/users/profile/me'),
  timeoutPromise
]);
```

**位置3**：多个页面组件在挂载时调用
- `Settings.tsx` - 加载时调用
- `Home.tsx` - 可能调用
- `Tasks.tsx` - 可能调用
- 等等...

#### 原因2：缓存机制不统一

**问题**：
- `fetchCurrentUser()` 虽然有5分钟缓存，但多个组件可能绕过缓存
- `ProtectedRoute` 直接调用 `api.get()`，不经过缓存层
- 时间戳参数可能绕过缓存（如 `Settings.tsx:139` 使用 `_t: Date.now()`）

**当前缓存实现**：`frontend/src/api.ts:501-512`
```typescript
export async function fetchCurrentUser() {
  return cachedRequest(
    '/api/users/profile/me',
    async () => {
      const res = await api.get('/api/users/profile/me');
      return res.data;
    },
    CACHE_TTL.USER_INFO, // 5分钟缓存
    undefined,
    DEFAULT_DEBOUNCE_MS // 300ms防抖
  );
}
```

#### 原因3：未读消息轮询依赖用户对象

**位置**：`frontend/src/contexts/UnreadMessageContext.tsx:139-149`
```typescript
// 每10秒刷新未读消息
const interval = setInterval(() => {
  if (!document.hidden && !isAdminOrServicePage()) {
    refreshUnreadCount(); // 需要 user 对象
  }
}, 10000);
```

### 修复方案

#### 方案1：统一数据访问层（强烈推荐使用SWR/React Query）+ 硬约束

**⚠️ 硬约束要求**：
1. 在 `api.ts` 给 `/api/users/profile/me` 做轻量代理，其他模块直接import该函数
2. 用ESLint rule或代码搜索守门（CI fail）拦截直接写 `api.get('/api/users/profile/me')` 的提交

**ESLint规则示例**：`.eslintrc.js`
```javascript
rules: {
  // ⚠️ 更精确的匹配，避免误杀其他模块导入
  'no-restricted-syntax': [
    'error',
    {
      // 精确匹配 api.get('/api/users/profile/me') 调用
      selector: "CallExpression[callee.object.name='api'][callee.property.name='get'] > Literal[value='/api/users/profile/me']",
      message: '请使用 fetchCurrentUser() 而不是直接调用 api.get("/api/users/profile/me")',
    },
    {
      // 匹配 api.get('/api/users/profile/me', ...) 带参数的情况
      selector: "CallExpression[callee.object.name='api'][callee.property.name='get'] > ArrayExpression > Literal[value='/api/users/profile/me']",
      message: '请使用 fetchCurrentUser() 而不是直接调用 api.get("/api/users/profile/me")',
    },
  ],
}
```

**代码搜索守门**：`.github/workflows/lint.yml`
```yaml
- name: Check direct profile API calls
  run: |
    if grep -r "api\.get.*['\"]/api/users/profile/me" frontend/src --exclude-dir=node_modules --exclude="api.ts"; then
      echo "❌ 发现直接调用 /api/users/profile/me，请使用 fetchCurrentUser()"
      exit 1
    fi
```

**推荐使用SWR或React Query**，而不是自研缓存层，原因：
- Battle-tested，经过大量项目验证
- 自带去重、stale-while-revalidate、focus/online revalidate
- 自动处理错误重试节流
- 自动处理 document.hidden、window.focus 等边界情况

**使用SWR示例**：
```typescript
// frontend/src/hooks/useUser.ts
import useSWR from 'swr';

const fetcher = (url: string) => api.get(url).then(res => res.data);

export function useUser() {
  const { data: user, error, mutate } = useSWR(
    '/api/users/profile/me',
    fetcher,
    {
      revalidateOnFocus: true,      // 窗口聚焦时重新验证
      revalidateOnReconnect: true,  // 网络重连时重新验证
      dedupingInterval: 5000,       // 5秒内去重
      refreshInterval: 300000,      // 5分钟自动刷新
      errorRetryCount: 3,
      errorRetryInterval: 5000,
    }
  );

  return {
    user,
    isLoading: !error && !user,
    isError: error,
    refresh: mutate,
  };
}

// 在组件中使用
function MyComponent() {
  const { user, isLoading } = useUser();
  // ...
}
```

**优点**：
- 自动去重：多个组件同时调用时，只发送一次请求
- 自动缓存：所有组件共享同一份数据
- 智能刷新：窗口聚焦、网络重连时自动刷新
- 错误处理：自动重试，带节流

#### 方案1b：自研UserContext（如果不想引入新依赖）

**创建全局用户Context**：`frontend/src/contexts/UserContext.tsx`

**功能**：
- 统一管理用户状态
- 提供全局用户数据
- 自动处理缓存和更新

**实现要点**：
```typescript
// 伪代码示例
export const UserProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [lastUpdate, setLastUpdate] = useState(0);
  
  // 统一的获取用户方法，带缓存
  const fetchUser = useCallback(async () => {
    const now = Date.now();
    // 如果5分钟内更新过，直接返回缓存
    if (user && (now - lastUpdate) < 5 * 60 * 1000) {
      return user;
    }
    
    const userData = await fetchCurrentUser();
    setUser(userData);
    setLastUpdate(now);
    return userData;
  }, [user, lastUpdate]);
  
  // 提供刷新方法
  const refreshUser = useCallback(async () => {
    const userData = await fetchCurrentUser();
    setUser(userData);
    setLastUpdate(Date.now());
  }, []);
  
  return (
    <UserContext.Provider value={{ user, fetchUser, refreshUser }}>
      {children}
    </UserContext.Provider>
  );
};
```

#### 方案2：优化轮询频率

**修改位置1**：`frontend/src/contexts/UnreadMessageContext.tsx:58-62`

**修改内容**：
```typescript
// 修改前：每60秒检查一次
const interval = setInterval(() => {
  if (!isAdminOrServicePage()) {
    loadUser();
  }
}, 60000);

// 修改后：每5-10分钟检查一次，或使用WebSocket推送
const interval = setInterval(() => {
  if (!isAdminOrServicePage() && !document.hidden) {
    loadUser();
  }
}, 300000); // 5分钟
```

**修改位置2**：`frontend/src/components/ProtectedRoute.tsx`

**修改内容**：
```typescript
// 修改前：直接调用api.get
const response = await Promise.race([
  api.get('/api/users/profile/me'),
  timeoutPromise
]);

// 修改后：使用缓存的fetchCurrentUser
const response = await Promise.race([
  fetchCurrentUser(),
  timeoutPromise
]);
```

#### 方案3：移除时间戳参数

**修改位置**：`frontend/src/pages/Settings.tsx:139`

**修改内容**：
```typescript
// 修改前
const userResponse = await api.get('/api/users/profile/me', {
  params: { _t: Date.now() } // 添加时间戳避免缓存
});

// 修改后：使用fetchCurrentUser，利用缓存
const userData = await fetchCurrentUser();
```

#### 方案4：服务端协商缓存（ETag/If-None-Match）

**修改位置**：`backend/app/routers.py:1565` (get_my_profile)

**修改内容**：
```python
from fastapi import Response
from hashlib import md5
import json

@router.get("/profile/me", response_model=schemas.UserOut)
def get_my_profile(
    request: Request,
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db),
    response: Response = None
):
    # 获取用户数据
    # ... 原有逻辑 ...
    
    # 生成ETag
    user_json = json.dumps(formatted_user, sort_keys=True)
    etag = md5(user_json.encode()).hexdigest()
    
    # 检查If-None-Match
    if_none_match = request.headers.get("If-None-Match")
    if if_none_match == etag:
        # ⚠️ 统一：304必须直接return Response对象，不return None
        from fastapi import Response
        return Response(
            status_code=304, 
            headers={
                "ETag": etag,
                "Cache-Control": "private, max-age=300",
                "Vary": "Cookie"
            }
        )
    
    # 设置响应头
    response.headers["ETag"] = etag
    response.headers["Cache-Control"] = "private, max-age=300"  # 5分钟，配合Vary避免CDN误缓存
    response.headers["Vary"] = "Cookie"  # 避免中间层误缓存
    
    return formatted_user
```

**优点**：
- 304响应时网络和CPU压力都低
- 浏览器自动处理ETag
- 配合SWR使用效果更好

#### 方案5：使用WebSocket推送用户状态变化

**实现**：
- 当用户信息更新时，通过WebSocket推送
- 前端收到推送后更新本地缓存（SWR的mutate）
- 减少轮询频率

#### 方案6：未读数刷新解耦（请求参数化，与用户态弱耦合）

**修改位置**：`frontend/src/contexts/UnreadMessageContext.tsx:139-149`

**问题**：未读数刷新强依赖完整Profile对象

**前端修改**：
```typescript
// 修改前：需要完整user对象
const refreshUnreadCount = useCallback(async () => {
  if (!user) {
    setUnreadCount(0);
    return;
  }
  // ...
}, [user]);

// 修改后：只需userId（可从上下文或localStorage获取），不依赖user缓存
const refreshUnreadCount = useCallback(async () => {
  const userId = user?.id || getUserIdFromContext();
  if (!userId) {
    setUnreadCount(0);
    return;
  }
  
  try {
    // 服务器用鉴权主体推断userId，前端无需传参
    const response = await api.get('/api/users/messages/unread/count');
    const count = response.data.unread_count || 0;
    setUnreadCount(count);
  } catch (error) {
    // 静默处理错误
  }
}, []); // 不再依赖user对象，即使user缓存陈旧也能刷新

// 或者：优先使用WebSocket推送未读数
useEffect(() => {
  const unsubscribe = WebSocketManager.subscribe((msg) => {
    if (msg.type === 'unread_count_update') {
      setUnreadCount(msg.count);
    }
  });
  return unsubscribe;
}, []);
```

**后端修改**：`backend/app/routers.py`（未读数接口）
```python
@router.get("/messages/unread/count")
def get_unread_count(
    current_user=Depends(get_current_user_secure_sync_csrf),
    db: Session = Depends(get_db)
):
    """获取未读消息数，服务器用鉴权主体推断userId，与用户态弱耦合"""
    # 直接从current_user获取userId，不依赖前端传参
    count = crud.get_unread_message_count(db, current_user.id)
    return {"unread_count": count}
```

**关键点**：
- 前端即便user缓存陈旧，也不必先await user
- 服务器用鉴权主体推断userId，前端无需传参
- 作为第一阶段的具体改动项

#### 方案7：ProtectedRoute超时与降级

**修改位置**：`frontend/src/components/ProtectedRoute.tsx`

**修改内容**：
```typescript
const checkAuth = async () => {
  // ⚠️ 使用ReturnType<typeof setTimeout>，避免浏览器环境类型不匹配
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  
  try {
    const timeoutPromise = new Promise((_, reject) => {
      timeoutId = setTimeout(() => {
        reject(new Error('认证检查超时'));
      }, 10000);
    });

    const response = await Promise.race([
      fetchCurrentUser().finally(() => {
        // ⚠️ 请求完成时清理定时器
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
      }),
      timeoutPromise
    ]) as any;
    
    // ⚠️ 清理定时器
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
    
    // ⚠️ isMounted守卫，避免在卸载组件上setState
    if (isMounted) {
      setIsAuthenticated(true);
      setLoading(false);
    }
  } catch (error: any) {
    // ⚠️ 清理定时器
    if (timeoutId) {
      clearTimeout(timeoutId);
      timeoutId = null;
    }
    
    if (!isMounted) return;
    
    // 超时后的UX处理
    if (error.message === '认证检查超时') {
      // 选项1：显示骨架屏，允许用户继续使用（如果之前已认证）
      // 选项2：跳转登录页
      // 选项3：显示离线模式提示
      console.warn('Auth check timeout, using cached state');
      // 这里可以根据业务需求选择策略
    }
    
    if (error.response?.status !== 401 && error.message !== '认证检查超时') {
      console.debug('ProtectedRoute 认证检查失败（非401）:', error);
    }
    setIsAuthenticated(false);
    setLoading(false);
  }
};
```

### 推荐修复步骤

1. **立即修复**：
   - 修改 `UnreadMessageContext.tsx` 轮询间隔为5分钟
   - 修改 `ProtectedRoute.tsx` 使用 `fetchCurrentUser()` 而不是直接调用
   - 移除 `Settings.tsx` 中的时间戳参数
   - 实现方案6（未读数刷新解耦）

2. **短期优化（1-2周）**：
   - **强烈推荐**：引入SWR或React Query（方案1）
   - 实现服务端协商缓存（方案4）
   - 实现WebSocket推送用户状态（方案5）
   - 完善ProtectedRoute超时处理（方案7）

3. **长期优化**：
   - 如果不想引入新依赖，使用自研UserContext（方案1b）
   - 监控ETag命中率和304比例

---

## 🔴 问题3：Redis键无法解析

### 问题描述

**现象**：
```
2025-11-16T18:25:15.453179002Z [err]  INFO:app.user_redis_cleanup:[USER_REDIS_CLEANUP] 删除无法解析的缓存数据: user:98921543
2025-11-16T18:25:15.453184223Z [err]  INFO:app.user_redis_cleanup:[USER_REDIS_CLEANUP] 删除无法解析的缓存数据: user:27167013
```

### 根本原因分析

#### 原因1：数据格式不匹配

**位置**：`backend/app/user_redis_cleanup.py:138-192`

**当前逻辑**：
```python
data = self._get_redis_data(key_str)  # 尝试pickle → JSON → orjson解析

if data is None:
    # 数据无法解析，直接删除
    self.redis_client.delete(key_str)
```

**问题**：
- `user:*` 键可能使用pickle格式存储（通过 `redis_cache.set`）
- 但某些情况下数据可能损坏或格式不正确
- `_get_redis_data()` 方法可能无法正确解析所有格式

#### 原因2：数据写入和读取格式不一致

**可能的情况**：
- 写入时使用pickle
- 读取时尝试JSON解析
- 导致数据无法正确解析

#### 原因3：数据损坏或过期

**可能的原因**：
- Redis内存不足导致数据损坏
- 数据写入过程中断
- 数据格式版本不匹配

### 修复方案

#### 方案1：增强解析逻辑（⚠️ 安全性：禁止反序列化不可信pickle）

**修改位置**：`backend/app/user_redis_cleanup.py:_get_redis_data()`

**⚠️ 安全警告**：
- **严禁在线上读路径使用pickle.loads反序列化不可信数据**
- pickle反序列化可执行任意代码，存在严重安全风险
- 清理脚本中如需兼容旧数据，必须：
  1. 限定白名单key前缀
  2. 检查魔数和版本号
  3. 在隔离进程中进行
  4. 只做"读字段→迁移JSON"，绝不复用pickle到线上读路径

**修改内容**：
```python
def _get_redis_data(self, key: str) -> Dict[str, Any] | None:
    """获取Redis数据，支持多种格式（安全版本）"""
    try:
        raw_data = self.redis_client.get(key)
        if not raw_data:
            return None
        
        # 检查是否是压缩数据（gzip/zlib）
        # ⚠️ 解压安全：增加输入/输出大小上限，避免"压缩炸弹"
        MAX_COMPRESSED_SIZE = 10 * 1024 * 1024  # 10MB上限
        MAX_DECOMPRESSED_SIZE = 100 * 1024 * 1024  # 100MB上限
        
        if isinstance(raw_data, bytes) and len(raw_data) > 2:
            # ⚠️ 检查输入大小
            if len(raw_data) > MAX_COMPRESSED_SIZE:
                logger.warning(f"[USER_REDIS_CLEANUP] 压缩数据过大: {key}, size: {len(raw_data)}")
                return None
            
            decompressed = None
            # 检查gzip魔数 \x1f\x8b
            if raw_data[:2] == b'\x1f\x8b':
                try:
                    import gzip
                    decompressed = gzip.decompress(raw_data)
                    # ⚠️ 检查输出大小
                    if len(decompressed) > MAX_DECOMPRESSED_SIZE:
                        logger.warning(f"[USER_REDIS_CLEANUP] 解压后数据过大: {key}, size: {len(decompressed)}")
                        return None
                except Exception as e:
                    logger.warning(f"[USER_REDIS_CLEANUP] 解压gzip失败 {key}: {e}")
                    # ⚠️ 解压失败不重试超过一次，任何异常都不要写回
                    return None
            
            # 检查zlib魔数
            elif raw_data[0] == 0x78:  # zlib常见起始字节
                try:
                    import zlib
                    decompressed = zlib.decompress(raw_data)
                    # ⚠️ 检查输出大小
                    if len(decompressed) > MAX_DECOMPRESSED_SIZE:
                        logger.warning(f"[USER_REDIS_CLEANUP] 解压后数据过大: {key}, size: {len(decompressed)}")
                        return None
                except Exception as e:
                    logger.warning(f"[USER_REDIS_CLEANUP] 解压zlib失败 {key}: {e}")
                    # ⚠️ 解压失败不重试超过一次，任何异常都不要写回
                    return None
            
            # ⚠️ 仅在确认解压成功后再使用
            if decompressed is not None:
                raw_data = decompressed
        
        # 尝试1：JSON格式（优先，安全）
        try:
            import json
            if isinstance(raw_data, bytes):
                raw_data = raw_data.decode('utf-8')
            data = json.loads(raw_data)
            if isinstance(data, dict):
                return data
        except (json.JSONDecodeError, UnicodeDecodeError):
            pass
        
        # 尝试2：orjson格式
        try:
            import orjson
            data = orjson.loads(raw_data)
            if isinstance(data, dict):
                return data
        except (orjson.JSONDecodeError, TypeError):
            pass
        
        # 尝试3：如果是字符串，可能是双重编码
        if isinstance(raw_data, str):
            try:
                data = json.loads(raw_data)
                if isinstance(data, str):
                    # 双重编码，再次解析
                    data = json.loads(data)
                if isinstance(data, dict):
                    return data
            except (json.JSONDecodeError, TypeError):
                pass
        
        # ⚠️ 尝试4：pickle格式（仅限隔离进程，必选校验）
        # ⚠️ 清理脚本运行在单独容器或一组隔离worker，且使用只读凭证
        # ⚠️ 白名单前缀 + 魔数检查 + schema_version 写成必选校验（不是"尝试性"）
        ALLOWED_PICKLE_PREFIXES = ['user:', 'user_cache:']  # 白名单
        PICKLE_MAGIC = b'\x80'  # pickle协议2+的魔数
        
        if any(key.startswith(prefix) for prefix in ALLOWED_PICKLE_PREFIXES):
            # ⚠️ 必选校验1：检查魔数
            if not (isinstance(raw_data, bytes) and raw_data.startswith(PICKLE_MAGIC)):
                logger.warning(f"[USER_REDIS_CLEANUP] Pickle魔数不匹配: {key}")
                return None
            
            try:
                import pickle
                # ⚠️ 在隔离环境中反序列化（仅用于迁移）
                data = pickle.loads(raw_data)
                
                # ⚠️ 必选校验2：检查schema_version（如果存在）
                if isinstance(data, dict):
                    # 检查是否有schema_version字段
                    if 'schema_version' in data:
                        schema_version = data.get('schema_version')
                        if schema_version not in ['1', '1.0']:  # 只允许v1格式
                            logger.warning(f"[USER_REDIS_CLEANUP] Pickle schema_version不匹配: {key}, version: {schema_version}")
                            return None
                    
                    # ⚠️ 立即迁移为JSON格式（仅在确认解析成功后）
                    self._migrate_to_json(key, data)
                    return data
            except (pickle.UnpicklingError, TypeError, Exception) as e:
                logger.warning(f"[USER_REDIS_CLEANUP] Pickle解析失败 {key}: {e}")
                # ⚠️ 失败不写回，避免把损坏数据"定格"
        
        # 所有解析都失败
        logger.warning(f"[USER_REDIS_CLEANUP] 无法解析数据格式: {key}, 类型: {type(raw_data)}")
        return None
        
    except Exception as e:
        logger.error(f"[USER_REDIS_CLEANUP] 获取Redis数据失败 {key}: {e}")
        return None
    
    def _migrate_to_json(self, key: str, data: dict):
        """将pickle数据迁移为JSON格式（⚠️ 保留TTL，严禁固定ex=3600）"""
        try:
            import json
            # ⚠️ 先读取PTTL，保留原有过期时间（毫秒）
            ttl_ms = self.redis_client.pttl(key)
            if ttl_ms < 0:
                ttl_ms = 3600000  # 默认1小时（毫秒）
            
            json_data = json.dumps(data, ensure_ascii=False)
            
            # ⚠️ 使用PEXPIRE保留原有TTL，严禁使用set(..., ex=3600)重置寿命
            self.redis_client.set(key, json_data)
            if ttl_ms > 0:
                self.redis_client.pexpire(key, ttl_ms)
            
            logger.info(f"[USER_REDIS_CLEANUP] 迁移pickle到JSON: {key}, TTL: {ttl_ms}ms")
        except Exception as e:
            logger.error(f"[USER_REDIS_CLEANUP] 迁移失败 {key}: {e}")
```

#### 方案2：渐进迁移策略（读老写新 + 后台迁移）

**目标**：平滑迁移到JSON格式，不中断服务

**阶段1：读老写新（双写）**

**修改位置**：`backend/app/redis_cache.py`

**修改内容**：
```python
def set_user_cache(user_id: str, data: dict, ttl: int = 3600):
    """设置用户缓存（统一写JSON v2）"""
    try:
        import json
        # 验证数据格式
        if not isinstance(data, dict):
            raise ValueError("Data must be a dictionary")
        
        # 添加schema版本和内容类型标记
        cache_data = {
            "schema_version": "2",
            "content_type": "application/json",
            "data": data,
            "created_at": datetime.utcnow().isoformat()
        }
        
        # 序列化为JSON
        serialized = json.dumps(cache_data, ensure_ascii=False)
        
        # ⚠️ 写入Redis（v2格式）
        # ⚠️ 注意：通用写缓存接口可保留ex=ttl参数化（默认值可3600），但迁移路径必须用PTTL+PEXPIRE
        redis_client.set(f"user:{user_id}", serialized, ex=ttl)
        
        logger.debug(f"User cache written (v2 JSON): {user_id}")
    except Exception as e:
        logger.error(f"Failed to set user cache {user_id}: {e}")

def get_user_cache(user_id: str) -> dict | None:
    """获取用户缓存（优先读v2，失败读v1）"""
    key = f"user:{user_id}"
    
    try:
        raw_data = redis_client.get(key)
        if not raw_data:
            return None
        
        # 尝试解析v2 JSON格式
        try:
            import json
            if isinstance(raw_data, bytes):
                raw_data = raw_data.decode('utf-8')
            cache_data = json.loads(raw_data)
            
            if isinstance(cache_data, dict):
                # v2格式：包含schema_version
                if cache_data.get("schema_version") == "2":
                    return cache_data.get("data")
                # v1格式：直接是数据
                else:
                    # 旁路迁移：回写为v2格式
                    asyncio.create_task(migrate_to_v2(key, cache_data))
                    return cache_data
        except (json.JSONDecodeError, UnicodeDecodeError):
            pass
        
        # 尝试解析v1格式（仅限白名单key，带安全检查）
        # ... 安全解析逻辑 ...
        
        return None
    except Exception as e:
        logger.error(f"Failed to get user cache {user_id}: {e}")
        return None

async def migrate_to_v2(key: str, v1_data: dict):
    """旁路迁移：将v1数据迁移为v2格式（⚠️ 保留TTL，严禁固定ex=3600）"""
    try:
        import json
        # ⚠️ 先读取PTTL，保留原有过期时间（毫秒）
        ttl_ms = redis_client.pttl(key)
        if ttl_ms < 0:
            ttl_ms = 3600000  # 如果没有TTL，使用默认1小时（毫秒）
        
        cache_data = {
            "schema_version": "2",
            "content_type": "application/json",
            "data": v1_data,
            "created_at": datetime.utcnow().isoformat()
        }
        serialized = json.dumps(cache_data, ensure_ascii=False)
        
        # ⚠️ 使用PEXPIRE保留原有TTL（毫秒），严禁使用set(..., ex=3600)重置寿命
        redis_client.set(key, serialized)
        if ttl_ms > 0:
            redis_client.pexpire(key, ttl_ms)
        
        logger.info(f"Migrated cache to v2: {key}, TTL: {ttl_ms}ms")
    except Exception as e:
        logger.error(f"Migration failed {key}: {e}")
```

**阶段2：后台批量迁移**

**修改位置**：新建 `backend/app/redis_migration.py`

**修改内容**：
```python
async def batch_migrate_user_cache():
    """后台批量迁移用户缓存（⚠️ SCAN游标处理、批处理限流）"""
    cursor = 0
    batch_size = 100
    migrated_count = 0
    failed_count = 0
    
    # ⚠️ 批处理阈值：最大字节总量和最大时长
    MAX_BATCH_BYTES = 5 * 1024 * 1024  # 5MB
    MAX_BATCH_DURATION = 0.1  # 100ms
    
    while True:
        batch_start_time = time.time()
        batch_bytes = 0
        
        # ⚠️ 使用SCAN而不是KEYS，避免阻塞
        # ⚠️ SCAN返回的key多为bytes，需要decode
        cursor, keys = redis_client.scan(cursor, match="user:*", count=batch_size)
        
        # ⚠️ 使用pipeline批处理（transaction=False）
        pipe = redis_client.pipeline(transaction=False)
        
        for key in keys:
            # ⚠️ 处理bytes类型key
            key_str = key.decode('utf-8') if isinstance(key, bytes) else key
            
            try:
                raw_data = redis_client.get(key_str)
                if not raw_data:
                    continue
                
                # ⚠️ 检查批处理阈值
                data_size = len(raw_data) if raw_data else 0
                if batch_bytes + data_size > MAX_BATCH_BYTES:
                    break  # 超出字节限制，下一批处理
                
                if time.time() - batch_start_time > MAX_BATCH_DURATION:
                    break  # 超出时长限制，下一批处理
                
                batch_bytes += data_size
                
                # 检查是否已经是v2格式
                try:
                    import json
                    if isinstance(raw_data, bytes):
                        raw_data = raw_data.decode('utf-8')
                    data = json.loads(raw_data)
                    if isinstance(data, dict) and data.get("schema_version") == "2":
                        continue  # 已经是v2，跳过
                except:
                    pass
                
                # ⚠️ 读取PTTL，保留原有过期时间（毫秒）
                ttl_ms = redis_client.pttl(key_str)
                if ttl_ms < 0:
                    ttl_ms = 3600000  # 默认1小时（毫秒）
                
                # 迁移为v2格式（添加到pipeline）
                # ⚠️ 严禁使用set(..., ex=3600)，必须使用PEXPIRE保留原TTL
                # ... 迁移逻辑 ...
                # pipe.set(key_str, serialized)
                # if ttl_ms > 0:
                #     pipe.pexpire(key_str, ttl_ms)
                migrated_count += 1
                
            except Exception as e:
                logger.error(f"Migration failed for {key_str}: {e}")
                failed_count += 1
        
        # ⚠️ 执行pipeline
        try:
            pipe.execute()
        except Exception as e:
            logger.error(f"Pipeline execution failed: {e}")
        
        # 控制迁移速率，避免影响线上性能
        await asyncio.sleep(0.01)  # 10ms延迟
        
        if cursor == 0:
            break  # 扫描完成
    
    logger.info(f"Migration completed: {migrated_count} migrated, {failed_count} failed")
```

**阶段3：只读新格式（切换）**

- 观察24-48小时指标
- 确认迁移完成度 > 99%
- 切换为只读v2格式
- 保留回滚开关

#### 方案3：添加数据验证

**修改位置**：写入和读取时都添加验证

**实现**：
```python
# 写入时验证
def set_user_cache(user_id: str, data: dict):
    try:
        # 验证数据格式
        if not isinstance(data, dict):
            raise ValueError("Data must be a dictionary")
        
        # 序列化
        serialized = json.dumps(data, ensure_ascii=False)
        
        # ⚠️ 写入Redis（通用写缓存接口，可保留ex参数化）
        # ⚠️ 注意：迁移路径（migrate_to_v2/_migrate_to_json）必须用PTTL+PEXPIRE，严禁固定ex=3600
        redis_client.set(f"user:{user_id}", serialized, ex=3600)  # 通用接口默认1小时
        
        # 验证写入成功
        verify = redis_client.get(f"user:{user_id}")
        if not verify:
            logger.warning(f"User cache write verification failed: {user_id}")
    except Exception as e:
        logger.error(f"Failed to set user cache {user_id}: {e}")
```

#### 方案4：改进清理逻辑（日志脱敏与体量控制）

**修改位置**：`backend/app/user_redis_cleanup.py:173-180`

**修改内容**：
```python
import hashlib
import re

def mask_sensitive_data(text: str) -> str:
    """脱敏敏感信息"""
    # 邮箱脱敏
    text = re.sub(r'([a-zA-Z0-9._%+-]+)@([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})', 
                  r'\1***@\2', text)
    # 手机号脱敏
    text = re.sub(r'(\d{3})\d{4}(\d{4})', r'\1****\2', text)
    return text

if data is None:
    # 数据无法解析，记录详细信息（脱敏）
    try:
        raw_data = self.redis_client.get(key_str)
        data_type = type(raw_data).__name__
        data_size = len(raw_data) if raw_data else 0
        
        # 计算哈希值，而不是记录完整内容
        data_hash = hashlib.sha256(raw_data).hexdigest()[:16] if raw_data else "empty"
        
        # 脱敏预览（仅前100字节，且脱敏）
        if raw_data:
            try:
                preview = str(raw_data)[:100]
                preview = mask_sensitive_data(preview)
            except:
                preview = "<binary data>"
        else:
            preview = "empty"
        
        # 采样日志：只记录部分无法解析的数据，避免日志放大
        import random
        if random.random() < 0.1:  # 10%采样率
            logger.warning(
                f"[USER_REDIS_CLEANUP] 无法解析的缓存数据: {key_str}, "
                f"类型: {data_type}, 大小: {data_size}, 哈希: {data_hash}, 预览: {preview}"
            )
        
        # 删除无法解析的数据
        self.redis_client.delete(key_str)
        cleaned_count += 1
        
        # 记录指标
        self.metrics['unparseable_deleted'] += 1
        
    except Exception as e:
        logger.error(f"[USER_REDIS_CLEANUP] 删除损坏的缓存数据失败 {key_str}: {e}")
```

**关键点**：
- 日志脱敏：掩码邮箱、手机号等敏感信息
- 采样日志：10%采样率，避免日志放大
- 记录哈希：而不是完整内容
- 控制预览长度：最多100字节

### 推荐修复步骤

1. **立即修复（安全优先）**：
   - ⚠️ **严禁在线上读路径使用pickle.loads**
   - 增强 `_get_redis_data()` 方法，支持压缩数据识别
   - 改进清理逻辑，添加日志脱敏和采样（方案4）
   - 添加指标统计（方案5）

2. **短期优化（1-2周）**：
   - 实现渐进迁移策略（方案2）：读老写新
   - 添加数据验证机制（方案3）
   - 监控无法解析的数据模式

3. **长期优化（1个月）**：
   - 后台批量迁移（方案2阶段2）
   - 切换为只读新格式（方案2阶段3）
   - 完全移除pickle支持

---

## 📊 修复优先级

### 高优先级（立即修复）
1. ✅ **WebSocket重连逻辑** - 影响用户体验和服务器性能
2. ✅ **Profile请求优化** - 减少数据库压力

### 中优先级（近期修复）
3. ⚠️ **Redis数据格式统一** - 防止数据丢失

---

## 🛠️ 修复时间表

### 第一阶段（1-2天）- 紧急修复（阻断项）

#### ⚠️ 阻断项（NO-GO）- 必须修复
- [ ] ⚠️ **心跳关闭码修正**：改为非1000（如4001），前端需要重连
- [ ] ⚠️ **ETag 304统一**：统一使用Response对象，不return None
- [ ] ⚠️ **Redis迁移保留TTL**：读取PTTL，使用PEXPIRE，严禁固定ex=3600
- [ ] ⚠️ **WebSocket关闭码常量**：统一命名，删除重复定义
- [ ] ⚠️ **心跳实现修正**：删除send_text("")伪ping，使用框架ping或方案B
- [ ] ⚠️ **前端类型修正**：使用ReturnType<typeof setTimeout>
- [ ] ⚠️ **连接锁清理**：连接关闭后清理connection_locks[user_id]

#### 重要修复
- [ ] 修复WebSocket关闭码问题（方案1+2+3）
- [ ] ⚠️ **决策1**：明确WebSocket多标签准则（单连接 or 多连接）
- [ ] ⚠️ **决策2**：确定Profile缓存层选型（SWR / React Query / 自研）
- [ ] 优化Profile轮询频率（60s → 5min）
- [ ] 统一Profile请求使用缓存（硬约束：ESLint规则收敛匹配范围）
- [ ] 实现未读数刷新解耦（请求参数化，与用户态弱耦合）
- [ ] ⚠️ 移除线上pickle反序列化（安全）
- [ ] ⚠️ 关闭码+reason常量化+单测（前后端）
- [ ] ⚠️ 重连回退清理计时器（防止多定时器并存）
- [ ] ⚠️ 心跳改为不与业务receive竞争（使用框架ping或统一处理）
- [ ] ⚠️ 统一"只在code===1000 && reason===NEW_CONNECTION时不重连"

### 第二阶段（3-5天）- 短期优化
- [ ] 服务端原子替换连接
- [ ] 前端指数回退重连
- [ ] 服务端心跳机制
- [ ] Token过期处理
- [ ] **强烈推荐**：引入SWR/React Query
- [ ] 服务端协商缓存（ETag）
- [ ] Redis日志脱敏和采样

### 第三阶段（1-2周）- 中期优化
- [ ] 多标签页协调（如需要）
- [ ] WebSocket推送用户状态
- [ ] Redis渐进迁移（读老写新）
- [ ] 添加监控指标和告警
- [ ] ProtectedRoute超时降级

### 第四阶段（1个月）- 长期优化
- [ ] Redis后台批量迁移
- [ ] 切换为只读新格式
- [ ] 完全移除pickle支持
- [ ] 性能优化和压力测试

---

## 📝 测试计划

### WebSocket重连测试

#### 基础功能测试
1. **单标签页连接**：打开一个标签页，验证连接成功
2. **多标签页连接**：打开多个标签页，验证不会重复连接（或按产品需求验证多标签协调）
3. **标签页关闭**：关闭一个标签页，验证其他标签页连接正常
4. **网络断开重连**：断开网络30秒后恢复，验证自动重连功能

#### 并发与竞态测试（关键）
5. **并发连接测试**：同时发送两条新连接请求，验证：
   - 仅一条连接存活
   - 旧连接收到 `code=1000` 且 `reason="New connection established"`
   - reason精确匹配协议契约
   - 前端不触发重连

6. **并发边界测试**：验证：
   - 双端抖动：前端同一刻3个tab + 移动网络切飞行模式
   - 服务端滚动重启期间连接生存
   - 无序消息投递校验

#### 网络异常测试
7. **断网场景**：断开网络30秒，验证：
   - 不应瞬时重连风暴
   - 重连采用指数回退 + 抖动
   - 重连延迟符合预期（1s, 2s, 4s...最大30s）

8. **丢包场景**：模拟10%丢包率，验证：
   - 心跳机制正常工作
   - 不会因临时丢包断开连接
   - 连续N次未收到pong才断开

#### Token与认证测试
9. **Token过期处理**：模拟token过期场景，验证：
   - Token过期后1分钟内自动刷新
   - 刷新成功后平滑重建连接
   - 刷新失败后降级处理（跳转登录或匿名模式）

10. **认证失败**：模拟认证失败（401），验证：
   - 连接正确关闭（code=1008）
   - 触发token刷新流程
   - 刷新失败后跳转登录

#### 心跳测试
11. **心跳机制**：验证：
    - 服务端每20-30秒发送ping（使用框架ping方法，不是send_text("")）
    - 前端正确响应pong
    - 连续3次未收到pong才断开
    - ⚠️ 断开后使用非1000关闭码（如4001），前端能重连

### Profile请求测试

#### 缓存与去重测试
1. **初始加载**：打开应用，验证：
   - 只请求一次Profile
   - 所有组件共享同一份数据
   - 使用缓存层（SWR/React Query或自研缓存）

2. **页面切换**：在不同页面间切换，验证：
   - 使用缓存，不重复请求
   - 缓存命中率 > 90%

3. **时间窗口**：验证：
   - 5分钟内使用缓存
   - 5分钟后自动刷新
   - 刷新时使用stale-while-revalidate策略

#### 窗口状态测试
4. **标签页切换**：验证：
   - 切换标签页不触发无意义更新
   - 重新聚焦时触发SWR revalidate
   - 窗口失焦时不更新

5. **网络重连**：验证：
   - 网络断开重连后自动刷新
   - 使用SWR的revalidateOnReconnect

#### 服务端缓存测试
6. **ETag协商缓存**：验证：
   - 首次请求返回200和ETag
   - 后续请求带If-None-Match
   - ⚠️ 数据未变化返回304（统一使用Response对象，不return None）
   - ETag命中率统计
   - 304响应比例 > 50%

7. **ETag权限变化测试**：验证：
   - ⚠️ 304命中下的权限变化（角色被降级）
   - 确保不会因为缓存而越权
   - 权限变更时ETag必须变化

8. **Cache-Control头**：验证：
   - 响应头包含 `Cache-Control: private, max-age=300`
   - 包含 `Vary: Cookie` 避免中间层误缓存

#### 超时与降级测试
9. **接口超时**：模拟接口超时（10秒），验证：
   - ⚠️ 超时后必须清理定时器
   - ⚠️ isMounted守卫，避免在卸载组件上setState
   - 超时后UX处理（骨架屏/离线模式/跳转登录）
   - 不影响其他功能
   - 使用缓存的用户状态（如果可用）

10. **网络离线**：模拟网络离线，验证：
   - 显示离线模式提示
   - 使用本地缓存数据
   - 网络恢复后自动刷新

#### Profile E2E测试
11. **用户信息变更推送**：验证：
   - 用户改密码/头像后，WebSocket推送 + SWR mutate能把UI拉新
   - 缓存正确失效和更新
   - 多标签页同步更新

12. **权限变化缓存**：验证：
   - 304命中下的权限变化（角色被降级）
   - 确保不会因为缓存而越权
   - 权限变更时ETag必须变化

#### 未读数解耦测试
13. **未读数刷新**：验证：
    - 不再强依赖完整Profile对象
    - 只需userId即可刷新
    - 或使用WebSocket推送未读数

### Redis数据解析测试

#### 格式兼容测试
1. **多格式解析**：创建测试数据，验证：
   - JSON格式正确解析
   - orjson格式正确解析
   - 双重编码JSON正确解析
   - 压缩数据（gzip/zlib）正确解压

2. **压缩数据识别**：验证：
   - gzip魔数 `\x1f\x8b` 正确识别
   - zlib魔数正确识别
   - 解压失败时记录警告

#### 安全性测试（关键）
3. **Pickle安全限制**：验证：
   - ⚠️ 线上读路径不使用pickle.loads
   - 清理脚本中pickle使用白名单限制
   - 只允许特定key前缀
   - 立即迁移为JSON格式
   - 不在线上读路径复用pickle

4. **数据损坏处理**：验证：
   - 损坏数据被正确识别
   - 无法解析的数据被删除
   - 记录详细日志（脱敏）

#### 迁移测试
5. **读老写新**：验证：
   - ⚠️ 迁移时保留TTL（读取PTTL，使用PEXPIRE）
   - v1/v2格式混布时读老写新生效
   - 优先读v2格式
   - v1格式自动迁移为v2
   - 旁路回写不互相踩踏

6. **后台迁移**：验证：
   - 使用SCAN而不是KEYS（避免阻塞）
   - ⚠️ SCAN返回的key多为bytes，需要decode
   - ⚠️ 使用pipeline/transaction=False批处理
   - ⚠️ 为每批设置最大字节总量（5-10MB）与最大时长（100ms）双阈值
   - 控制迁移速率（10ms延迟）
   - 迁移进度统计
   - 失败重试机制

7. **切换测试**：验证：
   - 观察24-48小时指标
   - 迁移完成度 > 99%才切换
   - 保留回滚开关
   - 切换后只读v2格式

8. **回滚演练**：验证：
   - ⚠️ 人为让v2解析出错（打坏一个字段）
   - ⚠️ 验证"回滚到读老"开关有效
   - ⚠️ 迁移中止、重启续跑不会重复处理同一批（幂等）

#### 日志与监控测试
9. **日志脱敏**：验证：
   - 邮箱脱敏（`user***@example.com`）
   - 手机号脱敏（`138****1234`）
   - 记录哈希值而不是完整内容
   - 预览长度限制在100字节

10. **日志采样**：验证：
   - 10%采样率生效
   - 避免日志放大
   - 关键错误仍100%记录

11. **指标统计**：验证：
    - 解析失败数量统计
    - 成功迁移数量统计
    - 删除数量统计
    - 平均数据大小统计
    - 按key前缀分布统计
    - ⚠️ **TTL分布**（迁移前后对比）
    - ⚠️ **单值大小直方图**
    - ⚠️ **前缀维度TOP-N**
    - ⚠️ **迁移速率**（keys/s）
    - ⚠️ **失败重试次数**

#### 边界情况测试
12. **超大value处理**：验证：
    - value > 1MB时的处理
    - 记录大小但不记录内容
    - 正确删除或迁移

13. **故意损坏数据**：验证：
    - 写入损坏数据后正确删除
    - 触发告警（如果配置）
    - 不影响其他正常数据

---

## 📈 预期效果

### WebSocket重连
- **连接数减少**：预计减少50-70%的重复连接
- **服务器负载**：减少WebSocket连接管理开销
- **用户体验**：连接更稳定，消息延迟降低
- **重连风暴**：指数回退 + 抖动避免同步重连
- **并发安全**：原子替换避免竞态条件

### Profile请求
- **请求频率**：从每60秒减少到每5分钟（减少83%）
- **数据库压力**：减少重复查询
- **网络带宽**：减少不必要的HTTP请求
- **ETag命中率**：预计304响应比例 > 50%
- **缓存去重**：SWR自动去重，多组件共享数据

### Redis数据解析
- **数据丢失**：避免误删有效数据
- **性能提升**：正确解析缓存，减少数据库查询
- **问题定位**：详细日志（脱敏）帮助定位根本原因
- **安全性**：移除pickle反序列化风险
- **迁移平滑**：读老写新策略，不中断服务

---

## 🚀 发布与回滚建议

### WebSocket/前端重连改动
- **发布策略**：使用feature flag，先灰度小流量（10%）
- **监控指标**：连接数、重连频率、消息延迟
- **回滚准备**：保留旧代码路径，可快速回滚

### Profile请求优化
- **发布策略**：SWR/React Query可逐步迁移组件
- **监控指标**：请求频率、缓存命中率、ETag命中率
- **回滚准备**：保留原有缓存机制作为fallback

### Redis迁移
- **发布策略**：
  1. 先开启读老写新，观察24-48小时
  2. 后台迁移，控制速率
  3. 迁移完成度 > 99%后切换只读新格式
- **监控指标**：
  - 解析失败/成功迁移/删除数量
  - 平均数据大小
  - 按key前缀分布
  - 迁移进度和健康度
- **回滚准备**：始终保留回滚开关，可切回v1格式

### 告警配置
- **WebSocket**：连接数异常增长、重连频率过高
- **Profile**：请求频率异常、缓存命中率过低
- **Redis**：解析失败率 > 1%、迁移失败率 > 5%

---

## 📚 协议契约与安全红线文档化

### 协议契约（必须写入README/CONTRIBUTING）

**WebSocket关闭码协议**：
- `code=1000` + `reason="New connection established"` → 新连接替换，前端不重连
- `code=4001` + `reason="Heartbeat timeout"` → 心跳超时，前端需要重连（⚠️ 非1000，必须重连）
- `code=1008` + `reason="Authentication failed"` → 认证失败，可恢复（刷新token）
- `code=1008` + `reason="Token expired"` → Token过期，可恢复

**变更要求**：
- 所有关闭码和reason必须使用常量，禁止硬编码
- 修改关闭码/reason需要前后端同步更新
- 必须添加单测覆盖

### 安全红线（必须写入README/CONTRIBUTING）

**Redis数据安全**：
- ⚠️ **线上读路径严禁使用pickle.loads反序列化不可信数据**
- 清理脚本中的pickle使用必须：
  1. 运行在隔离进程/容器
  2. 使用只读凭证
  3. 白名单前缀 + 魔数检查 + schema_version校验（必选）
  4. 立即迁移为JSON，不写回pickle
- ⚠️ **迁移必须保留TTL**：读取PTTL，使用PEXPIRE，严禁固定ex=3600
- ⚠️ **解压安全**：输入/输出大小上限（10MB/100MB），避免压缩炸弹

**代码所有者与变更评审**：
- WebSocket相关变更：需要前后端同步评审
- Profile缓存相关变更：需要前端缓存层评审
- Redis迁移相关变更：需要DBA和运维评审
- 所有变更必须包含测试用例

---

## 📋 一页纸执行清单

### WebSocket
- [ ] ⚠️ **心跳关闭码全局统一改为4001**（WS_CLOSE_CODE_HEARTBEAT_TIMEOUT），前端需要重连，严禁使用code=1000
- [ ] ⚠️ **删除send_text("")伪ping**，优先使用websocket.ping()，框架不支持时用方案B（业务循环统一处理），严禁双轨并存
- [ ] ⚠️ **"新连接替换"统一为1000 + "New connection established"**（前后端常量化+单测），删除所有1001旧代码和重复常量定义
- [ ] ⚠️ **连接关闭后真正清理connection_locks[user_id]**（检查active_connections后pop），防止泄漏
- [ ] 前端重连统一清理定时器（onclose和connect入口）
- [ ] 可见性/在线状态前置（document.hidden && navigator.onLine）
- [ ] 统一"只在code===1000 && reason===NEW_CONNECTION时不重连"
- [ ] 并发/滚动重启场景压测

### Profile
- [ ] ⚠️ **ProtectedRoute清理timeout和isMounted守卫**（使用ReturnType<typeof setTimeout>）
- [ ] ⚠️ **统一经fetchCurrentUser()**（ESLint规则收敛匹配范围）
- [ ] ⚠️ **ETag 304统一返回**（Response对象，不return None，保留Cache-Control和Vary）
- [ ] 确定缓存层选型（SWR/React Query/自研）
- [ ] 未读数解耦（请求参数化，服务器推断userId）

### Redis
- [ ] ⚠️ **迁移保留TTL**（读取PTTL，使用PEXPIRE，严禁固定ex=3600）
- [ ] ⚠️ **SCAN游标处理**（bytes decode，pipeline批处理）
- [ ] ⚠️ **批处理限字节+时长**（5-10MB，100ms双阈值）
- [ ] ⚠️ **解压安全**（输入/输出大小上限，避免压缩炸弹）
- [ ] Pickle仅隔离进程（白名单+魔数+schema必选校验）
- [ ] 失败不写回（解压/解析失败不重试，不写回损坏数据）

### 观测
- [ ] TTL分布/大小直方图/迁移速率/失败重试等指标
- [ ] 切换只读新格式前做回滚演练

### 文档
- [ ] 协议契约写入README/CONTRIBUTING
- [ ] 安全红线写入README/CONTRIBUTING
- [ ] 代码所有者与变更评审清单

---

生成时间：2025-11-16
基于日志：logs.1763317554418.log
最后更新：整合所有专业建议

