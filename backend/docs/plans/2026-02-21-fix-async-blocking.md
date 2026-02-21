# Fix Async Blocking Calls Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 消除 FastAPI async 函数中的同步阻塞调用，提升事件循环并发能力。

**Architecture:** 使用 `asyncio.to_thread()` 将 async 函数内的同步 DB/外部 IO 操作移入线程池执行；修复 background thread 中不安全的 `run_until_complete()` 为 `run_coroutine_threadsafe()`。不引入新依赖，改动范围最小化。

**Tech Stack:** Python asyncio, SQLAlchemy SessionLocal, FastAPI

---

## 背景：确认的阻塞点

经过完整扫描，以下是**真正在 async 上下文中阻塞事件循环**的代码（其他被误报的调用实际在 sync 函数中，由 FastAPI 线程池执行，不构成阻塞）：

| 文件 | 行号 | 问题 |
|---|---|---|
| `routers.py` | 425 | `SessionLocal()` + `process_invitation_input()` 在 `async def register()` 中 |
| `routers.py` | 469 | `SessionLocal()` + `use_invitation_code()` 在 `async def register()` 中 |
| `routers.py` | 500 | `SessionLocal()` + `EmailVerificationManager.create_pending_user()` 在 `async def register()` 中 |
| `customer_service_tasks.py` | 430-436 | `asyncio.run_until_complete()` 在后台线程中（P0 危险：可能死锁） |

---

### Task 1: 修复 async register() 中的 3 处 SessionLocal 阻塞

**Files:**
- Modify: `backend/app/routers.py:420-504`

**当前代码（问题区域）：**

```python
# Line 420-438: 邀请码验证
if validated_data.get('invitation_code'):
    from app.coupon_points_crud import process_invitation_input
    from app.database import SessionLocal
    sync_db = SessionLocal()          # ← 阻塞
    try:
        inviter_id, invitation_code_id, invitation_code_text, error_msg = process_invitation_input(
            sync_db, validated_data['invitation_code']
        )
        ...
    finally:
        sync_db.close()

# Line 466-477: 邀请码奖励（开发环境）
if invitation_code_id:
    from app.coupon_points_crud import use_invitation_code
    from app.database import SessionLocal
    sync_db = SessionLocal()          # ← 阻塞
    try:
        success, error_msg = use_invitation_code(sync_db, new_user.id, invitation_code_id)
        ...
    finally:
        sync_db.close()

# Line 498-504: 创建待验证用户（生产环境）
from app.database import SessionLocal
sync_db = SessionLocal()              # ← 阻塞
try:
    pending_user = EmailVerificationManager.create_pending_user(sync_db, user_data, verification_token)
finally:
    sync_db.close()
```

**Step 1: 用 `asyncio.to_thread()` 包装三处同步 DB 调用**

将 `routers.py` 中 async register() 的三处 SessionLocal 块替换如下：

```python
# 替换 Line 420-438（邀请码验证）
if validated_data.get('invitation_code'):
    def _process_invitation_sync():
        from app.database import SessionLocal
        from app.coupon_points_crud import process_invitation_input
        _db = SessionLocal()
        try:
            return process_invitation_input(_db, validated_data['invitation_code'])
        finally:
            _db.close()
    inviter_id, invitation_code_id, invitation_code_text, error_msg = await asyncio.to_thread(
        _process_invitation_sync
    )
    if inviter_id:
        logger.debug(f"邀请人ID验证成功: {inviter_id}")
    elif invitation_code_id:
        logger.debug(f"邀请码验证成功: {invitation_code_text}, ID: {invitation_code_id}")
    elif error_msg:
        logger.debug(f"邀请码/用户ID验证失败: {error_msg}")
```

```python
# 替换 Line 466-477（邀请码奖励，开发环境分支内）
if invitation_code_id:
    def _use_invitation_sync():
        from app.database import SessionLocal
        from app.coupon_points_crud import use_invitation_code
        _db = SessionLocal()
        try:
            return use_invitation_code(_db, new_user.id, invitation_code_id)
        finally:
            _db.close()
    success, error_msg = await asyncio.to_thread(_use_invitation_sync)
    if success:
        logger.info(f"邀请码奖励发放成功: 用户 {new_user.id}, 邀请码ID {invitation_code_id}")
    else:
        logger.warning(f"邀请码奖励发放失败: {error_msg}")
```

```python
# 替换 Line 498-504（创建待验证用户，生产环境分支内）
def _create_pending_user_sync():
    from app.database import SessionLocal
    _db = SessionLocal()
    try:
        return EmailVerificationManager.create_pending_user(_db, user_data, verification_token)
    finally:
        _db.close()
pending_user = await asyncio.to_thread(_create_pending_user_sync)
```

**注意：** `asyncio` 已在 routers.py 顶部 import，无需额外添加。

**Step 2: 验证 asyncio import 存在**

```bash
grep -n "^import asyncio" backend/app/routers.py
```
Expected: 找到 `import asyncio`（若不存在则在文件顶部添加）

**Step 3: Commit**

```bash
git add backend/app/routers.py
git commit -m "fix(routers): replace sync SessionLocal() in async register() with asyncio.to_thread()

Three sync DB calls in async def register() blocked the event loop:
- process_invitation_input() at invitation code validation
- use_invitation_code() at invitation reward (dev env)
- EmailVerificationManager.create_pending_user() at pending user creation

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

### Task 2: 修复 customer_service_tasks.py 中的危险事件循环代码

**Files:**
- Modify: `backend/app/customer_service_tasks.py:428-436`

**当前代码（危险）：**

```python
# Lines 429-436
try:
    loop = asyncio.get_event_loop()
    if loop.is_running():
        asyncio.create_task(ws_manager.send_to_user(chat.user_id, notification_update))
    else:
        loop.run_until_complete(ws_manager.send_to_user(chat.user_id, notification_update))
except RuntimeError:
    asyncio.run(ws_manager.send_to_user(chat.user_id, notification_update))
```

**问题：** 此代码在 TaskScheduler 后台线程中执行。
- `asyncio.create_task()` 不是线程安全的，从非 async 线程调用会导致未定义行为
- `loop.run_until_complete()` 在主事件循环已运行时调用会死锁
- `asyncio.run()` 创建新事件循环，与主循环隔离，发不出消息

**Step 1: 替换为线程安全的 `run_coroutine_threadsafe`**

```python
# 替换 Lines 429-436
try:
    loop = asyncio.get_event_loop()
    if loop.is_running():
        # 从后台线程安全地调度协程到主事件循环
        asyncio.run_coroutine_threadsafe(
            ws_manager.send_to_user(chat.user_id, notification_update),
            loop
        )
    else:
        asyncio.run(ws_manager.send_to_user(chat.user_id, notification_update))
except Exception as e:
    logger.debug(f"WebSocket超时通知跳过（后台线程上下文）: {e}")
```

**为什么这样改：**
- `asyncio.run_coroutine_threadsafe(coro, loop)` 是 Python 标准库提供的线程安全调度 API，专为"从非 async 线程调度协程到运行中事件循环"设计
- 不等待结果（fire-and-forget），不阻塞 TaskScheduler 线程
- 异常处理改为 `Exception` 而非仅 `RuntimeError`，避免未捕获的异常静默崩溃

**Step 2: Commit**

```bash
git add backend/app/customer_service_tasks.py
git commit -m "fix(customer_service_tasks): replace unsafe run_until_complete with run_coroutine_threadsafe

asyncio.create_task() is not thread-safe from non-async threads.
run_until_complete() on a running loop causes deadlock.
Use run_coroutine_threadsafe() which is the correct API for scheduling
coroutines from background threads onto the running event loop.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## 验证方法

修复后，验证以下端点不会因同步阻塞而延迟其他请求：

1. 使用邀请码注册时，其他并发请求应正常响应（不被 `register()` 的 DB 操作卡住）
2. 客服超时告警时，WebSocket 消息正常发送，无死锁日志

## 预期效果

- `async def register()` 中的 DB 操作交由线程池执行，事件循环空闲可处理其他请求
- 客服后台线程发送 WebSocket 通知时不再存在死锁风险
- 高并发时注册接口不再成为整体系统的阻塞点
